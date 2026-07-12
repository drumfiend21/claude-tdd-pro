#!/usr/bin/env bash
# commands/standards-refresh.sh — the ADR-0009 line 50 registry-walker orchestrator.
#
# What this script does (Option 3 hybrid — activates existing infrastructure, no new
# architecture invented):
#
#   1. Reads a URL registry (`*-URLS.yaml` under `.claude-tdd-pro/` or `*sources*.yaml`
#      under `standards/` and `pr-corpus/`).
#   2. Per entry: freshness-skip via `<registry>-last-fetch/<source-id>.txt` vs
#      `fetch_frequency` (per §17 S-15/S-16); `--force` overrides.
#   3. Dispatches through `standards/fetcher.sh` (S-2) with `standards/fetchers/http-get.sh`
#      as the upstream stub. Honors the entry's `fragility_tier` + `fragility_strategy`
#      (§2.6). Cache preserved on upstream failure (§16 S-2 discipline).
#   4. Feeds cached content into `commands/extract-rules-from-url.sh` (Stage 1) with
#      shape inferred from the entry's `fetcher:` field (html-anchor.sh → html-sections,
#      markdown-headers.sh → markdown-headings, pdf-section.sh → pdf-sections,
#      rfc-style.sh → free-prose; other/absent → markdown-headings).
#   5. Stages 2 + 3 + 4: classifies each segment (`classify-rule.sh`) + routes each
#      classification (`route-rule.sh`) + auto-binds architectural-content bundle on
#      `applies_to_prose:true` (§28.30).
#   5a. Prose-shape sources (§28.30/§29.4): entries whose `fetcher:` is one of
#      html-anchor.sh / markdown-headers.sh / rfc-style.sh yield PROSE rules, so
#      `applies_to_prose: true` is forced on every rule from that source BEFORE
#      routing — Stage 4 then auto-attaches the architectural-content bundle and
#      the rules fire on ADRs/design prose at design time (§29.4). pdf-section.sh
#      and other fetchers keep the classifier-derived flag.
#   5a2. Sufficiency signal (§31.9 A9 pattern): per source, the summary emits
#      `rule_count=<n> sufficiency=ok|below-threshold-<N>` (`--threshold`, default 30)
#      — a source below the floor fails loud, never silent (signal only; the file is
#      still written and the consuming harness owns the enforcement gate). A source
#      yielding 0 usable rules is REFUSED outright: `INSUFFICIENT` on stderr, entry
#      fails, nothing written (an existing target file from a prior fetch survives).
#   5b. Stage 5 (§28.34 four-layer fidelity): runs `draft-custom-rule.sh` per emitted
#      rule against its routed tool; asserts the `no_clause_dropped` contract; records
#      the per-rule audit trail (`fidelity:` block) in the emitted YAML; binds
#      `prose-judge.sh` into `enforced_by` for fallback clauses. Any rule violating
#      `no_clause_dropped` ⇒ the source's file is REFUSED (entry fails, nothing written).
#   6. Assembles the composite rule YAML with the `introduced_in` epoch tag per §28.40
#      Consumer Compatibility Contract, populates `source:` + `rules[]` + `recommended_set[]`
#      + `all_set[]`.
#   7. Merge (default) preserves rules whose `content_hash` matches (freezing their
#      `introduced_in`); rules absent from the fresh fetch are marked `deprecated: true`
#      with `deprecated_at: <NOW>` reason `removed-upstream`. `--replace` overwrites.
#   8. Atomic write to `<out-dir>/<resolved-namespace>/<framework-id>.yaml`; updates
#      `<registry>-last-fetch/<source-id>.txt`.
#   8b. Stage 6 opt-in (`--gate review-queue`, §28.36): the source's YAML stages under
#      `<out-dir>/_project/<crawl-id>/<resolved-namespace>/<framework-id>.yaml` instead
#      of the official namespace, per-rule Stage 5 draft JSONs are saved alongside at
#      `_project/<crawl-id>/drafts/<framework-id>/`, and `review-queue.sh --dir` routes
#      them (auto-stage / coverage-review / side-by-side-review). Default is
#      human-in-the-loop — nothing auto-staged, nothing touches the official namespace
#      until the operator reviews and promotes. Without `--gate` the default auto-write
#      behavior is byte-identical to before. Gated runs still update last-fetch markers
#      (the fetch happened); use `--force` to re-run ungated inside a freshness window.
#
# Nothing here reimplements what already exists: `standards/fetcher.sh` dispatch,
# per-source shape extractors, extract/classify/route stage commands, 4-axis binding,
# aggregator, §28.40 epoch tag — all reused as-is.
#
# CLI:
#   standards-refresh.sh --registry <path> [--force] [--now <iso>]
#                        [--dry-run] [--out-dir <dir>] [--replace]
#                        [--gate review-queue] [--threshold <n>]
#
# Exit codes:
#   0 ok (some entries may have been freshness-skipped)
#   1 pipeline error (at least one entry failed extract/classify/route, or a rule
#     violated the Stage 5 no_clause_dropped fidelity contract)
#   2 usage error
#   3 registry not found or unparseable
#
# Test affordance: CTP_STAGE5_DRAFT_CMD overrides the Stage 5 script path
# (same CLI as draft-custom-rule.sh) so specs can exercise the refusal path.

