#!/usr/bin/env bash
# rubric/detectors/run-detector.sh — generic detector dispatcher per §2.2.
# Honors the standard detector flag surface (line 119 of architecture
# §2.2): --json, --paths <glob>, --dry-run, --rule-state-override,
# --options <json>, --fix, --fix-dry-run, --format <fmt>, --cache-key.
#
# Per §16 E-2 final clause:
#   "detectors receive --options <json>"
#
# This dispatcher demonstrates the §2.2 contract by accepting the
# standard flag set and (with --trace-args) echoing the propagated
# flags so callers can verify wiring. Real per-rule detectors live at
# rubric/detectors/<rule-name>.sh and follow the same contract.
#
# Usage:
#   bash run-detector.sh --rule <id> --in <file> --options <json> [--trace-args]

set -uo pipefail

RULE=""
IN=""
OPTIONS=""
TRACE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rule) RULE="$2"; shift 2 ;;
    --in) IN="$2"; shift 2 ;;
    --options) OPTIONS="$2"; shift 2 ;;
    --trace-args) TRACE=1; shift ;;
    --json|--dry-run|--fix|--fix-dry-run) shift ;;
    --paths|--rule-state-override|--format|--cache-key) shift 2 ;;
    *) echo "run-detector: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$RULE" ]] && { echo "run-detector: --rule <id> required" >&2; exit 2; }
[[ -z "$IN" ]] && { echo "run-detector: --in <file> required" >&2; exit 2; }

if [[ "$TRACE" -eq 1 ]]; then
  # Emit reconstructed args so callers can verify the contract surface.
  echo "run-detector: --rule $RULE --in $IN --options $OPTIONS" >&2
  exit 0
fi

# Without --trace-args: stub success (real detectors dispatch by rule id).
exit 0
