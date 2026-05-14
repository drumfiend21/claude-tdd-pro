#!/usr/bin/env bash
# rubric-runner — execute RUBRIC.yaml detectors against the working tree.
#
# Modes:
#   --full          run every detector against the entire working tree
#   --diff          run detectors against `git diff HEAD` only
#   --staged        run detectors against `git diff --cached` only
#   --rule <id>     run only the rule with that id
#   --severity <p>  filter findings by min severity (P0|P1|P2). Default P1.
#   --json          emit JSON to stdout (default)
#   --md            emit Markdown summary to stdout
#   --quiet         no findings → exit 0; any finding → exit 2 (block hook)
#
# Inputs:
#   RUBRIC.yaml at ${CLAUDE_PLUGIN_ROOT}/rubric/RUBRIC.yaml
#
# Detector dispatch:
#   kind: lint    → eslint with the google config (or project's if present)
#   kind: tsc     → tsc --noEmit + flags from rule's detector.ref
#   kind: ruff    → ruff check --select <codes>
#   kind: mypy    → mypy with rule's flags
#   kind: pylint  → pylint --rcfile <google.rc>
#   kind: script  → ${PLUGIN_ROOT}/rubric/detectors/<ref>
#   kind: llm     → emits a deferred finding the agent layer must judge
#
# Behavior is deliberately conservative: tools that aren't installed
# produce a "skipped" finding, never an error. The Stop-hook caller
# treats P0 findings as blocking.

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
RUBRIC="${PLUGIN_ROOT}/rubric/RUBRIC.yaml"

# F-0 lock-version pre-check (per §2.7): if a lock file exists, refuse to
# run when its plugin_version disagrees with the installed plugin. Forces
# the operator to /migrate before continuing. No-op when no lock file
# exists (back-compat with installs predating CL-45).
LOCK_FILE="$PROJECT_DIR/.claude-tdd-pro/lock.json"
if [[ -f "$LOCK_FILE" ]] && command -v node >/dev/null 2>&1; then
  if ! bash "$PLUGIN_ROOT/rubric/lock.sh" --check --lock-path "$LOCK_FILE" >&2 2>&1; then
    echo "rubric/runner: refusing to start due to lock plugin_version mismatch" >&2
    exit 2
  fi
fi

MODE="full"
RULE_FILTER=""
SEVERITY_MIN="P1"
OUTPUT="json"
QUIET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --full)     MODE="full"; shift ;;
    --diff)     MODE="diff"; shift ;;
    --staged)   MODE="staged"; shift ;;
    --rule)     RULE_FILTER="$2"; shift 2 ;;
    --severity) SEVERITY_MIN="$2"; shift 2 ;;
    --json)     OUTPUT="json"; shift ;;
    --md)       OUTPUT="md"; shift ;;
    --quiet)    QUIET=1; shift ;;
    *) echo "rubric-runner: unknown arg: $1" >&2; exit 64 ;;
  esac
done

if [[ ! -f "$RUBRIC" ]]; then
  echo '{"error":"RUBRIC.yaml not found","path":"'"$RUBRIC"'"}' >&2
  exit 64
fi

# Build the file set once based on mode. JSON-array of paths.
build_file_set() {
  case "$MODE" in
    full)
      git -C "$PROJECT_DIR" ls-files 2>/dev/null \
        | grep -Ev '^(node_modules|dist|build|\.git|\.venv|venv|__pycache__)/' \
        || true
      ;;
    diff)
      git -C "$PROJECT_DIR" diff --name-only HEAD 2>/dev/null || true
      ;;
    staged)
      git -C "$PROJECT_DIR" diff --cached --name-only 2>/dev/null || true
      ;;
  esac
}

FILE_SET="$(build_file_set)"

# Stable detector helpers. Each emits findings in JSON-line form:
#   {"rule":"<id>","severity":"<P>","file":"<path>","line":<n>,"msg":"<text>"}
findings_file="$(mktemp -t rubric-findings.XXXXXX.jsonl)"
trap 'rm -f "$findings_file"' EXIT

emit_finding() {
  local rule="$1" severity="$2" file="$3" line="$4" msg="$5"
  printf '{"rule":"%s","severity":"%s","file":"%s","line":%s,"msg":"%s"}\n' \
    "$rule" "$severity" "$file" "$line" "${msg//\"/\\\"}" >> "$findings_file"
}

emit_skipped() {
  local rule="$1" reason="$2"
  printf '{"rule":"%s","severity":"SKIP","file":"","line":0,"msg":"%s"}\n' \
    "$rule" "${reason//\"/\\\"}" >> "$findings_file"
}

# ---------------------------------------------------------------------------
# YAML parsing — minimal grep-based reader. We read RUBRIC.yaml once
# and emit a TSV stream (id\tseverity\tdetector_kind\tdetector_ref\tlanguages).
# Avoids a yq dependency.
# ---------------------------------------------------------------------------

