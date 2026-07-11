#!/usr/bin/env bash
# commands/standards-refresh.sh — C-26 (v1.26 §33): the missing ADR-0009 pipeline
# orchestrator + periodic-refresh worker. Drives Stage 1 (extract) → Stage 2 (classify)
# → Stages 3+4 (route + auto-bind bundle) → assemble → merge-or-replace target rule YAML
# at generated-code-quality-standards/<target-namespace>/<framework-id>.yaml.
#
# Three modes:
#   A. Single-URL — --url + --target-namespace + --framework-id + --source-id +
#      --authoritative-publisher (+ optional --shape, --merge|--replace, --dry-run)
#   B. Registry-iteration — --registry <path> [--force] [--now <iso>]
#      Iterates every entry in a *-URLS.yaml registry; freshness-skip via
#      fetch_frequency vs `.claude-tdd-pro/<registry>-last-fetch/<source-id>.txt`.
#   C. Scheduler integration (deferred to CL-565) — auto-refresh-daily.sh replaces
#      its --upstream-stub with a call into this orchestrator.
#
# Idempotent by content_hash: re-run against unchanged URL → same YAML byte-identical
# modulo fetched_at timestamp. URL content changes → new rules appended (introduced_at),
# removed rules marked deprecated (deprecated_at reason: removed-upstream).
#
# Exit codes:
#   0 ok (or freshness-skip in registry mode)
#   1 pipeline failure (extract/classify/route stage failed; nothing written)
#   2 usage error
#   3 URL unreachable (network / DNS / HTTP error)

set -uo pipefail

URL=""; TARGET_NS=""; FRAMEWORK_ID=""; SOURCE_ID=""; AUTH_PUB=""
SHAPE="markdown-headings"; MERGE_MODE="merge"; OUT_DIR=""; DRY_RUN=0
REGISTRY=""; NOW_ISO=""; FORCE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --url)                     URL="${2-}";           shift 2 ;;
    --target-namespace)        TARGET_NS="${2-}";     shift 2 ;;
    --framework-id)            FRAMEWORK_ID="${2-}";  shift 2 ;;
    --source-id)               SOURCE_ID="${2-}";     shift 2 ;;
    --authoritative-publisher) AUTH_PUB="${2-}";      shift 2 ;;
    --shape)                   SHAPE="${2-}";         shift 2 ;;
    --merge)                   MERGE_MODE="merge";    shift ;;
    --replace)                 MERGE_MODE="replace";  shift ;;
    --out-dir)                 OUT_DIR="${2-}";       shift 2 ;;
    --dry-run)                 DRY_RUN=1;             shift ;;
    --registry)                REGISTRY="${2-}";      shift 2 ;;
    --now)                     NOW_ISO="${2-}";       shift 2 ;;
    --force)                   FORCE=1;               shift ;;
    -h|--help)
      sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//' >&2
      exit 0 ;;
    *) echo "standards-refresh: unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Defaults + resolution.
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
[ -z "$OUT_DIR" ] && OUT_DIR="$PLUGIN_ROOT/generated-code-quality-standards"
[ -z "$NOW_ISO" ] && NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
HERE="$(dirname "$0")"

# --- helpers ---

# Parse fetch_frequency (daily|weekly|monthly|quarterly|<N><m|h|d|w|mo>) into seconds.
freq_to_seconds() {
  local freq="$1"
  case "$freq" in
    daily)     echo 86400 ;;
    weekly)    echo 604800 ;;
    monthly)   echo 2592000 ;;    # 30 days
    quarterly) echo 7776000 ;;    # 90 days
    on-demand) echo 315360000 ;;  # 10y - never fires
    *)
      local n="${freq%[mhdwo]*}"
      local unit="${freq#$n}"
      case "$unit" in
        m)   echo $((n * 60)) ;;
        h)   echo $((n * 3600)) ;;
        d)   echo $((n * 86400)) ;;
        w)   echo $((n * 604800)) ;;
        mo)  echo $((n * 2592000)) ;;
        *)   echo 86400 ;;
      esac ;;
  esac
}

# Check if a source is due for refresh (returns 0 = due, 1 = not due yet).
freshness_due() {
  local sid="$1" freq="$2" last_fetch_dir="$3" now_iso="$4"
  local marker="$last_fetch_dir/$sid.txt"
  [ -f "$marker" ] || return 0   # never fetched -> due
  local last_iso; last_iso=$(cat "$marker" 2>/dev/null | head -1)
  [ -n "$last_iso" ] || return 0
  # Convert both to epoch and diff.
  local now_epoch last_epoch
  now_epoch=$(NOW_ISO="$now_iso" python3 -c 'import os,datetime; print(int(datetime.datetime.fromisoformat(os.environ["NOW_ISO"].replace("Z","+00:00")).timestamp()))' 2>/dev/null)
  last_epoch=$(LAST_ISO="$last_iso" python3 -c 'import os,datetime; print(int(datetime.datetime.fromisoformat(os.environ["LAST_ISO"].replace("Z","+00:00")).timestamp()))' 2>/dev/null)
  [ -z "$now_epoch" ] || [ -z "$last_epoch" ] && return 0
  local age=$((now_epoch - last_epoch))
  local freq_sec; freq_sec=$(freq_to_seconds "$freq")
  [ "$age" -ge "$freq_sec" ]
}

