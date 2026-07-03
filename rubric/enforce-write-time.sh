#!/usr/bin/env bash
# rubric/enforce-write-time.sh — THE single write-time native enforcement of the ENTIRE repo ruleset.
#
# §29.6 byte-identical enforcement: development's write-time governor (hooks/scripts/
# enforce-standards-pre-write.sh) AND the architectural-design consult (commands/architect-session.sh)
# BOTH call THIS ONE script for native enforcement — so the native enforcement of all rules is
# byte-identical across consult and development by construction (one code path, no duplicated flag logic).
#
# Given one file, it runs rubric/enforce-file.sh with the canonical write-time flags:
#   --single-file-gate                 tree-context rules (coverage) are not decidable per-file -> skipped
#   --include-app-code (app-code kinds) the full-stack rule set is enforced natively (any language)
#
# CLI:  <file>
# Exit: 0 clean/advisory | 1 blocking (P0/P1 violation) | 3 not_enforced | 2 usage.
set -uo pipefail
FILE="${1:-}"
[ -z "$FILE" ] && { echo "enforce-write-time: <file> required" >&2; exit 2; }
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
EF="$PLUGIN_ROOT/rubric/enforce-file.sh"
[ -f "$EF" ] || exit 0

# The canonical write-time flag set (defined in ONE place so consult == development, byte-identical).
EA=(--file "$FILE" --single-file-gate)
case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.py|*.go|*.rb|*.rs|*.java|*.kt|*.php|*.cs|*.swift|*.scala|*.ex) EA+=(--include-app-code) ;;
esac
bash "$EF" "${EA[@]}"
