#!/usr/bin/env bash
# _dispatch.sh — R-6 substrate stub: maps a rule id to its
# canonical detector script (per §16 R-2 table) and forwards
# --paths and other args to it. Used by R-6 fixture specs to
# exercise positive/negative fixtures without spec-level coupling
# to specific detector filenames.
#
# Usage:
#   _dispatch.sh --rule <rule-id> --paths <glob> [other detector args]

set -uo pipefail

RULE=""
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --rule) RULE="$2"; shift 2 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

if [[ -z "$RULE" ]]; then
  echo "_dispatch: --rule required" >&2
  exit 2
fi

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"

case "$RULE" in
  g-react-001) DETECTOR="rsc-boundary.sh" ;;
  g-react-002) DETECTOR="exhaustive-deps.sh" ;;
  g-react-003) DETECTOR="a11y-axe.sh" ;;
  g-react-004) DETECTOR="rsc-boundary.sh" ;;
  g-react-005) DETECTOR="rsc-boundary.sh" ;;
  g-react-006) DETECTOR="rsc-boundary.sh" ;;
  g-react-007) DETECTOR="rsc-boundary.sh" ;;
  g-react-008) DETECTOR="bundle-budget.sh" ;;
  g-react-009) DETECTOR="rsc-boundary.sh" ;;
  g-react-010) DETECTOR="bundle-budget.sh" ;;
  *)
    echo "_dispatch: no detector mapping for rule $RULE" >&2
    exit 2
    ;;
esac

DETECTOR_PATH="$PLUGIN_ROOT/rubric/detectors/$DETECTOR"
if [[ ! -x "$DETECTOR_PATH" ]]; then
  echo "_dispatch: detector not executable: $DETECTOR_PATH" >&2
  exit 2
fi

exec bash "$DETECTOR_PATH" "${ARGS[@]}"