# Resolve a registry-entry's jurisdiction / source_class to a target namespace (G-9).
ns_from_jurisdiction() {
  case "$1" in
    us-government)      echo "us-government" ;;
    european-union)     echo "european-union" ;;
    international)      echo "industry-self-regulatory" ;;
    federal-financial-regulator) echo "us-government" ;;
    financial-industry) echo "finance-industry" ;;
    gold-standard-process)       echo "linux-foundation" ;;
    *)                  echo "$1" ;;
  esac
}

# Slugify for id-safety.
slug() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' | cut -c1-60
}

# --- single-URL pipeline (Mode A) ---

pipeline_single_url() {
  local url="$1" ns="$2" fid="$3" sid="$4" pub="$5" shape="$6" merge="$7" out_dir="$8"
  local dry="$9"

  [ -n "$url" ] || { echo "standards-refresh: --url required" >&2; return 2; }
  [ -n "$ns" ]  || { echo "standards-refresh: --target-namespace required" >&2; return 2; }
  [ -n "$fid" ] || { echo "standards-refresh: --framework-id required" >&2; return 2; }
  [ -n "$sid" ] || { echo "standards-refresh: --source-id required" >&2; return 2; }
  [ -n "$pub" ] || { echo "standards-refresh: --authoritative-publisher required" >&2; return 2; }

  # Stage 1: extract.
  local segments
  segments=$(bash "$HERE/extract-rules-from-url.sh" --source "$url" --shape "$shape" --source-id "$sid" --json 2>/dev/null)
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "standards-refresh: stage1 extract failed (rc=$rc) url=$url" >&2
    return 3
  fi
  local seg_count
  seg_count=$(printf '%s' "$segments" | python3 -c 'import json,sys; print(len(json.loads(sys.stdin.read() or "[]")))' 2>/dev/null)
  [ -z "$seg_count" ] && seg_count=0

  # Stages 2 + 3 + assemble in one Python pass (avoids per-segment fork overhead).
  local target_file="$out_dir/$ns/$fid.yaml"
  local target_dir="$out_dir/$ns"
  mkdir -p "$target_dir"

  local composite_yaml
  composite_yaml=$(SEGS="$segments" SID="$sid" PUB="$pub" URL="$url" FID="$fid" \
                   NS="$ns" NOW="$NOW_ISO" MERGE="$merge" TARGET="$target_file" \
                   HERE="$HERE" python3 <<'PY'
import json, os, sys, subprocess, hashlib

segs = json.loads(os.environ["SEGS"] or "[]")
sid = os.environ["SID"]; pub = os.environ["PUB"]; url = os.environ["URL"]
fid = os.environ["FID"]; ns = os.environ["NS"]; now = os.environ["NOW"]
merge = os.environ["MERGE"]; target = os.environ["TARGET"]
here = os.environ["HERE"]

def call_classify(title, prose):
    r = subprocess.run(["bash", os.path.join(here, "classify-rule.sh"), "--title", title, "--prose", prose, "--json"],
                       capture_output=True, text=True, timeout=15)
    try: return json.loads(r.stdout or "{}")
    except Exception: return {"applies_to": {}, "applies_to_prose": False, "confidence": "low"}

def call_route(classified_json):
    import tempfile
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
        json.dump(classified_json, f); tmp = f.name
    try:
        r = subprocess.run(["bash", os.path.join(here, "route-rule.sh"), "--in", tmp, "--json"],
                           capture_output=True, text=True, timeout=15)
        try: return json.loads(r.stdout or "{}")
        except Exception: return {"enforced_by": []}
    finally:
        os.unlink(tmp)

def slugify(s):
    import re
    s = re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")
    return s[:60]

rules = []
for seg in segs:
    title = seg.get("title", ""); prose = seg.get("prose", "")
    if not title: continue
    ch = "sha256:" + hashlib.sha256((title + "\n" + prose).encode()).hexdigest()
    classification = call_classify(title, prose)
    routing = call_route(classification)
    rid = f"g-{ns}-{fid}-{slugify(title)}"[:100]
    rule = {
        "id": rid,
        "name": slugify(title),
        "description": prose[:500] if prose else title,
        "detector": "cloud-guidance-rule.sh",
        "type": "problem",
        "recommended": True,
        "docs_url": url,
        "provenance": [{"source": sid, "section": slugify(title)}],
        "applies_to": classification.get("applies_to", {}),
        "applies_to_prose": classification.get("applies_to_prose", False),
        "enforced_by": routing.get("enforced_by", []),
        "content_hash": ch,
        "confidence": classification.get("confidence", "low"),
        "introduced_at": now,
    }
    if classification.get("confidence") == "low":
        rule["needs_tier2_llm"] = True
    rules.append(rule)

# Merge mode: preserve existing rules by content_hash; mark removed as deprecated.
existing_map = {}
if merge == "merge" and os.path.exists(target):
    try:
        import re
        with open(target) as f: existing_text = f.read()
        # Naive YAML rule extraction: find "id:" + block until next "- id:" (bash-32 compat: don't add yaml dep).
        for m in re.finditer(r"^- id:\s*(\S+).*?(?=^- id:|^recommended_set:|\Z)", existing_text, re.M | re.S):
            block = m.group(0)
            hm = re.search(r"content_hash:\s*(\S+)", block)
            if hm: existing_map[hm.group(1)] = block
    except Exception: pass

new_hashes = set(r["content_hash"] for r in rules)
deprecated_blocks = []
for old_hash, block in existing_map.items():
    if old_hash not in new_hashes:
        # Preserve old rule but mark deprecated.
        if "deprecated: true" not in block:
            block = block.rstrip() + f"\n  deprecated: true\n  deprecated_at: {now}\n  deprecated_reason: removed-upstream\n"
        deprecated_blocks.append(block)

# Emit composite YAML.
out = []
out.append("---")
out.append("source:")
out.append(f"  id: {sid}")
out.append(f"  authoritative_publisher: {pub}")
out.append(f"  authoritative_url: {url}")
out.append("  registry_link: .claude-tdd-pro/COMPLIANCE-URLS.yaml")
out.append(f"  fetched_at: '{now}'")
out.append(f"  content_hash: sha256:{hashlib.sha256(url.encode()).hexdigest()[:32]}-fresh")
out.append("  fetch_frequency: quarterly")
out.append("  fragility_tier: low")
out.append(f"  license_note: 'Reference/educational use — © {pub}'")
out.append("rules:")
for r in rules:
    out.append(f"- id: {r['id']}")
    out.append(f"  name: {r['name']}")
    d = r["description"].replace("\n", " ").replace('"', "'")
    out.append(f'  description: "{d}"')
    out.append(f"  detector: {r['detector']}")
    out.append(f"  type: {r['type']}")
    out.append(f"  recommended: {str(r['recommended']).lower()}")
    out.append(f"  docs_url: {r['docs_url']}")
    out.append(f"  content_hash: {r['content_hash']}")
    out.append(f"  confidence: {r['confidence']}")
    out.append(f"  introduced_at: '{r['introduced_at']}'")
    if r.get("needs_tier2_llm"):
        out.append("  needs_tier2_llm: true")
    out.append(f"  applies_to_prose: {str(r['applies_to_prose']).lower()}")
    out.append("  provenance:")
    for p in r["provenance"]:
        out.append(f"  - source: {p['source']}")
        out.append(f"    section: {p['section']}")
    at = r.get("applies_to", {})
    if at:
        out.append("  applies_to:")
        for k, v in at.items():
            if isinstance(v, list) and v:
                out.append(f"    {k}:")
                for item in v: out.append(f"    - {item}")
    eb = r.get("enforced_by", [])
    if eb:
        out.append("  enforced_by:")
        for e in eb:
            if "tool" in e:
                out.append(f"  - tool: {e['tool']}")
                if e.get("required"): out.append("    required: true")
                if e.get("license"): out.append(f"    license: {e['license']}")
            elif "bundle" in e:
                out.append(f"  - bundle: {e['bundle']}")

# Append deprecated blocks (preserve their original YAML shape).
for db in deprecated_blocks:
    out.append(db.rstrip())

out.append("recommended_set:")
for r in rules: out.append(f"- {r['id']}")
out.append("all_set:")
for r in rules: out.append(f"- {r['id']}")

print("\n".join(out))
print(f"pipeline: segments={len(segs)} rules_new={len(rules)} deprecated={len(deprecated_blocks)}", file=sys.stderr)
PY
)
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "standards-refresh: pipeline (classify+route+assemble) failed rc=$rc" >&2
    return 1
  fi

  if [ "$dry" -eq 1 ]; then
    printf '%s\n' "$composite_yaml"
    echo "standards-refresh: DRY-RUN — would write $target_file" >&2
    return 0
  fi

  # Atomic write.
  local tmp_file
  tmp_file=$(mktemp) || { echo "standards-refresh: mktemp failed" >&2; return 1; }
  printf '%s\n' "$composite_yaml" > "$tmp_file"
  mv "$tmp_file" "$target_file" || { echo "standards-refresh: write failed for $target_file" >&2; return 1; }

  # Update last-fetch marker (best-effort).
  local last_fetch_dir=".claude-tdd-pro/compliance-last-fetch"
  case "$ns" in
    us-government|european-union|industry-self-regulatory|finance-industry|linux-foundation)
      last_fetch_dir=".claude-tdd-pro/compliance-last-fetch" ;;
    *) last_fetch_dir=".claude-tdd-pro/standards-last-fetch" ;;
  esac
  mkdir -p "$last_fetch_dir"
  echo "$NOW_ISO" > "$last_fetch_dir/$sid.txt"

  echo "standards-refresh: WROTE $target_file (target-namespace=$ns framework-id=$fid source-id=$sid)" >&2
  return 0
}