set -uo pipefail

REGISTRY=""; FORCE=0; NOW_ISO=""; DRY_RUN=0; OUT_DIR=""; MERGE_MODE="merge"; GATE=""; THRESHOLD=30

while [ $# -gt 0 ]; do
  case "$1" in
    --registry) REGISTRY="${2-}"; shift 2 ;;
    --force)    FORCE=1;          shift   ;;
    --now)      NOW_ISO="${2-}";  shift 2 ;;
    --dry-run)  DRY_RUN=1;        shift   ;;
    --out-dir)  OUT_DIR="${2-}";  shift 2 ;;
    --replace)  MERGE_MODE="replace"; shift ;;
    --merge)    MERGE_MODE="merge";   shift ;;
    --gate)     GATE="${2-}";     shift 2 ;;
    --threshold) THRESHOLD="${2-}"; shift 2 ;;
    -h|--help)
      sed -n '2,70p' "$0" | sed 's/^# \{0,1\}//' >&2
      exit 0 ;;
    *) echo "standards-refresh: unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -n "$REGISTRY" ] || { echo "standards-refresh: --registry <path> required" >&2; exit 2; }
[ -f "$REGISTRY" ] || { echo "standards-refresh: registry not found: $REGISTRY" >&2; exit 3; }
if [ -n "$GATE" ] && [ "$GATE" != "review-queue" ]; then
  echo "standards-refresh: unknown --gate mode: $GATE (supported: review-queue)" >&2; exit 2
fi
case "$THRESHOLD" in
  ''|*[!0-9]*) echo "standards-refresh: --threshold must be a non-negative integer, got: $THRESHOLD" >&2; exit 2 ;;
esac

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
[ -z "$OUT_DIR" ] && OUT_DIR="$PLUGIN_ROOT/generated-code-quality-standards"
[ -z "$NOW_ISO" ] && NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
HERE="$(cd "$(dirname "$0")" && pwd -P)"
# Crawl id for review-queue staging: registry basename + colon-free run timestamp.
CRAWL_ID="$(basename "$REGISTRY" | sed 's/\.[^.]*$//')-$(printf '%s' "$NOW_ISO" | tr -d ':')"

# --- helpers ---

