#!/usr/bin/env bash
# G-8 /operator-namespace-init — scaffold _operator/<my-org>/ with a starter
# conventions.yaml so the operator can author org-scoped rules without
# touching shipped source folders.
set -uo pipefail
ORG=""; ROOT=""; DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) echo "Usage: operator-namespace-init.sh <my-org> --root <dir> [--dry-run]"; exit 0 ;;
    *) [[ -z "$ORG" ]] && ORG="$1"; shift ;;
  esac
done
[[ -z "$ORG" ]] && { echo "operator-namespace-init: <my-org> required" >&2; exit 2; }
[[ -z "$ROOT" ]] && { echo "operator-namespace-init: --root <dir> required" >&2; exit 2; }

TARGET_DIR="$ROOT/_operator/$ORG"
TARGET_FILE="$TARGET_DIR/conventions.yaml"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "operator-namespace-init: planned: scaffold _operator/$ORG/conventions.yaml (no writes)" >&2
  exit 0
fi

if [[ -d "$TARGET_DIR" ]]; then
  echo "operator-namespace-init: already_exists $TARGET_DIR (refuse to overwrite; rm -rf manually if intended)" >&2
  exit 2
fi

mkdir -p "$TARGET_DIR"
cat > "$TARGET_FILE" <<YAML
source:
  id: $ORG-operator-conventions
  source_class: operator
rules: []
YAML
echo "operator-namespace-init: scaffolded $TARGET_FILE" >&2
