#!/usr/bin/env bash
# Grok Build on-save hook — thin delegator to the platform-independent runner.
set -uo pipefail
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
exec bash "$PLUGIN_ROOT/evals/runner.sh" "$@"
