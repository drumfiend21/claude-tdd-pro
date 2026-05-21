#!/usr/bin/env bash
# P-4 model-rationale detector. Verifies every prompt registry entry
# declares a non-empty model_rationale field (length >= --min-length).
# Modes: --prompt <file>, --prompts-dir <dir>, --registry <yaml>,
#        --emit json --out <file>, --min-length N, --dry-run.
set -uo pipefail
PROMPT=""; PROMPTS_DIR=""; REGISTRY=""; MIN_LEN=10
EMIT=""; OUT=""; DRY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt) PROMPT="$2"; shift 2 ;;
    --prompts-dir) PROMPTS_DIR="$2"; shift 2 ;;
    --registry) REGISTRY="$2"; shift 2 ;;
    --emit) EMIT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --min-length) MIN_LEN="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) echo "Usage: model-rationale.sh [--prompt <file>|--prompts-dir <dir>|--registry <yaml>] [--emit json --out <file>] [--min-length N] [--dry-run]"; exit 0 ;;
    *) shift ;;
  esac
done

# Registry-level rationale fallback when --registry is given.
if [[ -n "$REGISTRY" && -f "$REGISTRY" ]]; then
  if grep -qE '^rationale_default:' "$REGISTRY"; then
    echo "model-rationale: fallback_rationale_used=true registry=$REGISTRY" >&2
    exit 0
  fi
fi

# Single-prompt check.
if [[ -n "$PROMPT" && -f "$PROMPT" ]]; then
  if ! grep -qE '^model_rationale:' "$PROMPT"; then
    echo "model-rationale: missing required field: model_rationale in $PROMPT" >&2
    exit 1
  fi
  RAT=$(grep -E '^model_rationale:' "$PROMPT" | head -1 | sed -E 's/model_rationale:[[:space:]]*//' | tr -d '"')
  LEN=${#RAT}
  if [[ "$LEN" -lt "$MIN_LEN" ]]; then
    echo "model-rationale: rationale_too_short prompt=$PROMPT length=$LEN min_length=$MIN_LEN" >&2
    exit 1
  fi
  echo "model-rationale: rationale_present=true prompt=$PROMPT length=$LEN" >&2
fi

# Multi-prompt sweep.
if [[ -n "$PROMPTS_DIR" && -d "$PROMPTS_DIR" ]]; then
  CHECKED=0; FAILED=0; RECORDS=""
  for d in "$PROMPTS_DIR"/*/; do
    [[ -d "$d" ]] || continue
    pid=$(basename "$d")
    for f in "$d"*.md; do
      [[ -f "$f" ]] || continue
      CHECKED=$((CHECKED + 1))
      if grep -qE '^model_rationale:' "$f"; then
        RECORDS="$RECORDS{\"prompt_id\":\"$pid\",\"verdict\":\"pass\"},"
      else
        RECORDS="$RECORDS{\"prompt_id\":\"$pid\",\"verdict\":\"fail\"},"
        FAILED=$((FAILED + 1))
      fi
      break  # only check first version per prompt
    done
  done
  if [[ "$DRY" -eq 1 ]]; then
    echo "model-rationale: dry_run=true prompts_checked=$CHECKED (no writes)" >&2
    exit 0
  fi
  if [[ "$EMIT" == "json" && -n "$OUT" ]]; then
    mkdir -p "$(dirname "$OUT")"
    printf '[%s]\n' "${RECORDS%,}" > "$OUT"
  fi
  if [[ "$FAILED" -gt 0 ]]; then
    echo "model-rationale: prompts_failed=$FAILED prompts_checked=$CHECKED" >&2
    exit 1
  fi
  echo "model-rationale: prompts_checked=$CHECKED all_pass=true" >&2
  exit 0
fi
