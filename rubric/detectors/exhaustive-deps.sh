#!/usr/bin/env bash
# exhaustive-deps.sh — R-3 substrate stub (per §16 R-3 + §2.2 detector
# contract). Wraps eslint-plugin-react-hooks/exhaustive-deps via E-15
# ESLint integration: this script declares the wrap relationship via
# --print-config and (when wired up) shells out to ESLint.
#
# Per §2.2 detector contract: supports --json, --paths, --dry-run,
# --help, --print-config. Findings to stderr.
#
# Usage:
#   exhaustive-deps.sh --json --paths "src/**/*.tsx" [--dry-run]
#   exhaustive-deps.sh --print-config

set -uo pipefail

JSON=0
PATHS=""
DRY=0
PRINT_CONFIG=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --paths) PATHS="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --print-config) PRINT_CONFIG=1; shift ;;
    -h|--help)
      echo "Usage: exhaustive-deps.sh --json --paths <glob> [--dry-run] [--print-config]"
      echo "Detector flags: --json --paths --dry-run"
      echo "E-15 wrap target: react-hooks/exhaustive-deps from eslint-plugin-react-hooks"
      exit 0
      ;;
    *) shift ;;
  esac
done

if [[ "$PRINT_CONFIG" -eq 1 ]]; then
  cat >&2 <<'EOF'
{
  "rule_id": "g-react-002",
  "wrap_target": "eslint",
  "eslint_rule": "react-hooks/exhaustive-deps",
  "eslint_plugin_npm": "eslint-plugin-react-hooks",
  "eslint_plugin_version_min": "5.0.0",
  "wrap_method": "E-15"
}
EOF
  exit 0
fi

if [[ "$DRY" -eq 1 ]]; then
  echo "exhaustive-deps: dry-run; would walk $PATHS via eslint" >&2
  exit 0
fi

shopt -s globstar nullglob 2>/dev/null

EXIT=0
for f in $PATHS; do
  [[ -f "$f" ]] || continue
done

exit "$EXIT"
