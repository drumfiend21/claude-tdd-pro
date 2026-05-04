#!/usr/bin/env bash
# Stop hook: refuse to declare done when the diff has unresolved
# rubric P0 findings, leaked secrets, or lint failures.
#
# Per the v0.3 plan, this hook is narrowed: it only fires when the
# session was driven by /remediate, /pr, /feature, /fix-bug, or
# /extract-component (i.e. side-effecting flows). Greenfield free-form
# editing still rides on PreToolUse (TDD-Guard) plus PostToolUse (lint),
# without Stop-gating, to avoid the over-blocking that the validation
# pass flagged.
#
# Activation logic:
#   - If CLAUDE_TDD_PRO_STOP=off → exit 0 (no gate).
#   - If .claude-tdd-pro/stop-gate.disabled exists → exit 0.
#   - If .claude-tdd-pro/active-flow contains one of the gated commands
#     → run the gate. Otherwise → exit 0.
#
# Gate composition (in order; first failure blocks):
#   1. secret-scan.sh (P0, security)
#   2. rubric-runner.sh --diff --severity P0 --quiet (P0 rule findings)
#   3. lint-on-save.sh dry-run (project's lint config)
#
# Output protocol per code.claude.com/docs/en/hooks:
#   exit 2 + stderr → "block" decision; Claude must address findings.
#   exit 0 → allow Stop.

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
WORKSPACE="${CLAUDE_PROJECT_DIR:-$PWD}"

# Master kill-switch
[[ "${CLAUDE_TDD_PRO_STOP:-}" == "off" ]] && exit 0
[[ -f "$WORKSPACE/.claude-tdd-pro/stop-gate.disabled" ]] && exit 0

# Active-flow gate — only fire on side-effecting commands.
flow_file="$WORKSPACE/.claude-tdd-pro/active-flow"
if [[ ! -f "$flow_file" ]]; then exit 0; fi
case "$(cat "$flow_file" 2>/dev/null)" in
  remediate|pr|feature|fix-bug|extract-component) ;;
  *) exit 0 ;;
esac

block() {
  local why="$1"
  cat >&2 <<EOF
[stop-gate] BLOCKING: $why

This hook fires for /remediate, /pr, /feature, /fix-bug, and
/extract-component flows. Resolve the findings before declaring done.

Disable for this session only:
  rm $flow_file

Disable per-project:
  touch $WORKSPACE/.claude-tdd-pro/stop-gate.disabled
EOF
  exit 2
}

# 1. secret-scan
if [[ -x "$PLUGIN_ROOT/hooks/scripts/secret-scan.sh" ]]; then
  if ! "$PLUGIN_ROOT/hooks/scripts/secret-scan.sh" >/dev/null 2>&1; then
    block "secret-scan flagged a leaked credential. Run: bash $PLUGIN_ROOT/hooks/scripts/secret-scan.sh"
  fi
fi

# 2. rubric (P0 only at the gate; P1 surfaces in /analyze)
if [[ -x "$PLUGIN_ROOT/rubric/runner.sh" ]]; then
  if ! "$PLUGIN_ROOT/rubric/runner.sh" --diff --severity P0 --quiet >/dev/null 2>&1; then
    rc=$?
    if [[ $rc -eq 2 ]]; then
      msg="$("$PLUGIN_ROOT/rubric/runner.sh" --diff --severity P0 --md 2>/dev/null | head -40)"
      block "rubric P0 findings present:
$msg"
    fi
  fi
fi

# 3. lint dry-run (uses the existing PostToolUse script if present)
if [[ -x "$PLUGIN_ROOT/hooks/scripts/lint-on-save.sh" ]]; then
  # Lint-on-save expects a per-file invocation via stdin JSON. Skip the
  # dry-run if no diff (already-clean). For the Stop gate, we only
  # surface if the linter is wired and project-local.
  changed="$(git -C "$WORKSPACE" diff --name-only HEAD 2>/dev/null | grep -E '\.(ts|tsx|js|jsx|py)$' | head -1)"
  if [[ -n "$changed" ]]; then
    if [[ -f "$WORKSPACE/eslint.config.js" || -f "$WORKSPACE/.eslintrc.cjs" || -f "$WORKSPACE/.eslintrc.json" ]]; then
      if ! (cd "$WORKSPACE" && npx --no-install eslint --max-warnings 0 "$changed" >/dev/null 2>&1); then
        block "eslint reports errors on $changed. Run: npx eslint $changed"
      fi
    fi
  fi
fi

exit 0
