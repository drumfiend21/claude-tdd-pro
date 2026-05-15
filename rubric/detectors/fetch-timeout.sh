#!/usr/bin/env bash
# fetch-timeout.sh — N-3 substrate stub. Detects fetch / http.request
# / undici dispatch calls without an AbortController signal or timeout
# option; exits 1 on violation.
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
      echo "Usage: fetch-timeout.sh --json --paths <glob> [--dry-run]"
      echo "Detector flags: --json --paths --dry-run"
      exit 0
      ;;
    *) shift ;;
  esac
done

if [[ "$DRY" -eq 1 ]]; then
  echo "fetch-timeout: dry-run; would walk $PATHS" >&2
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
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  while IFS=':' read -r ln content; do
    [[ -z "$content" ]] && continue
    if echo "$content" | grep -qE 'signal:|AbortSignal\.timeout\('; then
      continue
    fi
    if [[ "$JSON" -eq 1 ]]; then
      echo '{"severity":"error","rule_id":"node/fetch-timeout","file":"'"$f"'","line":'"$ln"',"finding":"fetch-timeout: fetch without AbortController signal (no timeout)","suggested_fix":"pass signal: AbortSignal.timeout(default_timeout_ms)"}' >&2
    else
      echo "fetch-timeout: $f:$ln fetch missing signal" >&2
    fi
    EXIT=1
  done < <(grep -nE '\bfetch\(' "$f" 2>/dev/null)
done < <(find "$EXPAND_BASE" $FIND_DEPTH -type f -name "$EXPAND_PATTERN" 2>/dev/null)

exit "$EXIT"
