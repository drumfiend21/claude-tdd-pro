#!/usr/bin/env bash
# G-8 /operator-extension-init — scaffold _operator/<ns>/<file>-extensions.yaml
# so the operator can override plugin defaults via the source-folder cascade.
set -uo pipefail
NS=""; FILE=""; ROOT=""; DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) echo "Usage: operator-extension-init.sh <ns> <file> --root <dir> [--dry-run]"; exit 0 ;;
    *) if [[ -z "$NS" ]]; then NS="$1"; elif [[ -z "$FILE" ]]; then FILE="$1"; fi; shift ;;
  esac
done
[[ -z "$NS" || -z "$FILE" ]] && { echo "operator-extension-init: <ns> <file> required" >&2; exit 2; }
[[ -z "$ROOT" ]] && { echo "operator-extension-init: --root <dir> required" >&2; exit 2; }

SRC_DIR="$ROOT/$NS"
SRC_FILE="$SRC_DIR/$FILE.yaml"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "operator-extension-init: unknown_source_namespace $NS (no folder at $SRC_DIR)" >&2
  exit 2
fi
if [[ ! -f "$SRC_FILE" ]]; then
  echo "operator-extension-init: unknown_source_file $FILE (no $SRC_FILE in namespace $NS)" >&2
  exit 2
fi

TARGET_DIR="$ROOT/_operator/$NS"
TARGET_FILE="$TARGET_DIR/$FILE-extensions.yaml"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "operator-extension-init: planned: scaffold _operator/$NS/$FILE-extensions.yaml (no writes)" >&2
  exit 0
fi

mkdir -p "$TARGET_DIR"
SRC_ID=$(grep -E '^[[:space:]]*id:' "$SRC_FILE" | head -1 | sed -E 's/.*id:[[:space:]]*//')
cat > "$TARGET_FILE" <<YAML
source:
  id: ${SRC_ID:-$NS-$FILE}
  source_class: operator-extension
extends: $NS/$FILE.yaml
rules: []
YAML
echo "operator-extension-init: scaffolded $TARGET_FILE" >&2
