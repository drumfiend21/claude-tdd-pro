#!/usr/bin/env bash
# H-10 validate a community contribution entry has the required fields.
set -uo pipefail
ENTRY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --entry) ENTRY="$2"; shift 2 ;;
    -h|--help) echo "Usage: validate.sh --entry <yaml>"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$ENTRY" || ! -f "$ENTRY" ]] && { echo "community-validate: --entry <yaml> required" >&2; exit 2; }

REQUIRED=(contributor license review_status eval_evidence)
MISSING=()
for f in "${REQUIRED[@]}"; do
  if ! grep -qE "^${f}:" "$ENTRY"; then
    MISSING+=("$f")
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  for f in "${MISSING[@]}"; do
    echo "community-validate: missing required field: $f in $ENTRY" >&2
  done
  exit 1
fi

echo "community-validate: valid=true entry=$ENTRY" >&2
