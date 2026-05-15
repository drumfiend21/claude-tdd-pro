#!/usr/bin/env bash
# type-test-coverage.sh — T-3 substrate stub. Detects exported
# functions / types that lack a compile-time type test (test-d.ts
# file or expectTypeOf assertion).
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
      echo "Usage: type-test-coverage.sh --json --paths <glob> [--dry-run]"
      echo "Detector flags: --json --paths --dry-run"
      exit 0
      ;;
    *) shift ;;
  esac
done

if [[ "$DRY" -eq 1 ]]; then
  echo "type-test-coverage: dry-run; would walk $PATHS" >&2
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
EXPORT_FILES=$(find "$EXPAND_BASE" $FIND_DEPTH -type f -name "$EXPAND_PATTERN" -print0 2>/dev/null \
  | xargs -0 grep -lE '^export[[:space:]]+(function|class|type|interface|const|async)' 2>/dev/null)

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  base="${f%.*}"
  ext="${f##*.}"
  test_d="${base}.test-d.${ext}"
  if [[ ! -f "$test_d" ]] && ! grep -qE 'expectTypeOf' "$f" 2>/dev/null; then
    LINE=$(grep -nE '^export[[:space:]]+(function|class|type|interface|const|async)' "$f" | head -1 | cut -d: -f1)
    [[ -z "$LINE" ]] && LINE=1
    if [[ "$JSON" -eq 1 ]]; then
      echo '{"severity":"warn","rule_id":"types/type-test-coverage","file":"'"$f"'","line":'"$LINE"',"finding":"type-test-coverage: exported symbol lacks a test-d type-test or expectTypeOf assertion (google-tsguide §testing)","suggested_fix":"add a sibling '"$base"'.test-d.'"$ext"' with expectTypeOf assertions"}' >&2
    else
      echo "type-test-coverage: $f:$LINE exported symbol lacks test-d coverage" >&2
    fi
    EXIT=1
  fi
done <<< "$EXPORT_FILES"

exit "$EXIT"
