#!/usr/bin/env bash
# Detect the running Claude Code version.
#
# Tries multiple sources in order:
#   1. CLAUDE_CODE_VERSION env var (Claude Code sets this in sessions)
#   2. `claude --version` CLI output (if claude binary is on PATH)
#   3. ~/.claude/version, ~/.claude/CHANGELOG.md, or settings.json
#   4. Last-seen version cached at ~/.claude-tdd-pro/last-claude-version
#
# Emits the version string on stdout. Exit 0 if detected, 1 if not.
# Always emits a telemetry event with the detected (or "unknown") version.
#
# Usage:
#   commands/claude-version-detect.sh [--quiet] [--cache]
#
# Flags:
#   --quiet     Don't print to stdout; only exit code matters.
#   --cache     Update ~/.claude-tdd-pro/last-claude-version with the
#               detected value (used by the SessionStart hook to compare
#               against the prior session).

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
CACHE_FILE="${HOME}/.claude-tdd-pro/last-claude-version"
QUIET=0
CACHE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet) QUIET=1; shift ;;
    --cache) CACHE=1; shift ;;
    -h|--help)
      echo "Usage: claude-version-detect.sh [--quiet] [--cache]" >&2
      exit 0 ;;
    *) echo "claude-version-detect: unknown arg: $1" >&2; exit 2 ;;
  esac
done

detect() {
  # Source 1 — env var (set by Claude Code at session start)
  if [[ -n "${CLAUDE_CODE_VERSION:-}" ]]; then
    printf 'env:%s' "$CLAUDE_CODE_VERSION"
    return 0
  fi
  # Source 2 — CLI
  if command -v claude >/dev/null 2>&1; then
    local v
    v=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
    if [[ -n "$v" ]]; then
      printf 'cli:%s' "$v"
      return 0
    fi
  fi
  # Source 3 — settings.json / version file
  for f in "$HOME/.claude/version" "$HOME/.claude/.version" "$HOME/.claude/settings.json"; do
    if [[ -f "$f" ]]; then
      local v
      v=$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[0-9.]+"' "$f" 2>/dev/null \
        | head -1 | grep -oE '[0-9.]+')
      if [[ -z "$v" ]]; then
        v=$(cat "$f" 2>/dev/null | grep -oE '^[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
      fi
      if [[ -n "$v" ]]; then
        printf 'file:%s' "$v"
        return 0
      fi
    fi
  done
  return 1
}

version=$(detect)
rc=$?

if [[ "$rc" -ne 0 ]]; then
  version="unknown"
fi

if [[ "$QUIET" -eq 0 ]]; then
  echo "$version"
fi

# Cache for next session's drift comparison
if [[ "$CACHE" -eq 1 ]]; then
  mkdir -p "$(dirname "$CACHE_FILE")"
  echo "$version" > "$CACHE_FILE"
fi

# Telemetry
if [[ -x "$PLUGIN_ROOT/space/telemetry-emit.sh" ]]; then
  bash "$PLUGIN_ROOT/space/telemetry-emit.sh" \
    --event "claude-version.detected" --severity "info" \
    --field "version=$version" 2>/dev/null || true
fi

[[ "$rc" -eq 0 ]] && exit 0 || exit 1