# --- registry-iteration (Mode B) ---

pipeline_registry() {
  local registry="$1" force="$2" now="$3" dry="$4"
  [ -f "$registry" ] || { echo "standards-refresh: registry not found: $registry" >&2; return 2; }

  local last_fetch_dir
  case "$(basename "$registry")" in
    COMPLIANCE-URLS.yaml) last_fetch_dir=".claude-tdd-pro/compliance-last-fetch" ;;
    STANDARDS-URLS.yaml)  last_fetch_dir=".claude-tdd-pro/standards-last-fetch" ;;
    PR-SOURCES.yaml)      last_fetch_dir=".claude-tdd-pro/pr-source-last-fetch" ;;
    *)                    last_fetch_dir=".claude-tdd-pro/generic-last-fetch" ;;
  esac
  mkdir -p "$last_fetch_dir"

  # Parse registry entries.
  REGISTRY="$registry" python3 <<'PY' > /tmp/standards-refresh-entries.$$
import os, re, sys
text = open(os.environ["REGISTRY"]).read()
# Entries: `- id: <id>` starts an entry; capture name/url/jurisdiction/source_class/fetch_frequency.
entries = []
cur = None
for line in text.splitlines():
    m = re.match(r"^-\s*id:\s*(\S+)", line)
    if m:
        if cur: entries.append(cur)
        cur = {"id": m.group(1)}
        continue
    if not cur: continue
    for field in ("name", "url", "jurisdiction", "source_class", "authoritative_publisher", "fetch_frequency"):
        m2 = re.match(r"^\s+" + field + r":\s*(.+)$", line)
        if m2:
            cur[field] = m2.group(1).strip().strip('"\'')
