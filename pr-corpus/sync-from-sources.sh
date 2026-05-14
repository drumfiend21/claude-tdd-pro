#!/usr/bin/env bash
# pr-corpus/sync-from-sources.sh — L-18 sync mechanism. Initial substrate
# handles --calibrate-thresholds routing only (reads seed/pr-corpus-patterns/
# from O-1 seed corpus to bootstrap L-5 reconciler thresholds); subsequent
# CLs extend with the full L-18 sync flow (reads PR-SOURCES.yaml, invokes
# per-source fetcher, records sync timestamp, etc.).

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
CALIBRATE_THRESHOLDS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --calibrate-thresholds) CALIBRATE_THRESHOLDS=1; shift ;;
    *) echo "sync-from-sources: unknown flag: $1" >&2; exit 2 ;;
  esac
done

if [[ "$CALIBRATE_THRESHOLDS" -eq 1 ]]; then
  SEED_PATTERNS="$PLUGIN_ROOT/seed/pr-corpus-patterns/patterns.jsonl"
  if [[ ! -f "$SEED_PATTERNS" ]]; then
    echo "sync-from-sources: no seed patterns at $SEED_PATTERNS" >&2
    exit 1
  fi
  count=$(wc -l < "$SEED_PATTERNS" | tr -d ' ')
  echo "calibrate-thresholds: using seed corpus ($count patterns) for L-5 reconciler threshold tuning" >&2
  exit 0
fi

echo "sync-from-sources: only --calibrate-thresholds is implemented in initial substrate" >&2
exit 2
