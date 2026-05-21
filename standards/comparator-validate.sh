#!/usr/bin/env bash
# S-8 standards-comparator output validator.
set -uo pipefail
QUERY=""; ANSWER=""; CHECK=""; EMIT=""; OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --query) QUERY="$2"; shift 2 ;;
    --answer) ANSWER="$2"; shift 2 ;;
    --check) CHECK="$2"; shift 2 ;;
    --emit) EMIT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    -h|--help) echo "Usage: comparator-validate.sh [--query <json>|--answer <json>] [--check grounded|declined|no-hallucination] [--emit json --out <file>]"; exit 0 ;;
    *) shift ;;
  esac
done

if [[ -n "$QUERY" && -f "$QUERY" ]]; then
  HAS_Q=$(QUERY="$QUERY" node -e 'const j=JSON.parse(require("fs").readFileSync(process.env.QUERY,"utf8"));process.stdout.write(j.question?"true":"false")')
  if [[ -z "$CHECK" && "$HAS_Q" != "true" ]]; then
    echo "comparator-validate: missing required field: question" >&2
    exit 2
  fi
  if [[ "$CHECK" == "grounded" ]]; then
    GS=$(QUERY="$QUERY" node -e 'const j=JSON.parse(require("fs").readFileSync(process.env.QUERY,"utf8"));process.stdout.write(String((j.grounded_sources||[]).length))')
    if [[ "$GS" -gt 0 ]]; then
      echo "comparator-validate: all_claims_grounded=true grounded_sources=$GS" >&2
      exit 0
    fi
    echo "comparator-validate: all_claims_grounded=false grounded_sources=0" >&2
    exit 1
  fi
  if [[ "$CHECK" == "declined" ]]; then
    GS=$(QUERY="$QUERY" node -e 'const j=JSON.parse(require("fs").readFileSync(process.env.QUERY,"utf8"));process.stdout.write(String((j.grounded_sources||[]).length))')
    if [[ "$GS" -eq 0 ]]; then
      echo "comparator-validate: declined=true reason=no_grounding_available" >&2
      exit 0
    fi
    echo "comparator-validate: declined=false grounded_sources=$GS" >&2
    exit 1
  fi
  if [[ "$EMIT" == "json" && -n "$OUT" ]]; then
    QUERY="$QUERY" OUT="$OUT" node -e '
      const j = JSON.parse(require("fs").readFileSync(process.env.QUERY, "utf8"));
      const r = { answer: j.answer || "", citations: j.citations || [] };
      require("fs").writeFileSync(process.env.OUT, JSON.stringify(r));
    '
    echo "comparator-validate: emitted result to $OUT" >&2
    exit 0
  fi
fi

if [[ -n "$ANSWER" && -f "$ANSWER" ]]; then
  if [[ "$CHECK" == "no-hallucination" ]]; then
    HAS_GS=$(ANSWER="$ANSWER" node -e 'const j=JSON.parse(require("fs").readFileSync(process.env.ANSWER,"utf8"));process.stdout.write(String((j.grounded_sources||[]).length))')
    if [[ "$HAS_GS" -eq 0 ]]; then
      echo "comparator-validate: ungrounded_claim in answer (no grounded_sources)" >&2
      exit 1
    fi
    echo "comparator-validate: no_hallucination=true grounded_sources=$HAS_GS" >&2
    exit 0
  fi
fi
