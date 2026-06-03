#!/usr/bin/env bash
# ci-validate-all — H-11 CI gate entry point. Invokes G-12 validate-all
# and exits non-zero to gate the release on any validation failure.
#
# Usage:
#   bash .github/workflows/ci-validate-all.sh --root <dir>
#
# Per §11 H-11: "Plugin self-test against itself in CI: .github/workflows/
# self-test.yml runs /analyze on plugin's own repo; failures gate releases.
# Includes G-12, G-13 validators."

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    *) echo "ci-validate-all: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$ROOT" ]] && { echo "ci-validate-all: --root <dir> required" >&2; exit 2; }

if bash "$PLUGIN_ROOT/generated-code-quality-standards/validate-all.sh" --root "$ROOT" --format text 2>&1; then
  echo "ci-validate-all: validation passed" >&2
  exit 0
else
  echo "ci-validate-all: validation failed; release gated" >&2
  exit 1
fi
