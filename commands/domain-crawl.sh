#!/usr/bin/env bash
# commands/domain-crawl.sh — §33 domain-crawl: expand ONE registry entry's seed URL into a
# bounded, guarded set of same-host pages, run Stage 1 extraction per page, and emit the
# MERGED, content_hash-deduped segments JSON on stdout — the same output shape a single
# extract-rules-from-url.sh call produces, so the §33 orchestrator pipeline downstream of
# Stage 1 (classify → route → Stage 5 fidelity → assemble) is unchanged.
#
# Strategies (entry `scope.strategy`):
#   single-page   no crawl (the orchestrator never calls this script for it)
#   path-prefix   BFS over <a href> links, same host, path under the seed's path prefix
#   sitemap       seed is a sitemap; fetch its <loc> URLs at depth 1 (no further follow)
#   link-follow   BFS over <a href> links, same host, any path
#
# Universal guards (always enforced; entry values can only tighten, never exceed):
#   1 same-host only (links are never enqueued off the seed's host)
#   2 max_pages hard cap 200            3 max_depth hard cap 3
#   4 robots.txt respected (http/https; respect_robots:false opts out)
#   5 content-type filter (binary-extension excludes + NUL-byte content sniff)
#   6 content_hash dedupe (a page body is processed once per crawl)
#   7 rate limit between network fetches (scope.rate_limit_ms, default 1000; file:// exempt)
#   8 URL length <= 2048 bytes
# Refuse-on-root-path: path-prefix with a root ("/") prefix is a usage error — a
# whole-domain crawl must be an explicit link-follow choice, never an accident.
#
# Quality guards: empty-content-density gate (pages with <40 chars of tag-stripped text are
# skipped), low-yield pages (0 segments) recorded in the manifest not failed, default
# exclude_patterns (login/signup/search/static-asset URLs), per-crawl manifest JSONL (one
# line per URL considered: url/depth/status/reason/content_hash/segments), redirect
# following delegated to the S-2 http-get.sh stub (curl -L; off-host links discovered on a
# redirected page are still filtered by guard 1).
#
# CLI:
#   domain-crawl.sh --seed-url <url> --seed-file <cached-seed> --sid <id> --shape <shape>
#                   --scope-b64 <base64-json> --pages-dir <dir> --manifest <file>
#
# stdout: merged segments JSON array. stderr: per-page notes + summary
#   `crawl sid=<id> strategy=<s> pages_fetched=<n> pages_skipped=<m> segments=<k> manifest=<path>`
# Exit: 0 ok | 1 crawl/extract error | 2 usage (incl. refuse-on-root-path)

set -uo pipefail

SEED_URL=""; SEED_FILE=""; SID=""; SHAPE="markdown-headings"; SCOPE_B64=""; PAGES_DIR=""; MANIFEST=""
while [ $# -gt 0 ]; do
  case "$1" in
    --seed-url)  SEED_URL="${2-}";  shift 2 ;;
    --seed-file) SEED_FILE="${2-}"; shift 2 ;;
    --sid)       SID="${2-}";       shift 2 ;;
    --shape)     SHAPE="${2-}";     shift 2 ;;
    --scope-b64) SCOPE_B64="${2-}"; shift 2 ;;
    --pages-dir) PAGES_DIR="${2-}"; shift 2 ;;
    --manifest)  MANIFEST="${2-}";  shift 2 ;;
    -h|--help) sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 0 ;;
    *) echo "domain-crawl: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -n "$SEED_URL" ]  || { echo "domain-crawl: --seed-url required" >&2; exit 2; }
[ -s "$SEED_FILE" ] || { echo "domain-crawl: --seed-file missing or empty: $SEED_FILE" >&2; exit 2; }
[ -n "$SID" ]       || { echo "domain-crawl: --sid required" >&2; exit 2; }
[ -n "$PAGES_DIR" ] || { echo "domain-crawl: --pages-dir required" >&2; exit 2; }
[ -n "$MANIFEST" ]  || { echo "domain-crawl: --manifest required" >&2; exit 2; }

HERE="$(cd "$(dirname "$0")" && pwd -P)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$HERE/.." && pwd -P)}"
mkdir -p "$PAGES_DIR" "$(dirname "$MANIFEST")"