# Parse fetch_frequency into seconds. Accepts daily|weekly|monthly|quarterly|on-demand
# or numeric formats like 30m, 6h, 1d, 2w, 1mo.
freq_to_seconds() {
  local freq="$1"
  case "$freq" in
    daily)     echo 86400 ;;
    weekly)    echo 604800 ;;
    monthly)   echo 2592000 ;;
    quarterly) echo 7776000 ;;
    on-demand) echo 315360000 ;;
    "")        echo 86400 ;;
    *)
      local n="${freq%[mhdwo]*}" unit="${freq#$n}"
      case "$unit" in
        m)  echo $((n * 60)) ;;
        h)  echo $((n * 3600)) ;;
        d)  echo $((n * 86400)) ;;
        w)  echo $((n * 604800)) ;;
        mo) echo $((n * 2592000)) ;;
        *)  echo 86400 ;;
      esac ;;
  esac
}

# Compare epochs (bash 3.2 compatible; python3 for ISO parsing).
iso_to_epoch() {
  ISO="$1" python3 -c 'import os,datetime; s=os.environ["ISO"].replace("Z","+00:00"); print(int(datetime.datetime.fromisoformat(s).timestamp()))' 2>/dev/null
}

# freshness_due sid freq marker-dir now_iso -> 0 if due (or never fetched), 1 if within window.
freshness_due() {
  local sid="$1" freq="$2" dir="$3" now="$4"
  local marker="$dir/$sid.txt"
  [ -f "$marker" ] || return 0
  local last; last=$(head -1 "$marker" 2>/dev/null)
  [ -n "$last" ] || return 0
  local now_e last_e
  now_e=$(iso_to_epoch "$now"); last_e=$(iso_to_epoch "$last")
  [ -n "$now_e" ] && [ -n "$last_e" ] || return 0
  local age=$((now_e - last_e)) win; win=$(freq_to_seconds "$freq")
  [ "$age" -ge "$win" ]
}

# Namespace resolution per §17 G-9. Compliance jurisdictions → jurisdictional namespace;
# standards entries fall back to the entry's declared source_namespace or `_universal`.
resolve_namespace() {
  local juri="$1" src_class="$2" src_ns="$3"
  if [ -n "$juri" ]; then
    case "$juri" in
      us-government|federal-financial-regulator)   echo "us-government"; return ;;
      european-union)                              echo "european-union"; return ;;
      international)                               echo "industry-self-regulatory"; return ;;
      gold-standard-process)                       echo "linux-foundation"; return ;;
    esac
  fi
  if [ -n "$src_class" ]; then
    case "$src_class" in
      financial-industry) echo "finance-industry"; return ;;
      federal-financial-regulator) echo "us-government"; return ;;
    esac
  fi
  if [ -n "$src_ns" ]; then echo "$src_ns"; return; fi
  echo "_universal"
}

# Shape inference from the entry's fetcher: field. This is the mapping declared by
# ADR-0009 line 51 combined with §17 S-2 per-source fetcher naming.
shape_from_fetcher() {
  case "$1" in
    html-anchor.sh)      echo "html-sections" ;;
    markdown-headers.sh) echo "markdown-headings" ;;
    pdf-section.sh)      echo "pdf-sections" ;;
    rfc-style.sh)        echo "free-prose" ;;
    *)                   echo "markdown-headings" ;;
  esac
}

# Fragility-tier defaults when the entry does not declare one.
default_fragility_tier() { echo "${1:-medium}"; }
default_fragility_strategy() {
  case "${1:-}" in
    high)   echo "silent-replace" ;;
    low)    echo "manual-only" ;;
    *)      echo "prompt-on-change" ;;
  esac
}

# Marker dir per registry filename.
last_fetch_dir() {
  case "$(basename "$1")" in
    COMPLIANCE-URLS.yaml)  echo ".claude-tdd-pro/compliance-last-fetch" ;;
    STANDARDS-URLS.yaml)   echo ".claude-tdd-pro/standards-last-fetch"  ;;
    PR-SOURCES.yaml)       echo ".claude-tdd-pro/pr-source-last-fetch"  ;;
    *sources*.yaml)        echo ".claude-tdd-pro/standards-last-fetch"  ;;
    *)                     echo ".claude-tdd-pro/generic-last-fetch"    ;;
  esac
}

