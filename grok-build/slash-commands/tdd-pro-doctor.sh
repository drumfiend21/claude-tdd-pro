#!/usr/bin/env bash
# Grok Build slash command /tdd-pro-doctor — delegates to the underlying command.
set -uo pipefail
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
cmd_name="$(basename "$0" .sh | sed 's/^tdd-pro-//')"
if [[ -x "$PLUGIN_ROOT/commands/$cmd_name.sh" ]]; then
  exec bash "$PLUGIN_ROOT/commands/$cmd_name.sh" "$@"
else
  echo "tdd-pro: command not found: $cmd_name" >&2
  exit 2
fi
