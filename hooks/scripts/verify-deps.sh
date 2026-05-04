#!/usr/bin/env bash
# Setup hook: verify the tools claude-tdd-pro relies on are present.
# Runs once when the plugin is enabled. Never blocks the session —
# only emits warnings the user can act on.

set -uo pipefail

missing=()
warned=()

check() {
  local name="$1"
  local hint="$2"
  if ! command -v "$name" >/dev/null 2>&1; then
    missing+=("$name — $hint")
  fi
}

check_optional() {
  local name="$1"
  local hint="$2"
  if ! command -v "$name" >/dev/null 2>&1; then
    warned+=("$name — $hint")
  fi
}

# Required for the plugin to function at all
check "git"  "git is required for snapshot/commit/PR workflows. Install from https://git-scm.com"
check "node" "Node.js is required for ESLint, Prettier, and the lint hook. Install from https://nodejs.org (LTS)"
check "npm"  "npm is required to install per-project dev deps. Comes with Node.js."

# Required for /pr command
check_optional "gh" "GitHub CLI not found. Required by /pr command. Install: brew install gh (macOS) or see https://cli.github.com"

# Optional but recommended
check_optional "ruff"  "Python projects: ruff not found. Install: pip install ruff (or brew install ruff)"
check_optional "black" "Python projects: black not found. Install: pip install black"

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "[claude-tdd-pro] REQUIRED dependencies missing:" >&2
  for m in "${missing[@]}"; do echo "  ✗ $m" >&2; done
  echo "" >&2
fi

if [[ ${#warned[@]} -gt 0 ]]; then
  echo "[claude-tdd-pro] Optional dependencies not found (some commands will be unavailable):" >&2
  for w in "${warned[@]}"; do echo "  ⚠ $w" >&2; done
  echo "" >&2
fi

# `gh` extra check: warn if installed but not authenticated
if command -v gh >/dev/null 2>&1; then
  if ! gh auth status >/dev/null 2>&1; then
    echo "[claude-tdd-pro] ⚠ gh CLI not authenticated. Run: gh auth login" >&2
  fi
fi

# Never exit non-zero — we only inform.
exit 0