# --- Parse registry into a tab-separated stream (bash 3.2 friendly). ---

REGISTRY="$REGISTRY" python3 <<'PY' > /tmp/standards-refresh-entries.$$
import os, re, sys
text = open(os.environ["REGISTRY"]).read()
entries = []
cur = None
for line in text.splitlines():
    m = re.match(r"^-\s*id:\s*(\S+)", line)
    if m:
        if cur: entries.append(cur)
        cur = {"id": m.group(1)}
        continue
    if not cur: continue
    for field in ("name","url","jurisdiction","source_class","source_namespace",
                  "authoritative_publisher","fetch_frequency","fetcher",
                  "fragility_tier","fragility_strategy","paywalled","document_url"):
        m2 = re.match(r"^\s+" + field + r":\s*(.+)$", line)
        if m2:
            v = m2.group(1).strip().strip('"\'').rstrip()
            cur[field] = v
    # applies_to: [item, item] list — take first item as namespace hint.
    m3 = re.match(r"^\s+applies_to:\s*\[(.+)\]", line)
    if m3:
        items = [x.strip().strip('"\'') for x in m3.group(1).split(",") if x.strip()]
        if items: cur["applies_to_first"] = items[0]
if cur: entries.append(cur)
for e in entries:
    sid = e.get("id",""); url = e.get("url","") or e.get("document_url","")
    if not sid or not url: continue
    # Prefer explicit source_namespace; else applies_to[0]; else empty (falls to _universal).
    src_ns = e.get("source_namespace") or e.get("applies_to_first","")
    print("|".join([
        sid, url, e.get("jurisdiction",""), e.get("source_class",""),
        src_ns,
        e.get("authoritative_publisher") or e.get("name","unknown"),
        e.get("fetch_frequency","daily"), e.get("fetcher","markdown-headers.sh"),
        e.get("fragility_tier","medium"), e.get("fragility_strategy",""),
    ]))
PY

# --- Per-entry pipeline (invoked once per registry entry). ---