parse_rubric() {
  awk '
    /^  - id:/         { id=$3; sev=""; kind=""; ref=""; langs=""; in_det=0 }
    /^    severity:/   { sev=$2 }
    /^    detector:/   { in_det=1; next }
    /^    remediation:/{ in_det=0; next }
    /^    languages:/  { gsub(/[\[\],]/,""); langs=substr($0, index($0,$2)) }
    /^      kind:/     { if (in_det) kind=$2 }
    /^      ref:/      { if (in_det) {
                            r=$0; sub(/^      ref: */,"",r);
                            gsub(/^"|"$/,"",r); ref=r
                          }
                       }
    /^  - id:/ && id!=""  { print prev_id"\t"prev_sev"\t"prev_kind"\t"prev_ref"\t"prev_langs }
    { prev_id=id; prev_sev=sev; prev_kind=kind; prev_ref=ref; prev_langs=langs }
    END { if (id!="") print id"\t"sev"\t"kind"\t"ref"\t"langs }
  ' "$RUBRIC" | awk -F'\t' 'NF>=4 && $1!=""'
}

# ---------------------------------------------------------------------------
# Detector dispatch
# ---------------------------------------------------------------------------

run_eslint() {
  local rule="$1" sev="$2" eslint_rule="$3"
  command -v npx >/dev/null 2>&1 || { emit_skipped "$rule" "npx not on PATH"; return; }
  if ! [[ -d "$PROJECT_DIR/node_modules/eslint" || -f "$PROJECT_DIR/eslint.config.js" || -f "$PROJECT_DIR/.eslintrc.json" || -f "$PROJECT_DIR/.eslintrc.cjs" ]]; then
    emit_skipped "$rule" "no eslint config in project"
    return
  fi
  local files
  if [[ "$MODE" == "full" ]]; then
    files="$(echo "$FILE_SET" | grep -E '\.(js|jsx|ts|tsx|mjs|cjs)$' | tr '\n' ' ')"
  else
    files="$(echo "$FILE_SET" | grep -E '\.(js|jsx|ts|tsx|mjs|cjs)$' | tr '\n' ' ')"
  fi
  [[ -z "$files" ]] && return
  local out
  out="$(cd "$PROJECT_DIR" && npx --no-install eslint --no-error-on-unmatched-pattern \
       --format json --rule "{\"$eslint_rule\":\"error\"}" $files 2>/dev/null || true)"
  [[ -z "$out" || "$out" == "[]" ]] && return
  echo "$out" | python3 - "$rule" "$sev" <<'PY'
import json, sys
rule, sev = sys.argv[1], sys.argv[2]
try:
    data = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
for f in data:
    for m in f.get("messages", []):
        if m.get("severity",1) >= 2:
            print(json.dumps({
                "rule": rule, "severity": sev,
                "file": f.get("filePath",""),
                "line": m.get("line", 0),
                "msg":  m.get("message","")
            }))
PY
}

run_ruff() {
  local rule="$1" sev="$2" codes="$3"
  command -v ruff >/dev/null 2>&1 || { emit_skipped "$rule" "ruff not installed"; return; }
  local files
  files="$(echo "$FILE_SET" | grep -E '\.py$' | tr '\n' ' ')"
  [[ -z "$files" ]] && return
  local out
  out="$(cd "$PROJECT_DIR" && ruff check --select "$codes" --output-format json $files 2>/dev/null || true)"
  [[ -z "$out" || "$out" == "[]" ]] && return
  echo "$out" | python3 - "$rule" "$sev" <<'PY'
import json, sys
rule, sev = sys.argv[1], sys.argv[2]
try:
    data = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
for m in data:
    print(json.dumps({
        "rule": rule, "severity": sev,
        "file": m.get("filename",""),
        "line": (m.get("location") or {}).get("row", 0),
        "msg":  m.get("code","") + ": " + m.get("message","")
    }))
PY
}

run_mypy() {
  local rule="$1" sev="$2" flags="$3"
  command -v mypy >/dev/null 2>&1 || { emit_skipped "$rule" "mypy not installed"; return; }
  local files
  files="$(echo "$FILE_SET" | grep -E '\.py$' | tr '\n' ' ')"
  [[ -z "$files" ]] && return
  local out
  out="$(cd "$PROJECT_DIR" && mypy $flags --no-error-summary --show-column-numbers $files 2>&1 || true)"
  echo "$out" | grep -E ':[0-9]+:[0-9]+: error:' | python3 - "$rule" "$sev" <<'PY'
import sys, json, re
rule, sev = sys.argv[1], sys.argv[2]
pat = re.compile(r"^(?P<file>[^:]+):(?P<line>\d+):\d+: error: (?P<msg>.+)$")
for line in sys.stdin:
    m = pat.match(line.strip())
    if m:
        print(json.dumps({
            "rule": rule, "severity": sev,
            "file": m.group("file"),
            "line": int(m.group("line")),
            "msg":  m.group("msg"),
        }))
PY
}

