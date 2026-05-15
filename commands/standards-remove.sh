#!/usr/bin/env bash
# /standards-remove — G-9 archive for STANDARDS-URLS.yaml entry.
# Moves the matching folder file to _archived/.
set -uo pipefail

ID=""; TREE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) ID="$2"; shift 2 ;;
    --tree) TREE="$2"; shift 2 ;;
    *) echo "standards-remove: unknown flag: $1" >&2; exit 2 ;;
  esac
done
[[ -z "$ID" || -z "$TREE" ]] && { echo "standards-remove: --id and --tree required" >&2; exit 2; }

# Find any source-folder file whose source.id matches.
TARGET=$(grep -rlE "^\s*id:\s*${ID}\s*$" "$TREE" --include="*.yaml" 2>/dev/null | head -1)
[[ -z "$TARGET" ]] && { echo "standards-remove: id $ID not found in $TREE" >&2; exit 1; }
NS_DIR=$(dirname "$TARGET")
mkdir -p "$NS_DIR/_archived"
mv "$TARGET" "$NS_DIR/_archived/"
echo "standards-remove: archived $TARGET → $NS_DIR/_archived/" >&2
