#!/usr/bin/env bash
# exhaustive-unions.sh — T-3 substrate stub. Detects switch over a
# discriminated union that lacks a default branch with assertNever
# (or equivalent never-typed exhaustiveness check).
#
# Per §2.2 detector contract: --json, --paths, --dry-run, --help.

set -uo pipefail

JSON=0
PATHS=""
DRY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --paths) PATHS="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help)
      echo "Usage: exhaustive-unions.sh --json --paths <glob> [--dry-run]"
      echo "Detector flags: --json --paths --dry-run"
      exit 0
      ;;
    *) shift ;;
  esac
done

if [[ "$DRY" -eq 1 ]]; then
  echo "exhaustive-unions: dry-run; would walk $PATHS" >&2
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
SWITCH_FILES=$(find "$EXPAND_BASE" $FIND_DEPTH -type f -name "$EXPAND_PATTERN" -print0 2>/dev/null \
  | xargs -0 grep -lE 'switch[[:space:]]*\(' 2>/dev/null)

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  if ! grep -qE 'assertNever|: never\b' "$f" 2>/dev/null; then
    LINE=$(grep -nE 'switch[[:space:]]*\(' "$f" 2>/dev/null | head -1 | cut -d: -f1)
    [[ -z "$LINE" ]] && LINE=1
    if [[ "$JSON" -eq 1 ]]; then
      echo '{"severity":"error","rule_id":"types/exhaustive-unions","file":"'"$f"'","line":'"$LINE"',"finding":"exhaustive-unions: switch over discriminated union without assertNever default (typescript-handbook 2/narrowing#exhaustiveness)","suggested_fix":"add default: { const _exh: never = t; throw new Error(_exh); }"}' >&2
    else
      echo "exhaustive-unions: $f:$LINE switch missing assertNever" >&2
    fi
    EXIT=1
  fi
done <<< "$SWITCH_FILES"

exit "$EXIT"
