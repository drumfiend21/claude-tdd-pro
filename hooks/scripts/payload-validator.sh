#!/usr/bin/env bash
# Hook payload shape validator with auto-fallback to standalone mode.
#
# Sourced at the top of every hook script. Validates that the JSON
# payload Claude Code sends matches the contract in
# compatibility/claude-code-versions.yaml. On divergence:
#   1. Logs a hook.payload-shape-divergence telemetry event.
#   2. Engages auto-standalone mode (writes a marker file the
#      remaining hook scripts read at top).
#   3. Returns rc=0 to Claude Code (so Claude Code doesn't see a
#      crash and re-fire); the plugin's own surfaces continue via
#      CLI / LSP / CI.
#
# Usage (in a hook script):
#   source "$CLAUDE_PLUGIN_ROOT/hooks/scripts/payload-validator.sh"
#   validate_payload "PreToolUse" "$PAYLOAD_JSON" || exit 0

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
STANDALONE_MARKER="${HOME}/.claude-tdd-pro/standalone-mode"

# Validate a payload against the contract for the given hook event.
# Returns 0 on valid, 1 on invalid (caller should fall back).
validate_payload() {
  local hook_name="$1"
  local payload="$2"

  # Empty payload may be normal for some hooks (Stop, SessionStart).
  if [[ -z "$payload" ]]; then
    return 0
  fi

  # Quick JSON parse check; if it doesn't parse, it's broken.
  if ! echo "$payload" | node -e 'JSON.parse(require("fs").readFileSync(0, "utf8"))' 2>/dev/null; then
    _report_divergence "$hook_name" "payload not valid JSON"
    _engage_standalone
    return 1
  fi

  # Per-hook required-field check, per compatibility/claude-code-versions.yaml.
  local required=""
  case "$hook_name" in
    PreToolUse)    required="tool_name" ;;
    PostToolUse)   required="tool_name" ;;
    Stop)          return 0 ;;
    SessionStart)  return 0 ;;
    *)             return 0 ;;  # unknown hook → don't gate
  esac

  if [[ -n "$required" ]]; then
    local has_field
    has_field=$(echo "$payload" | node -e '
      try {
        const j = JSON.parse(require("fs").readFileSync(0, "utf8"));
        const f = process.env.FIELD;
        process.stdout.write(f in j ? "yes" : "no");
      } catch { process.stdout.write("no"); }
    ' FIELD="$required" 2>/dev/null)
    if [[ "$has_field" != "yes" ]]; then
      _report_divergence "$hook_name" "missing required field: $required"
      _engage_standalone
      return 1
    fi
  fi

  return 0
}

# Check whether standalone-mode is currently engaged. Hook scripts
# should call this at the top and exit 0 immediately if true.
is_standalone_engaged() {
  [[ -f "$STANDALONE_MARKER" ]]
}

# Re-engage normal mode (operator-driven, after they've confirmed
# compatibility).
disengage_standalone() {
  rm -f "$STANDALONE_MARKER"
  if [[ -x "$PLUGIN_ROOT/space/telemetry-emit.sh" ]]; then
    bash "$PLUGIN_ROOT/space/telemetry-emit.sh" \
      --event "standalone-mode.disengaged" --severity "info" \
      2>/dev/null || true
  fi
}

# Internal: log a divergence event with full context.
_report_divergence() {
  local hook="$1" reason="$2"
  if [[ -x "$PLUGIN_ROOT/space/telemetry-emit.sh" ]]; then
    bash "$PLUGIN_ROOT/space/telemetry-emit.sh" \
      --event "hook.payload-shape-divergence" --severity "error" \
      --field "hook=$hook" --field "reason=$reason" \
      2>/dev/null || true
  fi
}

# Internal: engage standalone mode (creates the marker file the
# other hook scripts check). Also surfaces a one-time operator notice.
_engage_standalone() {
  if [[ -f "$STANDALONE_MARKER" ]]; then
    return 0  # already engaged
  fi
  mkdir -p "$(dirname "$STANDALONE_MARKER")"
  cat > "$STANDALONE_MARKER" <<EOF
{
  "engaged_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "reason": "Hook payload shape divergence detected",
  "next_step": "Run scripts/post-upgrade-verify.sh to investigate, then bash commands/install.sh upgrade to re-pin if compatibility is confirmed.",
  "manual_disengage": "rm $STANDALONE_MARKER"
}
EOF
  if [[ -x "$PLUGIN_ROOT/space/telemetry-emit.sh" ]]; then
    bash "$PLUGIN_ROOT/space/telemetry-emit.sh" \
      --event "standalone-mode.engaged" --severity "warn" \
      --field "trigger=hook-payload-divergence" \
      2>/dev/null || true
  fi
  echo "claude-tdd-pro: standalone mode engaged (hook payload divergence)." >&2
  echo "  next step: bash $PLUGIN_ROOT/scripts/post-upgrade-verify.sh" >&2
  echo "  marker:    $STANDALONE_MARKER" >&2
}

# When invoked directly (not sourced), accept --check / --disengage
# operator commands.
if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
  case "${1:-}" in
    --check)
      if is_standalone_engaged; then
        echo "standalone-mode: engaged" >&2
        cat "$STANDALONE_MARKER" >&2
        exit 1
      fi
      echo "standalone-mode: not engaged" >&2
      exit 0 ;;
    --disengage)
      disengage_standalone
      echo "standalone-mode: disengaged" >&2
      exit 0 ;;
    -h|--help|*)
      echo "Usage: payload-validator.sh [--check | --disengage]" >&2
      echo "  --check:     report current standalone-mode state" >&2
      echo "  --disengage: clear the standalone-mode marker" >&2
      echo "  (when sourced from a hook: provides validate_payload + is_standalone_engaged)" >&2
      exit 0 ;;
  esac
fi
