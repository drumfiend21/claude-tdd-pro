#!/usr/bin/env bash
# E-16 /plugin-remove — uninstall a plugin and flag affected rules with
# provenance_status: plugin-removed (so they show up in /doctor as orphaned).
set -uo pipefail
ID=""; RULES_DIR=""; DRY_RUN=0; ROOT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --rules-dir) RULES_DIR="$2"; shift 2 ;;
    --root) ROOT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) echo "Usage: plugin-remove.sh <id> [--rules-dir <dir>] [--root <gen-code-quality-standards>] [--dry-run]"; exit 0 ;;
    *) [[ -z "$ID" ]] && ID="$1"; shift ;;
  esac
done
[[ -z "$ID" ]] && { echo "plugin-remove: <id> required" >&2; exit 2; }

REG_BASE=".claude-tdd-pro/plugins/registered"
if [[ ! -d "$REG_BASE/$ID" ]]; then
  echo "plugin-remove: unknown_plugin_id $ID (try /plugin-list to see registered plugins)" >&2
  exit 2
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "plugin-remove: dry-run; would remove plugin_id=$ID and flag affected rules (no writes)" >&2
  exit 0
fi

if [[ -n "$RULES_DIR" && -d "$RULES_DIR" ]]; then
  for f in "$RULES_DIR"/*.yaml; do
    [[ ! -f "$f" ]] && continue
    if grep -qE "plugin_id:[[:space:]]*$ID" "$f"; then
      echo "provenance_status: plugin-removed" >> "$f"
      echo "plugin-remove: flagged rule file $f provenance_status=plugin-removed" >&2
    fi
  done
fi

# G-11 also remove the _community/<plugin-id> folder when --root is given.
if [[ -n "$ROOT" && -d "$ROOT/_community/$ID" ]]; then
  rm -rf "$ROOT/_community/$ID"
  echo "plugin-remove: removed _community/$ID source folder" >&2
fi

rm -rf "$REG_BASE/$ID"
echo "plugin-remove: removed plugin_id=$ID" >&2
