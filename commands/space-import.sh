#!/usr/bin/env bash
# Q-8 space-import: rejects multi-user bundles per solo-scale scope.
set -uo pipefail
BUNDLE=""; CONFIG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle) BUNDLE="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    -h|--help) echo "Usage: space-import.sh --bundle <json> [--config <yaml>]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$BUNDLE" || ! -f "$BUNDLE" ]] && { echo "space-import: --bundle <path> required" >&2; exit 2; }

# Reject multi-user bundles.
if BUNDLE="$BUNDLE" node -e 'const j=JSON.parse(require("fs").readFileSync(process.env.BUNDLE,"utf8"));process.exit((j.included_users||[]).length > 1 ? 0 : 1)' 2>/dev/null; then
  echo "space-import: multi-user bundle rejected; this dashboard is solo-scale only (the scope contract refuses team-rollup imports)" >&2
  exit 2
fi
echo "space-import: ok" >&2
