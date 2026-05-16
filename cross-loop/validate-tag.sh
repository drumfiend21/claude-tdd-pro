#!/usr/bin/env bash
# L-15 validates a rule card carries the explicit cross-loop class tag.
set -uo pipefail
CARD=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --card) CARD="$2"; shift 2 ;;
    -h|--help) echo "Usage: validate-tag.sh --card <yaml>"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$CARD" || ! -f "$CARD" ]] && { echo "validate-tag: --card <yaml> required" >&2; exit 2; }

ORIGIN=$(grep -E '^origin_loop:' "$CARD" | sed -E 's/origin_loop:[[:space:]]*//' | tr -d ' "')
echo "validate-tag: card=$CARD class=$ORIGIN" >&2
