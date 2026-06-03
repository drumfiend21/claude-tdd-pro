#!/usr/bin/env bash
# L-5 subagent classification label validator.
# Architecture §12 L-5: subagent classifies into the 5-label vocabulary
# (same | refinement | adjacent | novel | conflict). This script
# enforces that vocabulary on subagent output before downstream routing.
set -uo pipefail

CLASSIFICATION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --classification) CLASSIFICATION="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: validate-classification.sh --classification <json>" >&2
      exit 0
      ;;
    *) shift ;;
  esac
done

[[ -z "$CLASSIFICATION" || ! -f "$CLASSIFICATION" ]] && { echo "validate-classification: --classification <json> required" >&2; exit 2; }

LABEL=$(CLASSIFICATION="$CLASSIFICATION" node -e 'const j=JSON.parse(require("fs").readFileSync(process.env.CLASSIFICATION,"utf8"));process.stdout.write(String(j.classification||""))')

case "$LABEL" in
  same|refinement|adjacent|novel|conflict)
    echo "validate-classification: label_valid=true label=$LABEL" >&2
    exit 0
    ;;
  *)
    echo "validate-classification: unknown_label=$LABEL allowed=same|refinement|adjacent|novel|conflict" >&2
    exit 2
    ;;
esac
