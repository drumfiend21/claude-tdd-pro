#!/usr/bin/env bash
# rubric/append-failure-log.sh — F-1 substrate. Appends a dated entry to
# the project's FAILURE-LOG.md. Honors §2.14 dry-run contract.
#
# CLI:
#   --file <path>     FAILURE-LOG path (required)
#   --date <iso>      YYYY-MM-DD prefix for the entry (required)
#   --summary <text>  one-line summary (required)
#   --dry-run         no writes; print what would be appended

FILE=""
DATE=""
SUMMARY=""
DRY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --file)    FILE="${2-}";    shift 2 ;;
    --date)    DATE="${2-}";    shift 2 ;;
    --summary) SUMMARY="${2-}"; shift 2 ;;
    --dry-run) DRY=1;           shift ;;
    -h|--help) echo "Usage: append-failure-log.sh --file <path> --date <iso> --summary <text> [--dry-run]" >&2; exit 0 ;;
    *) echo "append-failure-log: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$FILE" ] || [ -z "$DATE" ] || [ -z "$SUMMARY" ]; then
  echo "append-failure-log: --file, --date, --summary required" >&2
  exit 2
fi

if [ "$DRY" -eq 1 ]; then
  echo "append-failure-log: dry-run; would append \"## $DATE — $SUMMARY\" to $FILE" >&2
  exit 0
fi

printf '## %s — %s\n\n' "$DATE" "$SUMMARY" >> "$FILE"
echo "append-failure-log: appended date=$DATE to $FILE" >&2
