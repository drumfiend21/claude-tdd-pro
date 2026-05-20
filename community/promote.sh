#!/usr/bin/env bash
# H-10 promote a community entry. Tier-1 requires ≥2 reviewers per REVIEW.md.
set -uo pipefail
ENTRY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --entry) ENTRY="$2"; shift 2 ;;
    -h|--help) echo "Usage: promote.sh --entry <yaml>"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$ENTRY" || ! -f "$ENTRY" ]] && { echo "community-promote: --entry <yaml> required" >&2; exit 2; }

TIER=$(grep -E '^proposed_tier:' "$ENTRY" | sed -E 's/proposed_tier:[[:space:]]*//' | tr -d ' "')
REVIEWERS_LINE=$(grep -E '^reviewers:' "$ENTRY" | sed -E 's/reviewers:[[:space:]]*//')
REVIEWERS=$(echo "$REVIEWERS_LINE" | tr -d '[]' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -c .)

case "$TIER" in
  1) REQ=2 ;;
  2) REQ=1 ;;
  *) REQ=0 ;;
esac

if [[ "$REVIEWERS" -lt "$REQ" ]]; then
  echo "community-promote: reviewers_required>=$REQ reviewers_count=$REVIEWERS tier=$TIER entry=$ENTRY (insufficient approvals for proposed tier)" >&2
  exit 1
fi

echo "community-promote: promoted=true tier=$TIER reviewers_count=$REVIEWERS entry=$ENTRY" >&2
