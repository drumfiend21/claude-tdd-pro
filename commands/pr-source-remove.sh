#!/usr/bin/env bash
# /pr-source-remove — G-9 archive for PR-SOURCES.yaml entry.
set -uo pipefail

ID=""; TREE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) ID="$2"; shift 2 ;;
    --tree) TREE="$2"; shift 2 ;;
    *) echo "pr-source-remove: unknown flag: $1" >&2; exit 2 ;;
  esac
done
[[ -z "$ID" || -z "$TREE" ]] && { echo "pr-source-remove: --id and --tree required" >&2; exit 2; }

TARGET=$(grep -rlE "^\s*id:\s*${ID}\s*$" "$TREE" --include="*.yaml" 2>/dev/null | head -1)
[[ -z "$TARGET" ]] && { echo "pr-source-remove: id $ID not found in $TREE" >&2; exit 1; }
NS_DIR=$(dirname "$TARGET")
mkdir -p "$NS_DIR/_archived"
mv "$TARGET" "$NS_DIR/_archived/"
echo "pr-source-remove: archived $TARGET → $NS_DIR/_archived/" >&2
