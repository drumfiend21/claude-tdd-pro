#!/usr/bin/env bash
# rubric/detectors/adr-structure.sh - §2.2 detector for ADR structural conformance
# (v1.18 §28.20 "Fix F"). Enforces that an Architecture Decision Record carries the
# MADR-conformant sections (Status, Context, Decision, Consequences). Self-scopes to
# ADR files (basename `^[0-9]{4}-[a-z0-9-]+\.md$`, per §2.16) so an ordinary README is
# never flagged. This is the prose/Markdown half the cloud/code detectors could not
# reach; it flows through generated-code-quality-standards/ so a consumer can scope it.
#
# CLI: --paths <glob> [--json]
# stderr: per finding `adr-structure file=<f> missing=<csv>`; summary `adr-structure status=<green|red> adrs=<n> violations=<m>`
# Exit: 0 clean | 1 findings | 2 usage. (No ADR files matched -> exit 0, adrs=0.)

set -uo pipefail
PATHS=""; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --paths) PATHS="${2-}"; shift 2 ;;
    --json)  JSON=1; shift ;;
    -h|--help) echo "Usage: adr-structure.sh --paths <glob> [--json]" >&2; exit 0 ;;
    *) echo "adr-structure: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$PATHS" ] && { echo "adr-structure: --paths <glob> required" >&2; exit 2; }

adrs=0; violations=0
shopt -s nullglob globstar 2>/dev/null || true
for f in $PATHS; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  case "$base" in
    [0-9][0-9][0-9][0-9]-*.md) : ;;
    *) continue ;;
  esac
  adrs=$((adrs + 1))
  missing=""
  for section in Status Context Decision Consequences; do
    grep -qiE "(^#+[[:space:]]*|^[-*][[:space:]]+)?${section}" "$f" 2>/dev/null || missing="${missing:+$missing,}${section}"
  done
  if [ -n "$missing" ]; then
    violations=$((violations + 1))
    echo "adr-structure file=$f missing=$missing" >&2
    [ "$JSON" -eq 1 ] && printf '{"ruleId":"adr-structure","file":"%s","missing":"%s","severity":"error"}\n' "$f" "$missing"
  fi
done

if [ "$violations" -eq 0 ]; then
  echo "adr-structure status=green adrs=$adrs violations=0" >&2; exit 0
else
  echo "adr-structure status=red adrs=$adrs violations=$violations" >&2; exit 1
fi
