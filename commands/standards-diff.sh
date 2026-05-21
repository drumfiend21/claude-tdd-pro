#!/usr/bin/env bash
# S-5 /standards-diff per §16: Adopt/Defer/Reject decisions in
# standards/decisions.jsonl. Inputs: --current + --upstream snapshots.
# Output: textual diff + optional decision record appended to decisions.jsonl.
set -uo pipefail
SOURCE=""; CURRENT=""; UPSTREAM=""; DECIDE=""; CHANGE=""; DECISIONS=""
DRY=0; NOW=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --current) CURRENT="$2"; shift 2 ;;
    --upstream) UPSTREAM="$2"; shift 2 ;;
    --decide) DECIDE="$2"; shift 2 ;;
    --change) CHANGE="$2"; shift 2 ;;
    --decisions) DECISIONS="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --now) NOW="$2"; shift 2 ;;
    -h|--help) echo "Usage: standards-diff.sh --source <id> --current <yaml> --upstream <yaml> [--decide adopt|defer|reject --change <id> --decisions <jsonl>] [--dry-run] [--now <iso>]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$SOURCE" || -z "$CURRENT" || -z "$UPSTREAM" ]] && { echo "standards-diff: --source --current --upstream required" >&2; exit 2; }
[[ ! -f "$CURRENT" || ! -f "$UPSTREAM" ]] && { echo "standards-diff: snapshot files not found" >&2; exit 2; }
[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Decision-value validation (enforced before any other path).
if [[ -n "$DECIDE" ]]; then
  case "$DECIDE" in
    adopt|defer|reject) : ;;
    *) echo "standards-diff: invalid_decision $DECIDE allowed=adopt|defer|reject" >&2; exit 2 ;;
  esac
fi

# Compute diff.
ADDED=$(comm -13 <(sort "$CURRENT") <(sort "$UPSTREAM") | sed -E 's/:.*//' | grep -v '^$')
REMOVED=$(comm -23 <(sort "$CURRENT") <(sort "$UPSTREAM") | sed -E 's/:.*//' | grep -v '^$')

if [[ -z "$ADDED" && -z "$REMOVED" ]]; then
  echo "standards-diff: no_changes source=$SOURCE (current and upstream snapshots are identical)" >&2
  exit 0
fi

for r in $ADDED; do echo "standards-diff: added: $r source=$SOURCE" >&2; done
for r in $REMOVED; do echo "standards-diff: removed: $r source=$SOURCE" >&2; done

# Decision record.
if [[ -n "$DECIDE" && -n "$CHANGE" ]]; then
  if [[ "$DRY" -eq 1 ]]; then
    echo "standards-diff: planned: $DECIDE $CHANGE source=$SOURCE dry_run=true (no write)" >&2
    exit 0
  fi
  [[ -z "$DECISIONS" ]] && { echo "standards-diff: --decisions <jsonl> required for decision record" >&2; exit 2; }
  mkdir -p "$(dirname "$DECISIONS")"
  printf '{"decision":"%s","change":"%s","source":"%s","timestamp":"%s"}\n' "$DECIDE" "$CHANGE" "$SOURCE" "$NOW" >> "$DECISIONS"
  echo "standards-diff: recorded $DECIDE change=$CHANGE source=$SOURCE at=$NOW decisions=$DECISIONS" >&2
fi
