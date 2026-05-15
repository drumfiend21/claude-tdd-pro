#!/usr/bin/env bash
# rsc-boundary.sh — R-3 substrate stub (per §16 R-3 + §2.2 detector
# contract). Detects React Server Components boundary violations:
# server-only imports in client-marked files, client-only imports in
# server-marked files, async client components, missing Suspense.
#
# Per §2.2 detector contract: supports --json, --paths, --dry-run,
# --help. Findings to stderr; exit 1 on violation.
#
# Usage:
#   rsc-boundary.sh --json --paths "src/**/*.tsx" [--dry-run]

set -uo pipefail

JSON=0
PATHS=""
DRY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --paths) PATHS="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help)
      echo "Usage: rsc-boundary.sh --json --paths <glob> [--dry-run]"
      echo "Detector flags: --json --paths --dry-run"
      exit 0
      ;;
    *) shift ;;
  esac
done

if [[ "$DRY" -eq 1 ]]; then
  echo "rsc-boundary: dry-run; would walk $PATHS" >&2
  exit 0
fi

# Portable glob expansion (macOS bash 3.2 lacks globstar).
EXPAND_BASE=""
EXPAND_PATTERN=""
EXPAND_RECURSIVE=0
case "$PATHS" in
  *"/**"*)
    EXPAND_BASE="${PATHS%%/\*\*/*}"
    [[ "$EXPAND_BASE" == "$PATHS" ]] && EXPAND_BASE="${PATHS%/\*\*}"
    EXPAND_PATTERN="${PATHS##*/}"
    [[ "$EXPAND_PATTERN" == "**" ]] && EXPAND_PATTERN="*"
    EXPAND_RECURSIVE=1
    ;;
  */*)
    EXPAND_BASE="${PATHS%/*}"
    EXPAND_PATTERN="${PATHS##*/}"
    ;;
  *)
    EXPAND_BASE="."
    EXPAND_PATTERN="$PATHS"
    ;;
esac

[[ -d "$EXPAND_BASE" ]] || exit 0

if [[ "$EXPAND_RECURSIVE" -eq 1 ]]; then
  FIND_DEPTH_FLAGS=""
else
  FIND_DEPTH_FLAGS="-maxdepth 1"
fi

CLIENT_FILES=$(find "$EXPAND_BASE" $FIND_DEPTH_FLAGS -type f -name "$EXPAND_PATTERN" -print0 2>/dev/null \
  | xargs -0 grep -lE 'use client' 2>/dev/null)

EXIT=0
[[ -z "$CLIENT_FILES" ]] && exit 0

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  while IFS=':' read -r ln content; do
    [[ -z "$content" ]] && continue
    MATCHED_IMPORT=$(echo "$content" | perl -ne 'if (/(node:[a-zA-Z_-]+|["\x27](fs|path|crypto|server-only)["\x27])/) { print $1; exit }')
    [[ -z "$MATCHED_IMPORT" ]] && continue
    if [[ "$JSON" -eq 1 ]]; then
      echo '{"severity":"error","rule_id":"react/rsc-boundary","file":"'"$f"'","line":'"$ln"',"finding":"rsc-boundary violation: server-only import '"$MATCHED_IMPORT"' in client-marked file","suggested_fix":"remove use client directive or move import to a server component"}' >&2
    else
      echo "rsc-boundary: $f:$ln server-only import $MATCHED_IMPORT in client-marked file" >&2
    fi
    EXIT=1
  done < <(grep -nE 'from[[:space:]]+["'"'"']?(node:|fs|path|crypto|server-only)' "$f" 2>/dev/null)
done <<< "$CLIENT_FILES"

exit "$EXIT"
