#!/usr/bin/env bash
# X-7 installable hooks bundle per §14. Installs the plugin's Stop /
# PreToolUse / PostToolUse / SessionStart hooks into the operator's
# Claude Code settings file so the rubric runs at the same lifecycle
# points as the plugin's own session.
#
# Per §14 X-7: hooks-first packaging — TDD Pro installs as a Claude Code
# artifact rather than a sidecar.
#
# Usage:
#   commands/install-hooks.sh --settings-path <path> [--dry-run]
#                             [--emit-audit <jsonl>]
#
# Exit codes:
#   0 — installed (or dry-run plan emitted)
#   2 — usage error

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"

SETTINGS=""
DRY_RUN=0
EMIT_AUDIT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --settings-path) SETTINGS="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --emit-audit) EMIT_AUDIT="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: install-hooks.sh --settings-path <path> [--dry-run] [--emit-audit <jsonl>]"
      exit 0 ;;
    *) echo "install-hooks: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$SETTINGS" ]] && { echo "install-hooks: --settings-path <path> required" >&2; exit 2; }

# Build the hooks-block additions. Each hook points at the plugin's
# scripts/ directory under PLUGIN_ROOT so updates flow through without
# operator action.
HOOKS_BLOCK=$(cat <<EOF
{
  "Stop": "bash \$CLAUDE_PLUGIN_ROOT/hooks/scripts/stop-hook.sh",
  "PreToolUse": "bash \$CLAUDE_PLUGIN_ROOT/hooks/scripts/pre-tool-use.sh",
  "PostToolUse": "bash \$CLAUDE_PLUGIN_ROOT/hooks/scripts/post-tool-use.sh",
  "SessionStart": "bash \$CLAUDE_PLUGIN_ROOT/hooks/scripts/session-start.sh"
}
EOF
)

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "install-hooks: dry-run; would merge hooks block into $SETTINGS" >&2
  echo "$HOOKS_BLOCK" >&2
  exit 0
fi

mkdir -p "$(dirname "$SETTINGS")"
# If the settings file doesn't exist, create with the hooks block alone.
if [[ ! -f "$SETTINGS" ]]; then
  printf '{\n  "hooks": %s\n}\n' "$HOOKS_BLOCK" > "$SETTINGS"
else
  # Merge: preserve any operator keys; replace/add the `hooks` block.
  HOOKS_BLOCK="$HOOKS_BLOCK" SETTINGS="$SETTINGS" node -e '
    const fs = require("fs");
    const path = process.env.SETTINGS;
    const block = JSON.parse(process.env.HOOKS_BLOCK);
    let cur = {};
    try { cur = JSON.parse(fs.readFileSync(path, "utf8")); } catch {}
    cur.hooks = Object.assign(cur.hooks || {}, block);
    fs.writeFileSync(path, JSON.stringify(cur, null, 2) + "\n");
  '
fi
echo "install-hooks: installed 4 hooks into $SETTINGS" >&2

if [[ -n "$EMIT_AUDIT" ]]; then
  mkdir -p "$(dirname "$EMIT_AUDIT")"
  printf '{"action":"hooks-installed","settings":"%s","hooks":["Stop","PreToolUse","PostToolUse","SessionStart"],"ts":"%s"}\n' \
    "$SETTINGS" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$EMIT_AUDIT"
fi
exit 0