process_entry() {
  local sid="$1" url="$2" juri="$3" src_class="$4" src_ns="$5" pub="$6" freq="$7" fetcher="$8" ftier="$9" fstrat="${10}"

  local target_ns; target_ns=$(resolve_namespace "$juri" "$src_class" "$src_ns")
  local shape; shape=$(shape_from_fetcher "$fetcher")
  [ -z "$ftier" ]  && ftier=$(default_fragility_tier "")
  [ -z "$fstrat" ] && fstrat=$(default_fragility_strategy "$ftier")

  # Layer 1: cache-preserving fetch via existing S-2 dispatch.
  local cache_dir="$PLUGIN_ROOT/.claude-tdd-pro/standards-cache"
  mkdir -p "$cache_dir"
  local cache_file="$cache_dir/$sid.html"
  local meta_file; meta_file=$(mktemp)

  URL="$url" bash "$PLUGIN_ROOT/standards/fetcher.sh" \
      --source-id "$sid" \
      --fragility-tier "$ftier" \
      --strategy "$fstrat" \
      --upstream-stub "$PLUGIN_ROOT/standards/fetchers/http-get.sh" \
      --cache "$cache_dir" \
      --emit-metadata "$meta_file" \
      --auto --no-confirm-default 2>/dev/null
  local frc=$?
  rm -f "$meta_file"

  if [ "$frc" -ne 0 ] || [ ! -s "$cache_file" ]; then
    echo "standards-refresh: SKIP sid=$sid (fetch failed or cache empty rc=$frc)" >&2
    return 0   # cache-preserved skip is not a failure
  fi

  # Layer 2: extract via Stage 1 (extended to 5 shapes per ADR-0009 line 51).
  local segments
  segments=$(bash "$HERE/extract-rules-from-url.sh" --source "$cache_file" --shape "$shape" --source-id "$sid" --json 2>/dev/null)
  local xrc=$?
  if [ "$xrc" -ne 0 ]; then
    echo "standards-refresh: FAIL sid=$sid (extract rc=$xrc)" >&2
    return 1
  fi

  # Stage 6 opt-in (§28.36): stage under _project/<crawl-id>/ instead of the
  # official namespace; save per-rule Stage 5 drafts for review-queue routing.
  local target_file drafts_dir=""
  if [ "$GATE" = "review-queue" ]; then
    target_file="$OUT_DIR/_project/$CRAWL_ID/$target_ns/$sid.yaml"
    if [ "$DRY_RUN" -eq 0 ]; then
      drafts_dir="$OUT_DIR/_project/$CRAWL_ID/drafts/$sid"
      mkdir -p "$OUT_DIR/_project/$CRAWL_ID/$target_ns" "$drafts_dir"
    fi
  else
    target_file="$OUT_DIR/$target_ns/$sid.yaml"
    mkdir -p "$OUT_DIR/$target_ns"
  fi

  # Layer 3+4+5: classify + route + assemble YAML with §28.40 introduced_in epoch.
  local composite_yaml
  composite_yaml=$(SEGS="$segments" SID="$sid" PUB="$pub" URL="$url" \
                   NS="$target_ns" NOW="$NOW_ISO" MERGE="$MERGE_MODE" \
                   TARGET="$target_file" HERE="$HERE" FREQ="$freq" SHAPE="$shape" \
                   DRAFTS_DIR="$drafts_dir" FETCHER="$fetcher" THRESHOLD="$THRESHOLD" python3 <<'PY'
import json, os, sys, subprocess, hashlib, re

segs = json.loads(os.environ["SEGS"] or "[]")
sid = os.environ["SID"]; pub = os.environ["PUB"]; url = os.environ["URL"]
ns = os.environ["NS"]; now = os.environ["NOW"]; merge = os.environ["MERGE"]
target = os.environ["TARGET"]; here = os.environ["HERE"]; freq = os.environ["FREQ"]

def call_classify(title, prose):
    try:
        r = subprocess.run(["bash", os.path.join(here, "classify-rule.sh"),
                            "--title", title, "--prose", prose, "--json"],
                           capture_output=True, text=True, timeout=15)
        return json.loads(r.stdout or "{}")
    except Exception:
        return {"applies_to": {}, "applies_to_prose": False, "confidence": "low"}

def call_route(classified_json):
    import tempfile
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
        json.dump(classified_json, f); tmp = f.name
    try:
        r = subprocess.run(["bash", os.path.join(here, "route-rule.sh"), "--in", tmp, "--json"],
                           capture_output=True, text=True, timeout=15)
        return json.loads(r.stdout or "{}")
    except Exception:
        return {"enforced_by": []}
    finally:
        os.unlink(tmp)

# Stage 5 (§28.34): four-layer fidelity draft. Returns the draft JSON, or None
# when Stage 5 itself is unavailable/crashed (treated as a contract violation —
# fail closed; the no_clause_dropped assertion cannot be silently skipped).
def call_draft(rule_id, prose, tool):
    cmd = os.environ.get("CTP_STAGE5_DRAFT_CMD") or os.path.join(here, "draft-custom-rule.sh")
    try:
        r = subprocess.run(["bash", cmd, "--rule-id", rule_id, "--prose", prose,
                            "--tool", tool, "--json"],
                           capture_output=True, text=True, timeout=30)
        if r.returncode not in (0, 1):
            return None
        return json.loads(r.stdout or "null")
    except Exception:
        return None

def slugify(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")[:60]

# Read existing rules from target (bash-3.2 friendly: naive block scan; no yaml dep).
existing = {}     # content_hash -> {"introduced_in": iso, "block": raw yaml block}
if merge == "merge" and os.path.exists(target):
    try:
        old = open(target).read()
        for m in re.finditer(r"^- id:\s*(\S+).*?(?=^- id:|^recommended_set:|\Z)", old, re.M | re.S):
            block = m.group(0)
            hm = re.search(r"content_hash:\s*(\S+)", block)
            im = re.search(r"introduced_in:\s*['\"]?([^'\"\n]+)['\"]?", block)
            if hm:
                existing[hm.group(1)] = {"introduced_in": (im.group(1).strip() if im else now), "block": block}
    except Exception:
        pass

rules = []
fidelity_violations = []
fid_totals = {"clauses_total": 0, "clauses_covered": 0, "clauses_fallback": 0, "clauses_unenforceable": 0}
for seg in segs:
    title = seg.get("title","").strip(); prose = seg.get("prose","").strip()
    if not title: continue
    ch = "sha256:" + hashlib.sha256((title + "\n" + prose).encode()).hexdigest()
    classification = call_classify(title, prose)
    # §28.30/§29.4: prose-shape sources yield prose rules — force the flag BEFORE
    # routing so Stage 4 auto-attaches the architectural-content bundle.
    if os.environ.get("FETCHER", "") in ("html-anchor.sh", "markdown-headers.sh", "rfc-style.sh"):
        classification["applies_to_prose"] = True
    routing = call_route(classification)
    # §28.40 Consumer Compatibility Contract: freeze introduced_in when content_hash matches.
    intro = existing.get(ch, {}).get("introduced_in", now)
    rid = ("g-" + ns + "-" + sid + "-" + slugify(title))[:100]
    rule = {
        "id": rid, "name": slugify(title),
        "description": (prose[:500] or title),
        "detector": "cloud-guidance-rule.sh", "type": "problem",
        "recommended": True, "docs_url": url,
        "provenance": [{"source": sid, "section": slugify(title)}],
        "applies_to": classification.get("applies_to", {}),
        "applies_to_prose": classification.get("applies_to_prose", False),
        "enforced_by": routing.get("enforced_by", []),
        "content_hash": ch,
        "confidence": classification.get("confidence", "low"),
        "introduced_in": intro,
    }
    if classification.get("confidence") == "low":
        rule["needs_tier2_llm"] = True
    # Stage 5 (§28.34): four-layer fidelity against the rule's first routed tool
    # (Layer D binds uncovered clauses to prose-judge.sh regardless of tool choice).
    tool = "semgrep"
    for e in rule["enforced_by"]:
        if isinstance(e, dict) and e.get("tool"):
            tool = e["tool"]; break
    draft = call_draft(rid, prose or title, tool)
    dropped = (draft is None) or (not draft.get("no_clause_dropped", False))
    if dropped:
        fidelity_violations.append(rid)
    fid = {
        "clauses_total": (draft or {}).get("clauses_total", 0),
        "clauses_covered": (draft or {}).get("clauses_covered", 0),
        "clauses_fallback": (draft or {}).get("clauses_fallback", 0),
        "clauses_unenforceable": (draft or {}).get("clauses_unenforceable", 0),
        "no_clause_dropped": not dropped,
        "needs_operator_signoff": bool((draft or {}).get("needs_operator_signoff", False)),
    }
    for k in fid_totals: fid_totals[k] += fid[k]
    rule["fidelity"] = fid
    # Fallback clauses are semantically enforced via the prose-judge moat (§28.34 Layer D).
    if fid["clauses_fallback"] > 0 and not any(
            isinstance(e, dict) and e.get("tool") == "prose-judge.sh" for e in rule["enforced_by"]):
        rule["enforced_by"] = list(rule["enforced_by"]) + [{"tool": "prose-judge.sh"}]
    rule["_draft"] = draft
    rules.append(rule)

# THE CONTRACT (§28.34): no clause silently dropped, per rule, or the file is refused.
if fidelity_violations:
    sys.stderr.write("standards-refresh: FIDELITY-VIOLATION sid=" + sid
                     + " rules=" + ",".join(fidelity_violations)
                     + " no_clause_dropped=false — refusing to write " + target + "\n")
    sys.exit(1)

# Sufficiency signal (§31.9 A9 pattern): 0 usable rules ⇒ the file is refused
# (existing target from a prior fetch survives); below the floor ⇒ fails loud
# on stderr but the file is still written (the consuming harness owns the gate).
threshold = int(os.environ.get("THRESHOLD", "30"))
if not rules:
    sys.stderr.write("standards-refresh: INSUFFICIENT sid=" + sid
                     + " rule_count=0 sufficiency=below-threshold-" + str(threshold)
                     + " — refusing to write " + target + "\n")
    sys.exit(1)
suff = "ok" if len(rules) >= threshold else "below-threshold-" + str(threshold)
sys.stderr.write("standards-refresh: sufficiency sid=" + sid
                 + " rule_count=" + str(len(rules)) + " sufficiency=" + suff + "\n")

# Stage 6 staging (§28.36): persist per-rule Stage 5 drafts for review-queue routing.
drafts_dir = os.environ.get("DRAFTS_DIR", "")
for r in rules:
    d = r.pop("_draft", None)
    if drafts_dir and d is not None:
        with open(os.path.join(drafts_dir, r["id"] + ".json"), "w") as f:
            json.dump(d, f)

# Deprecated: rules present in existing but absent from fresh fetch.
new_hashes = {r["content_hash"] for r in rules}
deprecated_blocks = []
for ch, meta in existing.items():
    if ch not in new_hashes:
        b = meta["block"]
        if "deprecated: true" not in b:
            b = b.rstrip() + "\n  deprecated: true\n  deprecated_at: " + now + "\n  deprecated_reason: removed-upstream\n"
        deprecated_blocks.append(b)

# Compose YAML (bash-3.2 friendly; no PyYAML).
out = ["---", "source:", "  id: " + sid,
       "  authoritative_publisher: " + pub, "  authoritative_url: " + url,
       "  registry_link: " + os.path.basename(os.environ.get("REGISTRY","")),
       "  fetched_at: '" + now + "'",
       "  content_hash: sha256:" + hashlib.sha256(url.encode()).hexdigest()[:32] + "-fresh",
       "  fetch_frequency: " + (freq or "daily"),
       "  fragility_tier: medium",
       "  license_note: 'Reference/educational use - " + pub + "'",
       "rules:"]
for r in rules:
    out.append("- id: " + r["id"])
    out.append("  name: " + r["name"])
    d = r["description"].replace("\n", " ").replace('"', "'")
    out.append('  description: "' + d + '"')
    out.append("  detector: " + r["detector"])
    out.append("  type: " + r["type"])
    out.append("  recommended: " + str(r["recommended"]).lower())
    out.append("  docs_url: " + r["docs_url"])
    out.append("  content_hash: " + r["content_hash"])
    out.append("  confidence: " + r["confidence"])
    out.append("  introduced_in: '" + r["introduced_in"] + "'")
    if r.get("needs_tier2_llm"): out.append("  needs_tier2_llm: true")
    fid = r.get("fidelity")
    if fid:
        out.append("  fidelity:")
        out.append("    clauses_total: " + str(fid["clauses_total"]))
        out.append("    clauses_covered: " + str(fid["clauses_covered"]))
        out.append("    clauses_fallback: " + str(fid["clauses_fallback"]))
        out.append("    clauses_unenforceable: " + str(fid["clauses_unenforceable"]))
        out.append("    no_clause_dropped: " + str(fid["no_clause_dropped"]).lower())
        out.append("    needs_operator_signoff: " + str(fid["needs_operator_signoff"]).lower())
    out.append("  applies_to_prose: " + str(r["applies_to_prose"]).lower())
    out.append("  provenance:")
    for p in r["provenance"]:
        out.append("  - source: " + p["source"])
        out.append("    section: " + p["section"])
    at = r.get("applies_to", {})
    if at:
        out.append("  applies_to:")
        for k, v in at.items():
            if isinstance(v, list) and v:
                out.append("    " + k + ":")
                for it in v: out.append("    - " + str(it))
    eb = r.get("enforced_by", [])
    if eb:
        out.append("  enforced_by:")
        for e in eb:
            if "tool" in e:
                out.append("  - tool: " + e["tool"])
                if e.get("required"): out.append("    required: true")
                if e.get("license"): out.append("    license: " + e["license"])
            elif "bundle" in e:
                out.append("  - bundle: " + e["bundle"])
for db in deprecated_blocks:
    out.append(db.rstrip())
out.append("recommended_set:")
for r in rules: out.append("- " + r["id"])
out.append("all_set:")
for r in rules: out.append("- " + r["id"])

sys.stdout.write("\n".join(out) + "\n")
sys.stderr.write("pipeline sid=" + sid + " ns=" + ns + " shape=" + os.environ.get("SHAPE","") + " segments=" + str(len(segs)) + " rules_new=" + str(len(rules)) + " deprecated=" + str(len(deprecated_blocks))
                 + " stage5=ok clauses_total=" + str(fid_totals["clauses_total"])
                 + " covered=" + str(fid_totals["clauses_covered"])
                 + " fallback=" + str(fid_totals["clauses_fallback"])
                 + " unenforceable=" + str(fid_totals["clauses_unenforceable"]) + "\n")
PY
)
  local arc=$?
  if [ "$arc" -ne 0 ]; then
    echo "standards-refresh: FAIL sid=$sid (assemble rc=$arc)" >&2
    return 1
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '%s\n' "$composite_yaml"
    echo "standards-refresh: DRY-RUN sid=$sid target=$target_file" >&2
    return 0
  fi

  local tmp; tmp=$(mktemp) || return 1
  printf '%s' "$composite_yaml" > "$tmp"
  mv "$tmp" "$target_file" || return 1

  local mdir; mdir=$(last_fetch_dir "$REGISTRY")
  mkdir -p "$mdir"
  echo "$NOW_ISO" > "$mdir/$sid.txt"

  if [ "$GATE" = "review-queue" ]; then
    # Stage 6 (§28.36): route the staged drafts. Default human-in-the-loop —
    # no --auto-accept passed; nothing reaches the official namespace here.
    bash "$HERE/review-queue.sh" --dir "$drafts_dir"
    echo "standards-refresh: STAGED sid=$sid crawl=$CRAWL_ID ns=$target_ns file=$target_file (review-queue gate; promote after review)" >&2
  else
    echo "standards-refresh: WROTE sid=$sid ns=$target_ns file=$target_file" >&2
  fi
  return 0
}

# --- Main loop: walk entries, freshness-skip, delegate. ---

MARKER_DIR=$(last_fetch_dir "$REGISTRY")
mkdir -p "$MARKER_DIR"

TOTAL=0; PROCESSED=0; SKIPPED=0; FAILED=0
export REGISTRY
while IFS='|' read -r sid url juri src_class src_ns pub freq fetcher ftier fstrat; do
  [ -n "$sid" ] || continue
  TOTAL=$((TOTAL + 1))
  if [ "$FORCE" -eq 0 ] && ! freshness_due "$sid" "$freq" "$MARKER_DIR" "$NOW_ISO"; then
    echo "standards-refresh: SKIP sid=$sid (not due; freq=$freq)" >&2
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
  if process_entry "$sid" "$url" "$juri" "$src_class" "$src_ns" "$pub" "$freq" "$fetcher" "$ftier" "$fstrat"; then
    PROCESSED=$((PROCESSED + 1))
  else
    FAILED=$((FAILED + 1))
  fi
done < /tmp/standards-refresh-entries.$$
rm -f /tmp/standards-refresh-entries.$$

echo "standards-refresh: registry=$(basename "$REGISTRY") total=$TOTAL processed=$PROCESSED skipped=$SKIPPED failed=$FAILED" >&2
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
