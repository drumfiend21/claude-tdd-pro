#!/usr/bin/env bash
# f2-bootstrap-from-seed — F-2 cold-start helper that copies seed FP examples
# (O-1 seed corpus) into the actual rubric/fp-log/<rule-id>.jsonl path so a
# new install has a non-empty FP log to reference until real production data
# accrues.
#
# Per O-1 architecture: "30 pre-graded FP examples per existing rule"
# Per F-2 architecture: per-rule FP log lives at rubric/fp-log/<rule-id>.jsonl
#
# Usage:
#   bash f2-bootstrap-from-seed.sh --rule <rule-id>

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
RULE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rule) RULE="$2"; shift 2 ;;
    *) echo "f2-bootstrap-from-seed: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$RULE" ]] && { echo "f2-bootstrap-from-seed: --rule <rule-id> required" >&2; exit 2; }

SEED="$PLUGIN_ROOT/seed/fp-examples/$RULE/examples.jsonl"
DEST_DIR="$PWD/rubric/fp-log"
DEST="$DEST_DIR/$RULE.jsonl"

[[ ! -f "$SEED" ]] && { echo "f2-bootstrap-from-seed: no seed FP examples for rule $RULE at $SEED" >&2; exit 1; }

mkdir -p "$DEST_DIR"
cp "$SEED" "$DEST"
echo "f2-bootstrap-from-seed: bootstrapped $(wc -l < "$DEST" | tr -d ' ') FP records into $DEST" >&2
exit 0
