#!/usr/bin/env bash
# rubric/runners/run-bundle.sh — ADR-0008 Wave 3: the architectural-content bundle runner
# (whole-or-nothing). When a rule declares applies_to_prose:true the engine auto-attaches this
# bundle; it runs EVERY member of the bundle (the operator cannot pick/choose) against a Markdown
# file and aggregates their SARIF into one verdict. The bundle is the prose-enforcement floor:
# markdownlint + cspell + textlint + remark + vale + lychee + prose-judge.sh (semantic moat).
#
# Members are read from standards/kind-to-tool-routing.yaml (bundles.<name>). Each tool member is
# run via run-tool.sh (present -> run; absent -> §28.28 policy; unadapted -> not_enforced).
# prose-judge.sh is the per-rule semantic path (§28.26) and is not run generically here.
#
# Whole-or-nothing verdict (never vacuous green): red if ANY member found a violation; incomplete
# if no red but a member could not run (absent/unadapted -> not_enforced); green only if every
# member ran clean.
#
# CLI: --file <md> [--bundle <name>] [--required] [--strict] [--json]
# stderr: per member `bundle member=<t> verdict=<green|red|not_enforced>`; summary
#         `bundle name=<n> file=<f> status=<green|red|incomplete> members=<m> red=<r> not_enforced=<u>`
# Exit: 0 green | 1 red | 3 incomplete | 2 usage.

set -uo pipefail
FILE=""; BUNDLE="architectural-content"; REQUIRED=0; STRICT=0; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --file) FILE="${2-}"; shift 2 ;;
    --bundle) BUNDLE="${2-}"; shift 2 ;;
    --required) REQUIRED=1; shift ;;
    --strict) STRICT=1; shift ;;
    --json) JSON=1; shift ;;
    -h|--help) echo "Usage: run-bundle.sh --file <md> [--bundle <name>] [--required] [--strict] [--json]" >&2; exit 0 ;;
    *) echo "run-bundle: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$FILE" ] && { echo "run-bundle: --file required" >&2; exit 2; }
[ -f "$FILE" ] || { echo "run-bundle: not a file: $FILE" >&2; exit 2; }

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
ROUTING="$PLUGIN_ROOT/standards/kind-to-tool-routing.yaml"
RUNNER="$PLUGIN_ROOT/rubric/runners/run-tool.sh"
AGG="$PLUGIN_ROOT/rubric/sarif-aggregate.sh"

# Read the bundle members (tool names, excluding the in-repo prose-judge.sh per-rule path).
MEMBERS="$(BUNDLE="$BUNDLE" ROUTING="$ROUTING" ruby -ryaml -e '
  d=YAML.unsafe_load_file(ENV["ROUTING"]) rescue {}
  b=((d["bundles"]||{})[ENV["BUNDLE"]]||[])
  print b.map{|m| m["tool"]}.compact.reject{|t| t=="prose-judge.sh"}.join(",")
' 2>/dev/null)"
[ -z "$MEMBERS" ] && { echo "run-bundle name=$BUNDLE file=$FILE status=green members=0 red=0 not_enforced=0 reason=no-members" >&2; exit 0; }

SARIF_DIR="$(mktemp -d)"
nred=0; nunenf=0; nmem=0
IFS=',' read -r -a _m <<<"$MEMBERS"
for t in "${_m[@]}"; do
  [ -z "$t" ] && continue
  nmem=$((nmem+1))
  ra=(); [ "$REQUIRED" -eq 1 ] && ra=(--required)
  bash "$RUNNER" --tool "$t" --file "$FILE" "${ra[@]}" --json > "$SARIF_DIR/$t.sarif" 2>/dev/null
  ec=$?
  case "$ec" in
    1) nred=$((nred+1));   echo "bundle member=$t verdict=red" >&2 ;;
    0) echo "bundle member=$t verdict=green" >&2 ;;
    *) nunenf=$((nunenf+1)); echo "bundle member=$t verdict=not_enforced" >&2 ;;
  esac
done

AGG_ARGS=(--dir "$SARIF_DIR"); [ "$STRICT" -eq 1 ] && AGG_ARGS+=(--strict)
[ "$JSON" -eq 1 ] && bash "$AGG" "${AGG_ARGS[@]}" --json 2>/dev/null
rm -rf "$SARIF_DIR"

if [ "$nred" -gt 0 ]; then status="red"; rc=1
elif [ "$nunenf" -gt 0 ]; then status="incomplete"; rc=3
else status="green"; rc=0; fi
echo "bundle name=$BUNDLE file=$FILE status=$status members=$nmem red=$nred not_enforced=$nunenf" >&2
exit $rc
