#!/usr/bin/env bash
# L-19 first-use-of-day refresh trigger. Compares last_fetch date with
# now date; different date = trigger automatic refresh.
set -uo pipefail
SOURCE=""; NOW=""; STUB=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    --upstream-stub) STUB="$2"; shift 2 ;;
    -h|--help) echo "Usage: first-use-check.sh --source <id> --now <iso> [--upstream-stub <jsonl>]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$SOURCE" || -z "$NOW" ]] && { echo "first-use-check: --source and --now required" >&2; exit 2; }

LAST_FILE=".claude-tdd-pro/pr-corpus/last-fetch/$SOURCE.txt"
LAST=""
[[ -f "$LAST_FILE" ]] && LAST=$(tr -d '\n' < "$LAST_FILE")

NOW_DATE="${NOW%T*}"
LAST_DATE="${LAST%T*}"
if [[ "$LAST_DATE" != "$NOW_DATE" ]]; then
  echo "first-use-check: source=$SOURCE auto_refresh=triggered last_date=$LAST_DATE now_date=$NOW_DATE" >&2
else
  echo "first-use-check: source=$SOURCE auto_refresh=skipped (already fetched today)" >&2
fi
