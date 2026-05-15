#!/usr/bin/env bash
# /compliance-remove — G-9 archive for COMPLIANCE-URLS.yaml entry.
set -uo pipefail

ID=""; TREE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) ID="$2"; shift 2 ;;
    --tree) TREE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) echo "Usage: compliance-remove.sh ... [--dry-run]"; exit 0 ;;
    *) echo "compliance-remove: unknown flag: $1" >&2; exit 2 ;;
  esac
done
[[ -z "$ID" || -z "$TREE" ]] && { echo "compliance-remove: --id and --tree required" >&2; exit 2; }

TARGET=$(grep -rlE "^\s*id:\s*${ID}\s*$" "$TREE" --include="*.yaml" 2>/dev/null | head -1)
[[ -z "$TARGET" ]] && { echo "compliance-remove: id $ID not found in $TREE" >&2; exit 1; }
NS_DIR=$(dirname "$TARGET")
mkdir -p "$NS_DIR/_archived"
mv "$TARGET" "$NS_DIR/_archived/"
echo "compliance-remove: archived $TARGET → $NS_DIR/_archived/" >&2
