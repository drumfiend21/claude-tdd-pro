#!/usr/bin/env bash
# /postmortem — F-1 entry point. Initial substrate handles --show-historical
# routing only (reads seed/postmortems/ from O-1 seed corpus); subsequent CLs
# extend with the full F-1 flow (reproduce-bug → ask-what-should-have-caught
# → generate-eval-spec → optionally-draft-rule + detector → query SIRL/
# Compliance/L → append to FAILURE-LOG.md).

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
SHOW_HISTORICAL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --show-historical) SHOW_HISTORICAL=1; shift ;;
    *) echo "postmortem: unknown flag: $1" >&2; exit 2 ;;
  esac
done

if [[ "$SHOW_HISTORICAL" -eq 1 ]]; then
  POSTMORTEMS_DIR="$PLUGIN_ROOT/seed/postmortems"
  if [[ ! -d "$POSTMORTEMS_DIR" ]]; then
    echo "postmortem: no historical postmortems directory at $POSTMORTEMS_DIR" >&2
    exit 1
  fi
  count=$(find "$POSTMORTEMS_DIR" -name '*.jsonl' -type f | wc -l | tr -d ' ')
  echo "$count historical postmortems available" >&2
  exit 0
fi

echo "postmortem: only --show-historical is implemented in initial substrate" >&2
exit 2
