#!/usr/bin/env bash
# compliance-remove.sh — C-17 substrate. Removes an entry from
# .claude-tdd-pro/COMPLIANCE-URLS.yaml catalog.
#
# Per architecture section 16 C-17: "/compliance-remove <id>".
#
# Usage:
#   compliance-remove.sh <id> --catalog <path>
#                        [--controls-file <path>]   # block when cited
#                        [--target <tree-dir>]       # C-14 sync to archive folder
#                        [--audit-log <path>]
#                        [--force]                   # required for default bundled entries
#                        [--dry-run]

set -uo pipefail

ID=""
CATALOG=""
CONTROLS_FILE=""
TARGET_TREE=""
LEGACY_TREE=""
AUDIT_LOG=""
FORCE=0
DRY_RUN=0

# First positional arg is the ID (unless it starts with --).
if [[ $# -gt 0 && "${1:0:2}" != "--" && "$1" != "-h" ]]; then
  ID="$1"
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) ID="$2"; shift 2 ;;
    --catalog) CATALOG="$2"; shift 2 ;;
    --controls-file) CONTROLS_FILE="$2"; shift 2 ;;
    --target) TARGET_TREE="$2"; shift 2 ;;
    --tree) LEGACY_TREE="$2"; shift 2 ;;
    --audit-log) AUDIT_LOG="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      echo "Usage: compliance-remove.sh <id> --catalog <path> [--controls-file <path>] [--target <dir>] [--audit-log <path>] [--force] [--dry-run]"
      echo "       compliance-remove.sh --id <id> --tree <dir>  (legacy G-9 mode)"
      exit 0
      ;;
    *) shift ;;
  esac
done

# Legacy G-9 mode: --tree without --catalog (archive yaml file under <tree>/<jur>/_archived/).
if [[ -n "$LEGACY_TREE" && -z "$CATALOG" ]]; then
  if [[ -z "$ID" ]]; then
    echo "compliance-remove (legacy mode): --id required" >&2
    exit 2
  fi
  TARGET=$(grep -rlE "^[[:space:]]*id:[[:space:]]*${ID}[[:space:]]*\$" "$LEGACY_TREE" --include="*.yaml" 2>/dev/null | head -1)
  [[ -z "$TARGET" ]] && { echo "compliance-remove: id $ID not found in $LEGACY_TREE" >&2; exit 1; }
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "compliance-remove: dry-run; would archive $TARGET (no writes)" >&2
    exit 0
  fi
  NS_DIR=$(dirname "$TARGET")
  mkdir -p "$NS_DIR/_archived"
  mv "$TARGET" "$NS_DIR/_archived/"
  echo "compliance-remove: archived $TARGET -> $NS_DIR/_archived/" >&2
  exit 0
fi

if [[ -z "$ID" ]]; then
  echo "compliance-remove: positional <id> argument is required" >&2
  exit 2
fi

if [[ -z "$CATALOG" || ! -f "$CATALOG" ]]; then
  echo "compliance-remove: --catalog <path> required (and must exist)" >&2
  exit 2
fi

# Find the entry block in the catalog (between `^- id: <ID>` and the next `^- ` or EOF).
if ! grep -qE "^- id: $ID\$|^- id: $ID[[:space:]]*\$" "$CATALOG"; then
  echo "compliance-remove: id $ID not found in $CATALOG (unknown id)" >&2
  exit 2
fi

# Block when controls.yaml still cites this framework. Check FIRST so
# the citation error wins over the default-bundled error (per spec
# blocks-removal-when-controls-yaml-still-cites-framework).
if [[ -n "$CONTROLS_FILE" && -f "$CONTROLS_FILE" ]]; then
  if grep -qE "^- framework: $ID\$|^- framework: $ID[[:space:]]*\$" "$CONTROLS_FILE"; then
    CITED_CONTROLS=$(awk -v fw="$ID" '
      /^- framework:/ { in_block = ($0 ~ "framework: "fw"$") }
      in_block && /control_id:/ {
        sub(".*control_id:[[:space:]]*", "")
        print
      }
    ' "$CONTROLS_FILE" | tr '\n' ' ')
    echo "compliance-remove: $ID still cited in $CONTROLS_FILE (controls: ${CITED_CONTROLS}); remove control-mapping entries first" >&2
    exit 2
  fi
fi

# Default bundled list — these require --force.
DEFAULT_BUNDLED="soc2-tsc pci-dss-v4 nist-800-218 hipaa nist-csf-2 eu-ai-act gdpr"
case " $DEFAULT_BUNDLED " in
  *" $ID "*)
    if [[ "$FORCE" -ne 1 ]]; then
      echo "compliance-remove: $ID is a default bundled entry; pass --force to remove" >&2
      exit 2
    fi
    ;;
esac

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "compliance-remove: dry-run; would remove $ID from $CATALOG (no writes)" >&2
  exit 0
fi

# Remove the block (lines from `^- id: <ID>` until next `^- ` or EOF).
ID="$ID" CATALOG="$CATALOG" node -e '
const fs = require("fs");
const id = process.env.ID;
const path = process.env.CATALOG;
const lines = fs.readFileSync(path, "utf8").split("\n");
const out = [];
let skipping = false;
for (const line of lines) {
  if (line === `- id: ${id}` || line.match(new RegExp(`^- id: ${id}\\s*$`))) {
    skipping = true;
    continue;
  }
  if (skipping && line.startsWith("- ")) {
    skipping = false;
  }
  if (!skipping) out.push(line);
}
fs.writeFileSync(path, out.join("\n"));
'

# C-14 sync to archive folder.
if [[ -n "$TARGET_TREE" ]]; then
  SOURCE_DIR=""
  for jur in us-government european-union international us; do
    if [[ -d "$TARGET_TREE/$jur/$ID" ]]; then
      SOURCE_DIR="$TARGET_TREE/$jur/$ID"; break
    fi
  done
  if [[ -n "$SOURCE_DIR" ]]; then
    # C-14 archive convention: move to <tree>/_meta/archived/<id>
    ARCHIVE_DIR="$TARGET_TREE/_meta/archived"
    mkdir -p "$ARCHIVE_DIR"
    mv "$SOURCE_DIR" "$ARCHIVE_DIR/$ID"
    echo "compliance-remove: archived $SOURCE_DIR -> $ARCHIVE_DIR/$ID" >&2
  fi
fi

if [[ -n "$AUDIT_LOG" ]]; then
  mkdir -p "$(dirname "$AUDIT_LOG")"
  echo "{\"event\":\"compliance-remove\",\"id\":\"$ID\",\"force\":$([ "$FORCE" -eq 1 ] && echo true || echo false),\"at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "$AUDIT_LOG"
fi

echo "compliance-remove: removed $ID from $CATALOG" >&2
exit 0
