#!/usr/bin/env bash
# P-10 eval-driven router promotion wrapper.
#
# Thin shell over lib/router-promote.js so the command surface
# matches the §6 P-10 convention (commands/<verb>.sh). Forwards
# all flags to the node module.
#
# Usage:
#   commands/router-promote.sh [--router <yaml>] [--datasets <dir>]
#                              [--out <yaml>] [--dry-run]

set -uo pipefail
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
exec node "$PLUGIN_ROOT/lib/router-promote.js" "$@"