SEED_URL="$SEED_URL" SEED_FILE="$SEED_FILE" SID="$SID" SHAPE="$SHAPE" \
SCOPE_B64="$SCOPE_B64" PAGES_DIR="$PAGES_DIR" MANIFEST="$MANIFEST" \
HERE="$HERE" PLUGIN_ROOT="$PLUGIN_ROOT" python3 <<'PY'
import base64, hashlib, json, os, re, subprocess, sys, time
from urllib.parse import urljoin, urlparse, urldefrag

seed_url = os.environ["SEED_URL"]; seed_file = os.environ["SEED_FILE"]
sid = os.environ["SID"]; shape = os.environ["SHAPE"]
pages_dir = os.environ["PAGES_DIR"]; manifest_path = os.environ["MANIFEST"]
here = os.environ["HERE"]; plugin_root = os.environ["PLUGIN_ROOT"]

scope = {}
if os.environ.get("SCOPE_B64"):
    try:
        scope = json.loads(base64.b64decode(os.environ["SCOPE_B64"]).decode())
    except Exception:
        sys.stderr.write("domain-crawl: unparseable --scope-b64\n"); sys.exit(2)

strategy = scope.get("strategy", "single-page")
if strategy not in ("path-prefix", "sitemap", "link-follow"):
    sys.stderr.write("domain-crawl: unsupported strategy: " + strategy + "\n"); sys.exit(2)

# Universal guards 2+3: entry values may only tighten the hard caps.
max_pages = min(int(scope.get("max_pages", 200)), 200)
max_depth = min(int(scope.get("max_depth", 3)), 3)
respect_robots = bool(scope.get("respect_robots", True))
rate_limit_ms = int(scope.get("rate_limit_ms", 1000))
include_patterns = list(scope.get("include_patterns", []))
DEFAULT_EXCLUDES = ["/login", "/signup", "/signin", "/register", "/search?", "mailto:",
                    "javascript:", ".pdf", ".zip", ".tar", ".gz", ".png", ".jpg", ".jpeg",
                    ".gif", ".svg", ".ico", ".css", ".js", ".mp4", ".webm", ".woff", ".woff2"]
exclude_patterns = DEFAULT_EXCLUDES + list(scope.get("exclude_patterns", []))

seed = urlparse(seed_url)
prefix = seed.path if seed.path.endswith("/") else seed.path.rsplit("/", 1)[0] + "/"
if strategy == "path-prefix" and prefix == "/":
    sys.stderr.write("domain-crawl: REFUSED sid=" + sid + " strategy=path-prefix with root path prefix "
                     "— a whole-domain crawl must be an explicit link-follow choice\n")
    sys.exit(2)

# Guard 4: robots.txt disallow prefixes (http/https hosts only).
robots_disallow = []
if respect_robots and seed.scheme in ("http", "https"):
    try:
        r = subprocess.run(["bash", os.path.join(plugin_root, "standards", "fetchers", "http-get.sh")],
                           env={**os.environ, "URL": seed.scheme + "://" + seed.netloc + "/robots.txt"},
                           capture_output=True, text=True, timeout=30)
        if r.returncode == 0:
            active = False
            for line in r.stdout.splitlines():
                line = line.split("#")[0].strip()
                m = re.match(r"(?i)user-agent:\s*(.+)", line)
                if m:
                    active = (m.group(1).strip() == "*")
                    continue
                m = re.match(r"(?i)disallow:\s*(\S+)", line)
                if m and active:
                    robots_disallow.append(m.group(1))
    except Exception:
        pass

manifest = open(manifest_path, "w")
def note(url, depth, status, reason="", content_hash="", segments=None):
    row = {"url": url, "depth": depth, "status": status}
    if reason: row["reason"] = reason
    if content_hash: row["content_hash"] = content_hash
    if segments is not None: row["segments"] = segments
    manifest.write(json.dumps(row) + "\n")

def fetch(url):
    if urlparse(url).scheme in ("http", "https") and rate_limit_ms > 0:
        time.sleep(rate_limit_ms / 1000.0)
    r = subprocess.run(["bash", os.path.join(plugin_root, "standards", "fetchers", "http-get.sh")],
                       env={**os.environ, "URL": url}, capture_output=True, timeout=60)
    if r.returncode != 0:
        return None
    return r.stdout

