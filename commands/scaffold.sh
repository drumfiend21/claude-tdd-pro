#!/usr/bin/env bash
# O-12 application scaffolds per §13. Bootstraps a fresh project from
# one of the included scaffolds (next-saas, node-api, python-fastapi,
# react-spa) with the TDD Pro plugin pre-wired.
#
# Usage:
#   commands/scaffold.sh --kind <next-saas|node-api|python-fastapi|react-spa>
#                        --target <dir>
#                        [--dry-run]
#
# Exit codes:
#   0 — created (or dry-run plan emitted)
#   2 — usage error

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"

KIND=""
TARGET=""
DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --kind) KIND="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      echo "Usage: scaffold.sh --kind <next-saas|node-api|python-fastapi|react-spa> --target <dir> [--dry-run]"
      exit 0 ;;
    *) echo "scaffold: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$KIND" || -z "$TARGET" ]] && { echo "scaffold: --kind + --target required" >&2; exit 2; }

case "$KIND" in
  next-saas|node-api|python-fastapi|react-spa) : ;;
  *) echo "scaffold: --kind must be next-saas|node-api|python-fastapi|react-spa (got $KIND)" >&2; exit 2 ;;
esac

SRC="$PLUGIN_ROOT/scaffolds/$KIND"
[[ ! -d "$SRC" ]] && { echo "scaffold: $SRC not found" >&2; exit 2; }

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "scaffold: dry-run; would copy $SRC -> $TARGET" >&2
  exit 0
fi

mkdir -p "$TARGET"
cp -R "$SRC"/. "$TARGET"/
echo "scaffold: created $KIND at $TARGET" >&2
exit 0
