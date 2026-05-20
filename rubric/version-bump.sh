#!/usr/bin/env bash
# O-10 rubric semver bumper. --change breaking-detector-contract bumps major;
# feature bumps minor; bugfix bumps patch. --apply writes back to RUBRIC.yaml
# and appends a changelog entry.
set -uo pipefail
RUBRIC=""; CHANGE=""; APPLY=0; DRY=0; CHANGELOG=""; NOW=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --rubric) RUBRIC="$2"; shift 2 ;;
    --change) CHANGE="$2"; shift 2 ;;
    --apply) APPLY=1; shift ;;
    --dry-run) DRY=1; shift ;;
    --changelog) CHANGELOG="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    -h|--help) echo "Usage: version-bump.sh --rubric <yaml> --change breaking-detector-contract|feature|bugfix [--apply | --dry-run] [--changelog <md>] [--now <iso>]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$RUBRIC" || ! -f "$RUBRIC" ]] && { echo "version-bump: --rubric <yaml> required" >&2; exit 2; }
[[ -z "$CHANGE" ]] && { echo "version-bump: --change required" >&2; exit 2; }
[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

CURRENT=$(grep -E '^version:' "$RUBRIC" | head -1 | sed -E 's/version:[[:space:]]*//' | tr -d ' "')
IFS='.' read -r MAJ MIN PAT <<< "$CURRENT"
case "$CHANGE" in
  breaking-detector-contract) MAJ=$((MAJ + 1)); MIN=0; PAT=0 ;;
  feature) MIN=$((MIN + 1)); PAT=0 ;;
  bugfix) PAT=$((PAT + 1)) ;;
  *) echo "version-bump: unknown --change $CHANGE (expected: breaking-detector-contract | feature | bugfix)" >&2; exit 2 ;;
esac
NEXT="$MAJ.$MIN.$PAT"

if [[ "$DRY" -eq 1 || "$APPLY" -ne 1 ]]; then
  echo "version-bump: planned: $CURRENT -> $NEXT change=$CHANGE rubric=$RUBRIC dry_run=true" >&2
  exit 0
fi

# Apply: rewrite RUBRIC.yaml version line, append changelog entry.
sed -i.bak -E "s/^version:[[:space:]]*${CURRENT}/version: ${NEXT}/" "$RUBRIC"
rm -f "$RUBRIC.bak"
if [[ -n "$CHANGELOG" ]]; then
  {
    echo ""
    echo "## $NEXT — $NOW"
    echo ""
    echo "- $CHANGE bump from $CURRENT to $NEXT."
  } >> "$CHANGELOG"
fi
echo "version-bump: applied $CURRENT -> $NEXT change=$CHANGE rubric=$RUBRIC changelog=${CHANGELOG:-(none)}" >&2