def links_of(content, base_url):
    # Quoted AND unquoted href values: minified real-world HTML (e.g. the
    # nodejs.org/api/ index, 95 module links) omits attribute quotes entirely —
    # a quoted-only pattern silently finds zero links there.
    out = []
    for m in re.finditer(r'''href=(?:"([^"]*)"|'([^']*)'|([^\s"'<>]+))''', content):
        href = m.group(1) or m.group(2) or m.group(3) or ""
        href = href.strip()
        if not href or href.startswith("#"):
            continue
        u, _ = urldefrag(urljoin(base_url, href))
        out.append(u)
    return out

def allowed(url, depth):
    p = urlparse(url)
    if len(url) > 2048:                                   return "url-too-long"
    if p.netloc != seed.netloc or p.scheme != seed.scheme: return "off-host"
    if strategy == "path-prefix" and not p.path.startswith(prefix): return "outside-prefix"
    if depth > max_depth:                                  return "max-depth"
    for pat in exclude_patterns:
        if pat in url:                                     return "excluded-pattern"
    if include_patterns and not any(pat in url for pat in include_patterns): return "not-included"
    for d in robots_disallow:
        if p.path.startswith(d):                           return "robots-disallow"
    return ""

def extract(page_file):
    r = subprocess.run(["bash", os.path.join(here, "extract-rules-from-url.sh"),
                        "--source", page_file, "--shape", shape, "--source-id", sid, "--json"],
                       capture_output=True, text=True, timeout=60)
    if r.returncode != 0:
        return []
    try:
        return json.loads(r.stdout or "[]")
    except Exception:
        return []

seen_urls = {seed_url}
seen_hashes = set()
seg_hashes = set()
segments = []
fetched = 0; skipped = 0
queue = [(seed_url, 0, None)]   # (url, depth, prefetched-file)
page_n = 0

while queue and fetched < max_pages:
    url, depth, prefile = queue.pop(0)
    if prefile is None:
        reason = allowed(url, depth)
        if reason:
            skipped += 1; note(url, depth, "skipped", reason); continue
        raw = fetch(url)
        if raw is None:
            skipped += 1; note(url, depth, "skipped", "fetch-failed"); continue
    else:
        raw = open(prefile, "rb").read()
    if b"\x00" in raw:
        skipped += 1; note(url, depth, "skipped", "binary-content"); continue
    content = raw.decode("utf-8", "replace")
    ch = "sha256:" + hashlib.sha256(raw).hexdigest()
    if ch in seen_hashes:
        skipped += 1; note(url, depth, "skipped", "duplicate-content", ch); continue
    seen_hashes.add(ch)

    if strategy == "sitemap" and depth == 0:
        # The seed IS the sitemap index — enqueue its <loc> URLs, never extract it.
        note(url, depth, "index", "", ch)
        for loc in re.findall(r"<loc>\s*([^<]+?)\s*</loc>", content):
            if loc not in seen_urls:
                seen_urls.add(loc); queue.append((loc, 1, None))
        continue

    if len(re.sub(r"<[^>]+>", " ", content).split()) < 5:
        skipped += 1; note(url, depth, "skipped", "empty-content", ch); continue

    page_n += 1
    page_file = os.path.join(pages_dir, "page-%03d.html" % page_n)
    with open(page_file, "wb") as f:
        f.write(raw)
    segs = extract(page_file)
    fresh = [s for s in segs if s.get("content_hash") not in seg_hashes]
    for s in fresh:
        seg_hashes.add(s.get("content_hash"))
    segments.extend(fresh)
    fetched += 1
    note(url, depth, "fetched", "" if segs else "low-yield", ch, len(fresh))

    if strategy == "sitemap":
        pass   # sitemap pages are leaves; only the depth-0 index enqueues
    elif depth < max_depth:
        for link in links_of(content, url):
            if link not in seen_urls:
                seen_urls.add(link); queue.append((link, depth + 1, None))

for url, depth, _ in queue:
    skipped += 1
    note(url, depth, "skipped", "max-pages")
manifest.close()

sys.stdout.write(json.dumps(segments))
sys.stderr.write("crawl sid=%s strategy=%s pages_fetched=%d pages_skipped=%d segments=%d manifest=%s\n"
                 % (sid, strategy, fetched, skipped, len(segments), manifest_path))
PY
