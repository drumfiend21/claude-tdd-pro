#!/usr/bin/env bash
# console-in-src.sh — N-3 substrate stub. Detects console.{log,info,
# warn,error,debug} calls inside src/ paths; exits 1 on violation
# (callers should move to a structured logger per nodebestpractices §5.1).
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
      echo "Usage: console-in-src.sh --json --paths <glob> [--dry-run]"
      echo "Detector flags: --json --paths --dry-run"
      exit 0
      ;;
    *) shift ;;
  esac
done

if [[ "$DRY" -eq 1 ]]; then
  echo "console-in-src: dry-run; would walk $PATHS" >&2
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
    echo '{"severity":"warn","rule_id":"node/console-in-src","file":"'"$f"'","line":'"$ln"',"finding":"console call in src/ (use a structured logger; nodebestpractices 5.1)","suggested_fix":"replace console with pino/winston logger"}' >&2
  else
    echo "console-in-src: $f:$ln console call in src/" >&2
  fi
  EXIT=1
done < <(find "$EXPAND_BASE" $FIND_DEPTH -type f -name "$EXPAND_PATTERN" -print0 2>/dev/null \
  | xargs -0 grep -nE 'console\.(log|info|warn|error|debug)\(' 2>/dev/null)

exit "$EXIT"
