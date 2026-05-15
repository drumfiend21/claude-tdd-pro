#!/usr/bin/env bash
# _install.sh — R-5 substrate stub: copies R-4 templates into a
# target React project. Exposed via the react-component-build skill
# (per §16 R-5 + R-4).
#
# Usage:
#   _install.sh --target <project-dir> [--dry-run]

set -uo pipefail

TARGET=""
DRY=0
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help)
      echo "Usage: _install.sh --target <dir> [--dry-run]"
      exit 0
      ;;
    *) shift ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  echo "_install: --target required" >&2
  exit 2
fi

TEMPLATES=(
  vitest.react.config.ts
  playwright.config.ts
  size-limit.config.js
)

for t in "${TEMPLATES[@]}"; do
  src="$PLUGIN_ROOT/templates/$t"
  dest="$TARGET/$t"
  if [[ "$DRY" -eq 1 ]]; then
    echo "would copy $t -> $dest" >&2
  else
    mkdir -p "$TARGET"
    cp "$src" "$dest"
    echo "installed $t -> $dest" >&2
  fi
done

exit 0
