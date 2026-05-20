#!/usr/bin/env bash
# W-4 regenerate docs/adr/INDEX.md from the ADR files in the directory.
set -uo pipefail
ADR_DIR=""; INDEX=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --adr-dir) ADR_DIR="$2"; shift 2 ;;
    --index) INDEX="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[[ -z "$ADR_DIR" || ! -d "$ADR_DIR" ]] && { echo "regenerate-index: --adr-dir <dir> required" >&2; exit 2; }
[[ -z "$INDEX" ]] && { echo "regenerate-index: --index <path> required" >&2; exit 2; }

{
  echo "# ADR Index"
  echo ""
  echo "Auto-regenerated per W-4. Source of truth: $ADR_DIR/."
  echo ""
  for f in "$ADR_DIR"/*.md; do
    base=$(basename "$f" .md)
    [[ "$base" == "INDEX" ]] && continue
    title=$(head -1 "$f" | sed -E 's/^#[[:space:]]*//')
    echo "- [$base]($base.md) — $title"
  done
} > "$INDEX"
echo "regenerate-index: wrote $INDEX adr_count=$(ls "$ADR_DIR"/*.md 2>/dev/null | grep -v INDEX.md | wc -l | tr -d ' ')" >&2