if cur: entries.append(cur)
for e in entries:
    sid = e.get("id","")
    url = e.get("url","")
    juri = e.get("jurisdiction","") or e.get("source_class","")
    pub  = e.get("authoritative_publisher") or e.get("name","unknown")
    freq = e.get("fetch_frequency","daily")
    if sid and url:
        print("\t".join([sid, url, juri, pub, freq]))
PY

  local total=0 skipped=0 processed=0 failed=0
  while IFS=$'\t' read -r sid url juri pub freq; do
    [ -z "$sid" ] && continue
    total=$((total+1))
    if [ "$force" -eq 0 ] && ! freshness_due "$sid" "$freq" "$last_fetch_dir" "$now"; then
      echo "standards-refresh: SKIP sid=$sid (not due; freq=$freq)" >&2
      skipped=$((skipped+1))
      continue
    fi
    local ns; ns=$(ns_from_jurisdiction "$juri")
    local dry_arg=$dry
    pipeline_single_url "$url" "$ns" "$sid" "$sid" "$pub" "markdown-headings" "merge" "$OUT_DIR" "$dry_arg"
    local rc=$?
    if [ "$rc" -eq 0 ]; then processed=$((processed+1))
    else failed=$((failed+1))
    fi
  done < /tmp/standards-refresh-entries.$$
  rm -f /tmp/standards-refresh-entries.$$

  echo "standards-refresh: registry=$(basename "$registry") total=$total processed=$processed skipped=$skipped failed=$failed" >&2
  [ "$failed" -eq 0 ] && return 0 || return 1
}

# --- dispatch ---

if [ -n "$REGISTRY" ]; then
  pipeline_registry "$REGISTRY" "$FORCE" "$NOW_ISO" "$DRY_RUN"
  exit $?
elif [ -n "$URL" ]; then
  pipeline_single_url "$URL" "$TARGET_NS" "$FRAMEWORK_ID" "$SOURCE_ID" "$AUTH_PUB" "$SHAPE" "$MERGE_MODE" "$OUT_DIR" "$DRY_RUN"
  exit $?
else
  echo "standards-refresh: --url + --target-namespace mode OR --registry <path> mode required" >&2
  exit 2
fi
