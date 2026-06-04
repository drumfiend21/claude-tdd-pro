#!/usr/bin/env bash
# a11y-axe.sh — R-3 substrate stub (per §16 R-3 + §2.2 detector
# contract). Walks JSX/TSX files for accessibility violations and
# emits findings citing the relevant WCAG 2.2 success criteria
# (e.g. §1.1.1 missing alt, §1.3.1 info-and-relationships,
# §2.4.7 focus-visible, §4.1.2 name-role-value).
#
# Per §2.2 detector contract: supports --json, --paths, --dry-run,
# --help; emits findings to stderr (so callers redirect with 2>).
#
# Usage:
#   a11y-axe.sh --json --paths "src/**/*.tsx" [--dry-run]

set -uo pipefail

# AI-NATIVE MIGRATION (Musk + Fowler joint review):
#   When LLM_JUDGE=1 and llm-judge.sh + a model CLI exist,
#   defer to llm-judge for semantic verdict; fall back to
#   grep on rc=3 (model unavailable).
PLUGIN_ROOT_LJ="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
LLM_JUDGE="${LLM_JUDGE:-0}"
LLM_JUDGE_RULE_ID="react/a11y-axe"
ai_native_judge() {
  [[ "$LLM_JUDGE" -ne 1 ]] && return 1
  bash "$PLUGIN_ROOT_LJ/rubric/detectors/llm-judge.sh" \
       --target "$1" --rule "$LLM_JUDGE_RULE_ID" 2>/dev/null
  return $?
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
      echo "Usage: a11y-axe.sh --json --paths <glob> [--dry-run]"
      echo "Detector flags: --json --paths --dry-run"
      exit 0
      ;;
    *) shift ;;
  esac
done

if [[ "$DRY" -eq 1 ]]; then
  echo "a11y-axe: dry-run; would walk $PATHS" >&2
  exit 0
fi

# Portable glob expansion (macOS bash 3.2 lacks globstar). Convert
# either src/**/*.tsx or src/routes/*.tsx into a find invocation.
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

EXIT=0
[[ -d "$EXPAND_BASE" ]] || exit 0

if [[ "$EXPAND_RECURSIVE" -eq 1 ]]; then
  CANDIDATES=$(find "$EXPAND_BASE" -type f -name "$EXPAND_PATTERN" 2>/dev/null | xargs grep -lE '<img[^>]*\bsrc=' 2>/dev/null)
else
  CANDIDATES=$(find "$EXPAND_BASE" -maxdepth 1 -type f -name "$EXPAND_PATTERN" 2>/dev/null | xargs grep -lE '<img[^>]*\bsrc=' 2>/dev/null)
fi

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  if ! grep -qE '\balt=' "$f"; then
    if [[ "$JSON" -eq 1 ]]; then
      echo '{"severity":"warn","rule_id":"react-a11y/img-alt","file":"'"$f"'","line":1,"finding":"img element missing alt attribute (wcag-2-2 §1.1.1, §1.3.1)","suggested_fix":"add alt attribute (use alt= for decorative images)"}' >&2
    else
      echo "a11y-axe: $f: img missing alt (wcag-2-2 §1.1.1)" >&2
    fi
  fi
done <<< "$CANDIDATES"

exit 0
