#!/usr/bin/env bash
# naked-throw.sh — N-3 substrate stub. Detects throw of plain Error
# (instead of typed subclass with stable kind/code) and throw of
# string literals.  Exits 1 on violation.
#
# Per §2.2 detector contract: --json, --paths, --dry-run, --help.

set -uo pipefail

# AI-NATIVE MIGRATION (Musk + Fowler joint review):
#   When LLM_JUDGE=1 in the environment and llm-judge.sh +
#   a model CLI (claude/grok) are available, this detector
#   defers to llm-judge for the semantic verdict and falls
#   back to grep when the model is unavailable (rc=3) or
#   indeterminate. Toggle via:
#     LLM_JUDGE=1 bash rubric/detectors/<this>.sh ...
PLUGIN_ROOT_LJ="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
LLM_JUDGE="${LLM_JUDGE:-0}"
LLM_JUDGE_RULE_ID="ts/naked-throw"
ai_native_judge() {
  local target="$1"
  [[ "$LLM_JUDGE" -ne 1 ]] && return 1
  bash "$PLUGIN_ROOT_LJ/rubric/detectors/llm-judge.sh" \
       --target "$target" --rule "$LLM_JUDGE_RULE_ID" 2>/dev/null
  return $?  # 0=satisfies, 1=violates, 3=unavailable
}

JSON=0
PATHS=""
DRY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --paths) PATHS="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help)
      echo "Usage: naked-throw.sh --json --paths <glob> [--dry-run]"
      echo "Detector flags: --json --paths --dry-run"
      exit 0
      ;;
    *) shift ;;
  esac
done

if [[ "$DRY" -eq 1 ]]; then
  echo "naked-throw: dry-run; would walk $PATHS" >&2
  exit 0
fi

EXPAND_BASE=""
EXPAND_PATTERN=""
EXPAND_RECURSIVE=0
case "$PATHS" in
  *"/**"*)
    EXPAND_BASE="${PATHS%%/\*\*/*}"
    [[ "$EXPAND_BASE" == "$PATHS" ]] && EXPAND_BASE="${PATHS%/\*\*}"
    EXPAND_PATTERN="${PATHS##*/}"
    [[ "$EXPAND_PATTERN" == "**" ]] && EXPAND_PATTERN="*"
    EXPAND_RECURSIVE=1
    ;;
  */*)
    EXPAND_BASE="${PATHS%/*}"
    EXPAND_PATTERN="${PATHS##*/}"
    ;;
  *)
    EXPAND_BASE="."
    EXPAND_PATTERN="$PATHS"
    ;;
esac

[[ -d "$EXPAND_BASE" ]] || exit 0
if [[ "$EXPAND_RECURSIVE" -eq 1 ]]; then
  FIND_DEPTH=""
else
  FIND_DEPTH="-maxdepth 1"
fi

EXIT=0
while IFS=: read -r f ln content; do
  [[ -z "$f" ]] && continue
  if [[ "$JSON" -eq 1 ]]; then
    echo '{"severity":"warn","rule_id":"node/typed-error-taxonomy","file":"'"$f"'","line":'"$ln"',"finding":"naked-throw: throw of plain Error (introduce a named Error subclass with stable code)","suggested_fix":"throw new MySpecificError(\"...\") with kind/code"}' >&2
  else
    echo "naked-throw: $f:$ln throw of plain Error" >&2
  fi
  EXIT=1
done < <(find "$EXPAND_BASE" $FIND_DEPTH -type f -name "$EXPAND_PATTERN" -print0 2>/dev/null \
  | xargs -0 grep -nE 'throw[[:space:]]+new[[:space:]]+Error\(' 2>/dev/null)

exit "$EXIT"
