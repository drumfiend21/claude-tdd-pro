#!/usr/bin/env bash
# H-6 /plan-first — kept-as-is per builtin-command reconciliation.
# Per §16 H-6: this command predates Claude Code's builtin slash-command
# set and was kept under its existing name (no rename) because operators
# already script around it. Marker: "kept" in --help text.
set -uo pipefail
case "${1:-}" in
  -h|--help)
    {
      echo "Usage: plan-first.sh [args]"
      echo ""
      echo "Status: kept-as-is per H-6 builtin-command reconciliation."
      echo "Predates Claude Code builtin /plan; not renamed because external"
      echo "scripts already invoke this command by its current name."
    } >&2
    exit 0
    ;;
esac
echo "plan-first: invoked (kept-as-is per H-6)" >&2
