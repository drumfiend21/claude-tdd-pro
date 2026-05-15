#!/usr/bin/env bash
# /standards-remove — S-15 + G-9 archive per §16:
#   "/standards-remove <id>." (S-15)
#   "/standards-remove archives folder file to _archived/." (G-9)
#
# Removes the entry from .claude-tdd-pro/STANDARDS-URLS.yaml AND
# archives the matching folder file to <ns>/_archived/. Bundled
# sources (those in plugin standards/sources.yaml) are protected
# unless --force.
#
# Usage:
#   standards-remove.sh --id <id> [--tree <dir>] [--force] [--dry-run]
#                       [--force-orphan] [--check-orphan-rules]
#                       [--emit-audit <jsonl>]

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
ID=""; TREE=""; FORCE=0; DRY_RUN=0; FORCE_ORPHAN=0; CHECK_ORPHAN=0; EMIT_AUDIT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) ID="$2"; shift 2 ;;
    --tree) TREE="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --force-orphan) FORCE_ORPHAN=1; shift ;;
    --check-orphan-rules) CHECK_ORPHAN=1; shift ;;
    --emit-audit) EMIT_AUDIT="$2"; shift 2 ;;
    *) echo "standards-remove: unknown flag: $1" >&2; exit 2 ;;
  esac
done
[[ -z "$ID" ]] && { echo "standards-remove: --id <id> required" >&2; exit 2; }

# Bundled-source check.
BUNDLED_FILE="$PLUGIN_ROOT/standards/sources.yaml"
IS_BUNDLED=0
if [[ -f "$BUNDLED_FILE" ]] && grep -qE "^- id: ${ID}\$" "$BUNDLED_FILE"; then
  IS_BUNDLED=1
fi

if [[ "$IS_BUNDLED" -eq 1 && "$FORCE" -eq 0 ]]; then
  echo "standards-remove: id $ID is bundled (in plugin's standards/sources.yaml); use --force to remove or set 'disable: true' in operator registry instead" >&2
  exit 2
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "standards-remove: dry-run; would remove id=$ID" >&2
  exit 0
fi

REGISTRY=".claude-tdd-pro/STANDARDS-URLS.yaml"
REMOVED_FROM_REGISTRY=0
if [[ -f "$REGISTRY" ]] && grep -qE "^- id: ${ID}\$" "$REGISTRY"; then
  # Remove block: from "- id: $ID" line until next "- id:" or EOF.
  awk -v target="- id: $ID" '
    /^- id: / {
      if (in_block) in_block = 0
      if ($0 == target) { in_block = 1; next }
    }
    !in_block { print }
  ' "$REGISTRY" > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"
  REMOVED_FROM_REGISTRY=1
fi

# Orphan-rule check BEFORE archiving so the archived copy isn't found
# by grep. Uses perl for portable regex capture (BSD awk lacks the
# gawk 3-arg match() form).
if [[ "$CHECK_ORPHAN" -eq 1 && -n "$TREE" ]]; then
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    [[ "$f" == */_archived/* ]] && continue
    perl -ne '
      BEGIN { $src = shift @ARGV; $in_rules = 0; }
      if (/^rules:/) { $in_rules = 1; next; }
      next unless $in_rules;
      if (/\bid:\s*([a-zA-Z0-9_\/\-]+)/) { $rid = $1; }
      if (/source:\s*([a-zA-Z0-9_\-]+)/ && $1 eq $src && $rid) { print "$rid\n"; }
    ' "$ID" "$f" | sort -u | while read -r rid; do
      [[ -n "$rid" ]] && echo "standards-remove: rule $rid orphaned (still cites removed source $ID)" >&2
    done
  done < <(grep -rlE "source:\s*${ID}\b" "$TREE" --include="*.yaml" 2>/dev/null)
fi

# Folder-file archive (when --tree given OR id can be located).
ARCHIVED=""
if [[ -n "$TREE" ]]; then
  TARGET=$(grep -rlE "^\s*id:\s*${ID}\s*$" "$TREE" --include="*.yaml" 2>/dev/null | grep -v "/_archived/" | head -1)
  if [[ -n "$TARGET" ]]; then
    NS_DIR=$(dirname "$TARGET")
    mkdir -p "$NS_DIR/_archived"
    mv "$TARGET" "$NS_DIR/_archived/"
    ARCHIVED="$NS_DIR/_archived/$(basename "$TARGET")"
  fi
fi

# Audit log.
if [[ -n "$EMIT_AUDIT" ]]; then
  mkdir -p "$(dirname "$EMIT_AUDIT")"
  TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  ACTION="standards-remove"
  [[ "$IS_BUNDLED" -eq 1 ]] && ACTION="standards-remove force-removed-bundled"
  printf '{"command":"%s","id":"%s","ts":"%s","archived":"%s"}\n' "$ACTION" "$ID" "$TS" "$ARCHIVED" >> "$EMIT_AUDIT"
fi

if [[ "$REMOVED_FROM_REGISTRY" -eq 0 && -z "$ARCHIVED" && "$IS_BUNDLED" -eq 0 ]]; then
  echo "standards-remove: id $ID not found (no registry entry, no folder file, not bundled)" >&2
  exit 2
fi

echo "standards-remove: removed $ID (registry=$REMOVED_FROM_REGISTRY archived=${ARCHIVED:-no})" >&2
