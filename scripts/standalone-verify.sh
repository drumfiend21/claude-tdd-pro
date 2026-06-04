#!/usr/bin/env bash
# Proves the system runs WITHOUT Claude Code as a dependency.
# Per docs/PLATFORM_DEPENDENCY.md: 85% of surface is
# platform-independent. This script exercises that 85% in isolation.
#
# Verifies:
#   1. Runner executes without Claude Code env vars set.
#   2. Fitness functions run in isolation.
#   3. LSP --print-diagnostics works as a CLI.
#   4. Installer's preflight + doctor work standalone.
#
# Usage:
#   bash scripts/standalone-verify.sh [--quiet]
#
# Exit codes:
#   0 — all standalone surfaces work
#   1 — at least one failed in standalone mode

set -uo pipefail
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
QUIET=0
[[ "${1:-}" == "--quiet" ]] && QUIET=1

pass=0
fail=0
check() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    [[ "$QUIET" -eq 0 ]] && printf '  ✓ %s\n' "$label" >&2
    pass=$((pass + 1))
  else
    [[ "$QUIET" -eq 0 ]] && printf '  ✗ %s\n' "$label" >&2
    fail=$((fail + 1))
  fi
}

# Unset every Claude-Code-specific env var for the duration.
unset CLAUDE_SESSION_ID CLAUDE_HOOKS_DIR

check "runner runs without CLAUDE_SESSION_ID" \
  env CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
    bash "$PLUGIN_ROOT/evals/runner.sh" --filter cl414-Q-1-space-config-yaml-ships

check "fitness function: substrate-completeness" \
  bash "$PLUGIN_ROOT/rubric/detectors/audit-substrate-completeness.sh" --quiet

check "fitness function: CLI surface fidelity" \
  bash "$PLUGIN_ROOT/rubric/detectors/audit-cli-surface-fidelity.sh" --quiet

check "fitness function: spec depth" \
  bash "$PLUGIN_ROOT/rubric/detectors/audit-spec-depth.sh" --quiet

check "LSP --print-diagnostics works as a CLI" \
  bash "$PLUGIN_ROOT/lsp/tdd-pro-lsp/tdd-pro-lsp" --print-diagnostics

check "installer preflight runs (--help)" \
  bash "$PLUGIN_ROOT/scripts/install.sh" --help

check "doctor command runs" \
  bash "$PLUGIN_ROOT/scripts/install.sh" doctor

check "version command runs" \
  bash "$PLUGIN_ROOT/scripts/install.sh" version

[[ "$QUIET" -eq 0 ]] && printf '\n%d/%d standalone surfaces work without Claude Code.\n' \
  "$pass" "$((pass + fail))" >&2

[[ "$fail" -eq 0 ]] && exit 0 || exit 1
