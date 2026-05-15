#!/usr/bin/env bash
# /help — H-9 progressive disclosure helper.
set -uo pipefail
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
TOPIC="${1:-getting-started}"
KNOWN=(getting-started first-week reference source-folders threat-model eslint-migration-cheatsheet)
for k in "${KNOWN[@]}"; do
  if [[ "$TOPIC" == "$k" ]]; then
    cat "$PLUGIN_ROOT/docs/${TOPIC}.md" >&2
    exit 0
  fi
done
echo "help: unknown topic \"$TOPIC\". Known topics: ${KNOWN[*]}" >&2
exit 0
