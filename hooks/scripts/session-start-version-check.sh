#!/usr/bin/env bash
# SessionStart hook — auto-detect Claude Code version drift.
#
# Best-practice plugin behavior on Claude Code upgrade:
#   1. Detect the current Claude Code version.
#   2. Compare against the last-seen version cached locally.
#   3. If drift detected, run scripts/post-upgrade-verify.sh
#      automatically. The operator gets a clear PASS/FAIL/DEGRADED
#      report without having to remember to verify manually.
#   4. Emit telemetry events for each transition.
#
# Wired by commands/install-hooks.sh into the SessionStart hook
# block. Idempotent; safe to re-run.

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
CACHE_FILE="${HOME}/.claude-tdd-pro/last-claude-version"
STANDALONE_MARKER="${HOME}/.claude-tdd-pro/standalone-mode"

# Bail quickly if standalone mode is engaged — the operator needs
# to disengage manually after confirming compatibility.
if [[ -f "$STANDALONE_MARKER" ]]; then
  echo "session-start-version-check: standalone mode engaged — skipping hooks." >&2
  echo "  inspect: cat $STANDALONE_MARKER" >&2
  echo "  re-engage: bash $PLUGIN_ROOT/hooks/scripts/payload-validator.sh --disengage" >&2
  exit 0
fi

# Detect current Claude Code version + read prior cached version.
current=$(bash "$PLUGIN_ROOT/commands/claude-version-detect.sh" --quiet 2>/dev/null \
  && bash "$PLUGIN_ROOT/commands/claude-version-detect.sh" 2>/dev/null)
prior=""
if [[ -f "$CACHE_FILE" ]]; then
  prior=$(cat "$CACHE_FILE")
fi

# First-ever run — just cache and exit clean.
if [[ -z "$prior" ]]; then
  echo "$current" > "$CACHE_FILE"
  if [[ -x "$PLUGIN_ROOT/space/telemetry-emit.sh" ]]; then
    bash "$PLUGIN_ROOT/space/telemetry-emit.sh" \
      --event "session-start.first-run" --severity "info" \
      --field "claude_version=$current" 2>/dev/null || true
  fi
  exit 0
fi

# Same version as last session — common path; exit clean.
if [[ "$current" == "$prior" ]]; then
  exit 0
fi

# Drift detected.
echo "claude-tdd-pro: Claude Code version drift detected" >&2
echo "  prior:   $prior" >&2
echo "  current: $current" >&2

if [[ -x "$PLUGIN_ROOT/space/telemetry-emit.sh" ]]; then
  bash "$PLUGIN_ROOT/space/telemetry-emit.sh" \
    --event "claude-version.drift-detected" --severity "warn" \
    --field "prior=$prior" --field "current=$current" \
    2>/dev/null || true
fi

# Auto-run post-upgrade verification.
if [[ -x "$PLUGIN_ROOT/scripts/post-upgrade-verify.sh" ]]; then
  echo "  running post-upgrade-verify..." >&2
  if bash "$PLUGIN_ROOT/scripts/post-upgrade-verify.sh" \
       --from "$prior" --to "$current" >&2; then
    echo "  post-upgrade-verify: PASS — continuing normal operation." >&2
    echo "$current" > "$CACHE_FILE"
  else
    rc=$?
    if [[ "$rc" -eq 2 ]]; then
      echo "  post-upgrade-verify: DEGRADED — continuing with warnings." >&2
      echo "$current" > "$CACHE_FILE"
    else
      echo "  post-upgrade-verify: FAIL — standalone mode engaged." >&2
      # post-upgrade-verify is responsible for engaging standalone
      # mode on FAIL; we just notify the operator.
    fi
  fi
else
  # No verify script; just update the cache and warn.
  echo "  (post-upgrade-verify.sh not present; cache updated)" >&2
  echo "$current" > "$CACHE_FILE"
fi
