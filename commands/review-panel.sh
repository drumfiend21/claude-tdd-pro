#!/usr/bin/env bash
# H-6 /review-panel — renamed from /review per builtin-command reconciliation.
# Per §16 H-6: Claude Code shipped a builtin /review; this plugin's
# review-orchestrator was renamed to /review-panel to avoid namespace
# collision. Legacy /review is a deprecation shim.
set -uo pipefail
case "${1:-}" in
  -h|--help)
    {
      echo "Usage: review-panel.sh [args]"
      echo ""
      echo "Status: renamed from /review per H-6 builtin-command reconciliation."
      echo "Originally /review; renamed to /review-panel to avoid collision with"
      echo "the Claude Code builtin /review command."
    } >&2
    exit 0
    ;;
esac
echo "review-panel: invoked (renamed from /review per H-6)" >&2
