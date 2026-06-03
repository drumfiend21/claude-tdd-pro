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

# Per §23 X-7: --scope user|project + --include <component>... +
# --dry-run + --force. Legacy --settings-path / --emit-audit kept as
# test-affordance aliases during reconciliation.
SCOPE="project"
INCLUDE=""
SETTINGS=""
DRY_RUN=0
FORCE=0
EMIT_AUDIT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope) SCOPE="$2"; shift 2 ;;
    --include) INCLUDE="${INCLUDE:+$INCLUDE,}$2"; shift 2 ;;
    --settings-path) SETTINGS="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --force) FORCE=1; shift ;;
    --emit-audit) EMIT_AUDIT="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: install-hooks.sh [--scope user|project] [--include <component>...] [--dry-run] [--force]" >&2
      echo "  scopes: user -> ~/.claude/settings.json" >&2
      echo "          project -> .claude/settings.json" >&2
      echo "  components: hooks | commands | agents | detectors" >&2
      echo "  (legacy: --settings-path <path>)" >&2
      exit 0 ;;
    *) echo "install-hooks: unknown flag: $1" >&2; exit 2 ;;
  esac
done

case "$SCOPE" in
  user|project) : ;;
  *) echo "install-hooks: --scope must be user|project (got $SCOPE)" >&2; exit 2 ;;
esac

# If --settings-path not given, resolve from --scope.
if [[ -z "$SETTINGS" ]]; then
  if [[ "$SCOPE" == "user" ]]; then
    SETTINGS="$HOME/.claude/settings.json"
  else
    SETTINGS=".claude/settings.json"
  fi
fi

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