run_tsc() {
  local rule="$1" sev="$2" flags="$3"
  if ! [[ -f "$PROJECT_DIR/tsconfig.json" ]]; then emit_skipped "$rule" "no tsconfig.json"; return; fi
  command -v npx >/dev/null 2>&1 || { emit_skipped "$rule" "npx not on PATH"; return; }
  local out
  out="$(cd "$PROJECT_DIR" && npx --no-install tsc --noEmit $flags 2>&1 || true)"
  echo "$out" | grep -E '\([0-9]+,[0-9]+\): error' | python3 - "$rule" "$sev" <<'PY'
import sys, json, re
rule, sev = sys.argv[1], sys.argv[2]
pat = re.compile(r"^(?P<file>[^(]+)\((?P<line>\d+),\d+\): error (?P<code>TS\d+): (?P<msg>.+)$")
for line in sys.stdin:
    m = pat.match(line.strip())
    if m:
        print(json.dumps({
            "rule": rule, "severity": sev,
            "file": m.group("file").strip(),
            "line": int(m.group("line")),
            "msg":  m.group("code") + ": " + m.group("msg"),
        }))
PY
}

run_script() {
  local rule="$1" sev="$2" script_name="$3"
  local script_path="${PLUGIN_ROOT}/rubric/detectors/${script_name}"
  if [[ ! -x "$script_path" ]]; then emit_skipped "$rule" "detector script missing or not exec: $script_name"; return; fi
  RULE_ID="$rule" SEVERITY="$sev" MODE="$MODE" "$script_path"
}

emit_llm_deferred() {
  local rule="$1" sev="$2" agent_ref="$3"
  printf '{"rule":"%s","severity":"%s","file":"","line":0,"msg":"DEFERRED: requires agent %s"}\n' \
    "$rule" "$sev" "$agent_ref" >> "$findings_file"
}

# ---------------------------------------------------------------------------
# Severity threshold
# ---------------------------------------------------------------------------

severity_rank() { case "$1" in P0) echo 0 ;; P1) echo 1 ;; P2) echo 2 ;; *) echo 9 ;; esac; }
SEV_MIN_RANK="$(severity_rank "$SEVERITY_MIN")"

passes_severity() {
  local sev="$1"; [[ "$(severity_rank "$sev")" -le "$SEV_MIN_RANK" ]]
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

while IFS=$'\t' read -r RULE_ID SEV KIND REF LANGS; do
  [[ -z "$RULE_ID" ]] && continue
  [[ -n "$RULE_FILTER" && "$RULE_ID" != "$RULE_FILTER" ]] && continue
  passes_severity "$SEV" || continue
  case "$KIND" in
    lint)   run_eslint "$RULE_ID" "$SEV" "$REF" ;;
    ruff)   run_ruff   "$RULE_ID" "$SEV" "$REF" ;;
    mypy)   run_mypy   "$RULE_ID" "$SEV" "$REF" ;;
    tsc)    run_tsc    "$RULE_ID" "$SEV" "$REF" ;;
    script) run_script "$RULE_ID" "$SEV" "$REF" >> "$findings_file" ;;
    llm)    emit_llm_deferred "$RULE_ID" "$SEV" "$REF" ;;
    *)      emit_skipped "$RULE_ID" "unknown detector kind: $KIND" ;;
  esac
done < <(parse_rubric)

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

count_blocking() {
  awk -F'"' '/"severity":"P0"/ && !/"DEFERRED/ {n++} END{print n+0}' "$findings_file"
}

case "$OUTPUT" in
  json)
    printf '{"version":1,"mode":"%s","findings":[' "$MODE"
    awk 'NR>1{printf ","} {print}' "$findings_file" | tr -d '\n' | sed 's/}{/},{/g' || true
    printf ']}\n'
    ;;
  md)
    echo "# Rubric report"
    echo
    echo "Mode: \`$MODE\` · Severity threshold: \`$SEVERITY_MIN\`"
    echo
    if [[ -s "$findings_file" ]]; then
      echo "| rule | severity | file | line | msg |"
      echo "|---|---|---|---|---|"
      python3 - <<PY
import json
with open("$findings_file") as fh:
    for line in fh:
        try: d = json.loads(line)
        except: continue
        print(f'| {d["rule"]} | {d["severity"]} | {d["file"]} | {d["line"]} | {d["msg"]} |')
PY
    else
      echo "_No findings._"
    fi
    ;;
esac

if [[ "$QUIET" == "1" ]]; then
  blocking="$(count_blocking)"
  [[ "$blocking" -gt 0 ]] && exit 2
  exit 0
fi
