#!/usr/bin/env bash
# O-5 / C-4 checkpoint directory listing in chronological order
# (filename `checkpoint-<N>.json` encodes the included-event count which
# is monotonic across invocations).
set -uo pipefail

CHECKPOINT_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --checkpoint-dir) CHECKPOINT_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: checkpoint-list.sh --checkpoint-dir <dir>" >&2
      exit 0
      ;;
    *) shift ;;
  esac
done

[[ -z "$CHECKPOINT_DIR" || ! -d "$CHECKPOINT_DIR" ]] && { echo "list: --checkpoint-dir <dir> required" >&2; exit 2; }

for f in "$CHECKPOINT_DIR"/checkpoint-*.json; do
  [[ -f "$f" ]] && echo "checkpoint=$(basename "$f")"
done | sort -t- -k2 -n >&2
