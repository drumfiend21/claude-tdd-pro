#!/usr/bin/env bash
# rubric/detectors/doc-citation-presence.sh - §2.2 detector for citation presence in
# decision records (v1.18 §28.20 "Fix F"). Enforces the cite-or-decline discipline on
# PROSE: an Architecture Decision Record must reference at least one grounding source
# (a `source`/`grounding` citation or a link), not assert an unsourced decision.
# Self-scopes to ADR files (basename `^[0-9]{4}-[a-z0-9-]+\.md$`). Substance ("did not
# invent the architecture") stays a decision-level cross-check; this is the mechanical
# floor: every ADR cites something.
#
# CLI: --paths <glob> [--json]
# stderr: per finding `doc-citation file=<f> citations=0`; summary `doc-citation status=<green|red> adrs=<n> uncited=<m>`
# Exit: 0 clean | 1 findings | 2 usage.

set -uo pipefail
PATHS=""; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --paths) PATHS="${2-}"; shift 2 ;;
    --json)  JSON=1; shift ;;
    -h|--help) echo "Usage: doc-citation-presence.sh --paths <glob> [--json]" >&2; exit 0 ;;
    *) echo "doc-citation-presence: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$PATHS" ] && { echo "doc-citation-presence: --paths <glob> required" >&2; exit 2; }

adrs=0; uncited=0
shopt -s nullglob globstar 2>/dev/null || true
for f in $PATHS; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  case "$base" in
    [0-9][0-9][0-9][0-9]-*.md) : ;;
    *) continue ;;
  esac
  adrs=$((adrs + 1))
  # a citation = a grounding/source reference or a markdown link
  if ! grep -qiE 'grounding|source[s]?[:_ ]|\]\(http|\bcite' "$f" 2>/dev/null; then
    uncited=$((uncited + 1))
    echo "doc-citation file=$f citations=0" >&2
    [ "$JSON" -eq 1 ] && printf '{"ruleId":"doc-citation-presence","file":"%s","citations":0,"severity":"error"}\n' "$f"
  fi
done

if [ "$uncited" -eq 0 ]; then
  echo "doc-citation status=green adrs=$adrs uncited=0" >&2; exit 0
else
  echo "doc-citation status=red adrs=$adrs uncited=$uncited" >&2; exit 1
fi
