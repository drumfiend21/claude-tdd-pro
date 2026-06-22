#!/usr/bin/env bash
# rubric/composite-dispatch.sh — ADR-0008 Wave 2: the composite-engine dispatch loop.
#
# Given a file, it (1) resolves the file's 4-axis canonical vocabulary (vendor/.../resolve.sh),
# (2) routes each kind to its FOSS tool(s) (standards/kind-to-tool-routing.yaml), (3) runs each
# tool via rubric/runners/run-tool.sh (which normalizes to SARIF 2.1.0 and applies the §28.28
# hard-require / optional missing-tool policy), and (4) aggregates all tool SARIF through the
# §28.29 bus (rubric/sarif-aggregate.sh) into one verdict.
#
# Verdict (never a vacuous green): red if any tool found a violation OR a REQUIRED tool was
# absent (hard-fail); incomplete if no red but an OPTIONAL tool was absent (not_enforced); else
# green. Tools may be explicitly listed with --tools (override) or auto-resolved (default).
#
# CLI: --file <path> [--tools <csv>] [--required-tools <csv>] [--strict] [--json]
# stderr: `dispatch tool=<t> verdict=<green|red|not_enforced>` per tool; summary
#         `dispatch file=<f> status=<green|red|incomplete> tools=<n> red=<r> not_enforced=<u>`
# Exit: 0 green | 1 red | 3 incomplete | 2 usage.

set -uo pipefail
FILE=""; TOOLS=""; REQ=""; STRICT=0; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --file) FILE="${2-}"; shift 2 ;;
    --tools) TOOLS="${2-}"; shift 2 ;;
    --required-tools) REQ="${2-}"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    --json) JSON=1; shift ;;
    -h|--help) echo "Usage: composite-dispatch.sh --file <path> [--tools <csv>] [--required-tools <csv>] [--strict] [--json]" >&2; exit 0 ;;
    *) echo "composite-dispatch: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$FILE" ] && { echo "composite-dispatch: --file required" >&2; exit 2; }
[ -f "$FILE" ] || { echo "composite-dispatch: not a file: $FILE" >&2; exit 2; }

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
RESOLVE="$PLUGIN_ROOT/vendor/canonical-vocabulary/resolve.sh"
ROUTING="$PLUGIN_ROOT/standards/kind-to-tool-routing.yaml"
RUNNER="$PLUGIN_ROOT/rubric/runners/run-tool.sh"
AGG="$PLUGIN_ROOT/rubric/sarif-aggregate.sh"

# Determine the tool set: explicit --tools, or auto-resolve file -> 4-axis -> routed tools.
if [ -z "$TOOLS" ] && [ -x "$RESOLVE" ]; then
  RES="$(bash "$RESOLVE" --file "$FILE" --json 2>/dev/null)"
  TOOLS="$(FILE="$FILE" ROUTING="$ROUTING" RES="$RES" ruby -ryaml -rjson -e '
    res = JSON.parse(ENV["RES"]) rescue {}
    routing = YAML.unsafe_load_file(ENV["ROUTING"]) rescue {}
    tools = []
    { "linguist_aliases" => res["linguist_aliases"], "iac_dialects" => res["iac_dialects"] }.each do |axis, vals|
      Array(vals).each do |v|
        Array((routing[axis] || {})[v]).each { |t| tools << t["tool"] if t["tool"] }
      end
    end
    print tools.uniq.first(8).join(",")
  ' 2>/dev/null)"
fi
[ -z "$TOOLS" ] && { echo "composite-dispatch file=$FILE status=green tools=0 red=0 not_enforced=0 reason=no-applicable-tool" >&2; exit 0; }

# required-tool set (membership test)
is_required() { case ",$REQ," in *,"$1",*) return 0 ;; *) return 1 ;; esac; }

SARIF_DIR="$(mktemp -d)"
nred=0; nunenf=0; ntools=0
IFS=',' read -r -a _tlist <<<"$TOOLS"
for t in "${_tlist[@]}"; do
  [ -z "$t" ] && continue
  ntools=$((ntools + 1))
  ra=(); is_required "$t" && ra=(--required)
  bash "$RUNNER" --tool "$t" --file "$FILE" "${ra[@]}" --json > "$SARIF_DIR/$t.sarif" 2>/dev/null
  ec=$?
  case "$ec" in
    1) nred=$((nred + 1));   echo "dispatch tool=$t verdict=red" >&2 ;;
    0) echo "dispatch tool=$t verdict=green" >&2 ;;
    # exit 3 (optional absent) OR any other (e.g. an unadapted routed tool) -> not_enforced.
    # Never a vacuous green: a tool we routed to but could not run leaves the file incomplete.
    *) nunenf=$((nunenf + 1)); echo "dispatch tool=$t verdict=not_enforced" >&2 ;;
  esac
done

# Aggregate every tool's SARIF into one normalized stream (the bus also recomputes red).
AGG_ARGS=(--dir "$SARIF_DIR"); [ "$STRICT" -eq 1 ] && AGG_ARGS+=(--strict)
if [ "$JSON" -eq 1 ]; then bash "$AGG" "${AGG_ARGS[@]}" --json 2>/dev/null; fi
bash "$AGG" "${AGG_ARGS[@]}" >/dev/null 2>&1 || true
rm -rf "$SARIF_DIR"

if [ "$nred" -gt 0 ]; then status="red"; rc=1
elif [ "$nunenf" -gt 0 ]; then status="incomplete"; rc=3
else status="green"; rc=0; fi
echo "dispatch file=$FILE status=$status tools=$ntools red=$nred not_enforced=$nunenf" >&2
exit $rc
