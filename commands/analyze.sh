#!/usr/bin/env bash
# H-5 /analyze — per-repo coverage-honesty report. Lists first-class vs
# partial language coverage and emits a coverage_caveat block when the
# repo contains any partial-coverage language file.
set -uo pipefail
ROOT=""; DRY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) echo "Usage: analyze.sh --root <dir> [--dry-run]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$ROOT" || ! -d "$ROOT" ]] && { echo "analyze: --root <dir> required" >&2; exit 2; }

# First-class: javascript, typescript, python. Partial: go, ruby, rust.
LANGS=$(find "$ROOT" -type f -name "*.*" 2>/dev/null | sed -E 's|.*\.||' | sort -u)
PARTIAL=""
HAS_FIRST_CLASS=0
for ext in $LANGS; do
  case "$ext" in
    js|jsx|ts|tsx|py|mjs|cjs) HAS_FIRST_CLASS=1 ;;
    go) PARTIAL="${PARTIAL}${PARTIAL:+,}go" ;;
    rb) PARTIAL="${PARTIAL}${PARTIAL:+,}ruby" ;;
    rs) PARTIAL="${PARTIAL}${PARTIAL:+,}rust" ;;
  esac
done

echo "analyze: first_class=javascript,typescript,python root=$ROOT" >&2
if [[ -n "$PARTIAL" ]]; then
  echo "analyze: coverage_caveat: repo contains partial-coverage language(s)" >&2
  echo "analyze: partial=$PARTIAL root=$ROOT" >&2
  for lang in ${PARTIAL//,/ }; do
    echo "analyze: $lang: partial (rule scaffold ships; full coverage in roadmap)" >&2
  done
fi
[[ "$DRY" -eq 1 ]] && echo "analyze: dry_run=true" >&2
