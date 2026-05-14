#!/usr/bin/env bash
# hooks/scripts/budget-impact-gate.sh — PreToolUse hook that blocks Write of
# a new skill/agent/hook file lacking budget_impact_estimate when the project
# has telemetry-baseline pinned. Per §13 O-0.
#
# Reads Claude Code hook event JSON from stdin (per Claude Code hook
# protocol). Exits 2 to block; 0 to allow.

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"

# Read hook event JSON from stdin.
EVENT=$(cat)
[[ -z "$EVENT" ]] && exit 0

# Extract file_path from tool_input. Only act on Write to skills/, agents/,
# hooks/scripts/.
TARGET=$(echo "$EVENT" | node -e '
  let s = "";
  process.stdin.on("data", d => s += d);
  process.stdin.on("end", () => {
    try {
      const j = JSON.parse(s);
      const fp = (j.tool_input || {}).file_path || "";
      process.stdout.write(fp);
    } catch { process.stdout.write(""); }
  });
')

[[ -z "$TARGET" ]] && exit 0

# Only gate on telemetered-component paths.
if [[ "$TARGET" != skills/* && "$TARGET" != agents/* && "$TARGET" != hooks/scripts/* ]]; then
  exit 0
fi

# Only enforce when a telemetry baseline is pinned (no pin → no enforcement).
LOCK_FILE="$PWD/.claude-tdd-pro/lock.json"
if [[ ! -f "$LOCK_FILE" ]]; then
  exit 0
fi
if ! grep -q '"telemetry_baseline_hash":"sha256:' "$LOCK_FILE"; then
  exit 0
fi

# Run budget-impact-required.sh on the target file.
if bash "$PLUGIN_ROOT/rubric/detectors/budget-impact-required.sh" --file "$TARGET" 2>/dev/null; then
  exit 0
fi

echo "budget-impact-gate: file $TARGET lacks budget_impact_estimate (required by O-0 when telemetry-baseline is pinned)" >&2
exit 2
