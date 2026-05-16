#!/usr/bin/env bash
# L-15 cross-loop emission. Two modes:
# (1) --reference <json> --log <jsonl>: append a cross-loop reference event.
# (2) --profile <yaml> --target <name> --dry-run: opt-in / per-target gate check.
set -uo pipefail
REF=""; LOG=""; PROFILE=""; TARGET=""; DRY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --reference) REF="$2"; shift 2 ;;
    --log) LOG="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) echo "Usage: cross-loop/emit.sh [--reference <json> --log <jsonl>] | [--profile <yaml> --target <name> --dry-run]"; exit 0 ;;
    *) shift ;;
  esac
done

if [[ -n "$PROFILE" && -f "$PROFILE" ]]; then
  ENABLED=$(grep -E '^[[:space:]]*enabled:' "$PROFILE" | sed -E 's/.*enabled:[[:space:]]*//' | tr -d ' "')
  EMIT_TO=$(grep -E '^[[:space:]]*emit_to:' "$PROFILE" | sed -E 's/.*emit_to:[[:space:]]*//' | tr -d ' []"')
  if [[ "$ENABLED" == "false" ]]; then
    echo "cross-loop-emit: opt_in=false target=$TARGET no_emission (profile pr_corpus_cross_loop.enabled=false)" >&2
    exit 0
  fi
  if [[ -n "$EMIT_TO" && -n "$TARGET" ]]; then
    if [[ ",$EMIT_TO," != *",$TARGET,"* ]]; then
      echo "cross-loop-emit: target=$TARGET disabled=true (not in profile pr_corpus_cross_loop.emit_to=$EMIT_TO)" >&2
      exit 0
    fi
  fi
fi

if [[ -n "$REF" && -f "$REF" && -n "$LOG" ]]; then
  mkdir -p "$(dirname "$LOG")"
  cat "$REF" >> "$LOG"
  echo "cross-loop-emit: emitted ref=$REF log=$LOG" >&2
  exit 0
fi

[[ "$DRY" -eq 1 ]] && { echo "cross-loop-emit: dry_run=true (no emission)" >&2; exit 0; }
echo "cross-loop-emit: no operation performed (need --reference+--log or --profile+--target+--dry-run)" >&2
exit 0
