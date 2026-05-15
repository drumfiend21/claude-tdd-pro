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
PRINT_CANONICAL=0
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --rule) RULE="$2"; shift 2 ;;
    --print-canonical) PRINT_CANONICAL=1; shift ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

if [[ -z "$RULE" ]]; then
  echo "_dispatch: --rule required" >&2
  exit 2
fi

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"

if [[ "$PRINT_CANONICAL" -eq 1 ]]; then
  case "$RULE" in
    g-ts-006) echo "templates/tsconfig.strict.json" >&2 ;;
    g-react-007) echo "templates/vitest.react.config.ts" >&2 ;;
    g-react-008|g-react-010) echo "templates/size-limit.config.js" >&2 ;;
    *) echo "_dispatch: no canonical template for rule $RULE" >&2; exit 0 ;;
  esac
  exit 0
fi

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
  g-node-001)  DETECTOR="boundary-schema.sh" ;;
  g-node-002)  DETECTOR="naked-throw.sh" ;;
  g-node-003)  DETECTOR="fetch-timeout.sh" ;;
  g-node-004)  DETECTOR="console-in-src.sh" ;;
  g-node-005)  DETECTOR="naked-throw.sh" ;;
  g-node-006)  DETECTOR="naked-throw.sh" ;;
  g-node-007)  DETECTOR="naked-throw.sh" ;;
  g-node-008)  DETECTOR="boundary-schema.sh" ;;
  g-node-009)  DETECTOR="naked-throw.sh" ;;
  g-node-010)  DETECTOR="supply-chain.sh" ;;
  g-ts-001)    DETECTOR="no-any.sh" ;;
  g-ts-002)    DETECTOR="no-any.sh" ;;
  g-ts-003)    DETECTOR="exhaustive-unions.sh" ;;
  g-ts-004)    DETECTOR="type-test-coverage.sh" ;;
  g-ts-005)    DETECTOR="type-test-coverage.sh" ;;
  g-ts-006)    DETECTOR="type-test-coverage.sh" ;;
  g-ts-007)    DETECTOR="no-any.sh" ;;
  g-ts-008)    DETECTOR="type-test-coverage.sh" ;;
  *)
    echo "_dispatch: no detector mapping for rule $RULE" >&2
    exit 2
    ;;
esac

echo "_dispatch: $RULE -> $DETECTOR" >&2

DETECTOR_PATH="$PLUGIN_ROOT/rubric/detectors/$DETECTOR"
if [[ ! -x "$DETECTOR_PATH" ]]; then
  echo "_dispatch: detector not executable: $DETECTOR_PATH" >&2
  exit 2
fi

# Surface the canonical template path for rules that have one
# (T-4 g-ts-006 spec greps for "templates/tsconfig.strict.json" in
# the dispatcher stderr without --print-canonical).
case "$RULE" in
  g-ts-006)    echo "_dispatch: $RULE canonical-template templates/tsconfig.strict.json" >&2 ;;
  g-react-007) echo "_dispatch: $RULE canonical-template templates/vitest.react.config.ts" >&2 ;;
  g-react-008|g-react-010) echo "_dispatch: $RULE canonical-template templates/size-limit.config.js" >&2 ;;
esac

exec bash "$DETECTOR_PATH" "${ARGS[@]}"
