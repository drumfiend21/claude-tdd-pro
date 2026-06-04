#!/usr/bin/env bash
# Drift gate: CLI-surface fidelity audit.
#
# Verifies that every CLI flag documented in the architecture text
# for a substrate script is honored by that script's actual --help
# output (or argparse case statement). Catches the failure mode
# where docs promise --foo but the script only accepts --bar.
#
# Usage:
#   bash rubric/detectors/audit-cli-surface-fidelity.sh [--quiet]
#
# Exit codes:
#   0 — clean (every documented flag is honored)
#   1 — dirty (one or more flags documented but not honored)
#   2 — usage error

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
ARCH="$PLUGIN_ROOT/docs/architecture-v1.9.md"
QUIET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet|-q) QUIET=1; shift ;;
    -h|--help)
      echo "Usage: audit-cli-surface-fidelity.sh [--quiet]" >&2
      exit 0 ;;
    *) echo "audit-cli-surface-fidelity: unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -f "$ARCH" ]] || { echo "audit-cli-surface-fidelity: arch file missing: $ARCH" >&2; exit 2; }

# For the script-flag pairs we know about, check that the script
# honors each documented flag. This is a sample-based gate (not a
# full reverse-engineering of arch.md); each entry below corresponds
# to a script + flag pattern explicitly documented in arch §23/§24.

dirty=0
total=0

check_flag() {
  local script="$1" flag="$2" arch_ref="$3"
  total=$((total + 1))
  if [[ ! -f "$PLUGIN_ROOT/$script" ]]; then
    echo "MISSING_SCRIPT $arch_ref documents $script which does not exist"
    dirty=$((dirty + 1))
    return
  fi
  # Check the script's argument handling for the flag.
  if ! grep -qE "(\-\-${flag#--}\b|\"${flag}\")" "$PLUGIN_ROOT/$script" 2>/dev/null; then
    echo "MISSING_FLAG $arch_ref $script lacks $flag"
    dirty=$((dirty + 1))
  fi
}

# X-6 IDE rules export (§23): /export-rules <ide> [--profile] [--include]
#                              [--exclude] [--out] [--skip-fresh]
check_flag commands/export-rules.sh   --profile      "X-6 §23"
check_flag commands/export-rules.sh   --include      "X-6 §23"
check_flag commands/export-rules.sh   --exclude      "X-6 §23"
check_flag commands/export-rules.sh   --out          "X-6 §23"

# X-7 installable hooks bundle (§23): /install-hooks [--scope user|project]
#                                      [--include <component>] [--dry-run]
check_flag commands/install-hooks.sh  --scope        "X-7 §23"
check_flag commands/install-hooks.sh  --include      "X-7 §23"
check_flag commands/install-hooks.sh  --dry-run      "X-7 §23"

# X-8 LSP surface (§24): --print-diagnostics one-shot mode
check_flag lsp/tdd-pro-lsp/tdd-pro-lsp --print-diagnostics "X-8 §24"

# P-10 runtime model router (§24): /router-set --task-class --model
check_flag commands/router-set.sh     --task-class   "P-10 §24"
check_flag commands/router-set.sh     --model        "P-10 §24"

# O-12 application scaffolds (§24): /scaffold --kind --target
check_flag commands/scaffold.sh       --kind         "O-12 §24"
check_flag commands/scaffold.sh       --target       "O-12 §24"

# §2.14 dry-run subjects — every command in the §2.14 list must
# honor --dry-run. Sample the most-touched ones:
check_flag commands/export-rules.sh   --dry-run      "§2.14"
check_flag commands/install-hooks.sh  --dry-run      "§2.14"
check_flag commands/router-set.sh     --dry-run      "§2.14"
check_flag commands/scaffold.sh       --dry-run      "§2.14"

echo "cli_surface_audit=$( [[ $dirty -eq 0 ]] && echo clean || echo dirty ) checks=$total dirty=$dirty"
[[ $dirty -eq 0 ]] && exit 0 || exit 1
