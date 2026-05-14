#!/usr/bin/env bash
# /doctor — health-check command. Initial substrate handles G-12 routing only;
# extended in subsequent CLs to cover H-1 token-cost transparency, H-7 --watch
# monitor, multi-language coverage check (H-5), and others.
#
# Usage:
#   bash doctor.sh --check validate-all --root <dir>
#
# Per detector contract §2.2:
#   exit 0 → check passed
#   exit 1 → check failed
#   exit 2 → tooling/usage error

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
CHECK=""
ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK="$2"; shift 2 ;;
    --root) ROOT="$2"; shift 2 ;;
    -h|--help) sed -n '1,15p' "$0" | grep -E '^# ' | sed 's/^# //'; exit 0 ;;
    *) echo "doctor: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$CHECK" ]] && { echo "doctor: --check <name> required" >&2; exit 2; }

case "$CHECK" in
  validate-all)
    [[ -z "$ROOT" ]] && { echo "doctor: --check validate-all requires --root <dir>" >&2; exit 2; }
    if bash "$PLUGIN_ROOT/generated-code-quality-standards/validate-all.sh" --root "$ROOT" --format text 2>/dev/null; then
      echo "validate-all: ok" >&2
      exit 0
    else
      echo "validate-all: fail" >&2
      exit 1
    fi
    ;;
  *)
    echo "doctor: unknown check: $CHECK" >&2
    exit 2
    ;;
esac
