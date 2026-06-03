#!/usr/bin/env bash
# L-5 classification → action router.
# Reads a decision JSON ({pattern_id, matched_rule_id, classification})
# and routes to the appropriate downstream action per §12 L-5 5-label
# vocabulary. Conflict-surfacing log is the human-resolution channel.
set -uo pipefail

DECISION=""
LOG=""
DECISIONS_LOG=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --decision) DECISION="$2"; shift 2 ;;
    --log) LOG="$2"; shift 2 ;;
    --decisions-log) DECISIONS_LOG="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      echo "Usage: apply-classification.sh --decision <json> [--log <jsonl>] [--decisions-log <jsonl>] [--dry-run]" >&2
      exit 0
      ;;
    *) shift ;;
  esac
done

[[ -z "$DECISION" || ! -f "$DECISION" ]] && { echo "apply-classification: --decision <json> required" >&2; exit 2; }

DECISION="$DECISION" node -e '
const fs = require("fs");
const d = JSON.parse(fs.readFileSync(process.env.DECISION, "utf8"));
const label = d.classification || "";
const out = { label, pattern_id: d.pattern_id || null, matched_rule_id: d.matched_rule_id || null };
process.stdout.write(JSON.stringify(out));
' > /tmp/.l5-decision.$$

LABEL=$(node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync("/tmp/.l5-decision.'"$$"'","utf8")).label)')
PATTERN_ID=$(node -e 'process.stdout.write(String(JSON.parse(require("fs").readFileSync("/tmp/.l5-decision.'"$$"'","utf8")).pattern_id))')
MATCHED_RULE_ID=$(node -e 'process.stdout.write(String(JSON.parse(require("fs").readFileSync("/tmp/.l5-decision.'"$$"'","utf8")).matched_rule_id))')

rm -f /tmp/.l5-decision.$$

case "$LABEL" in
  same)
    echo "apply-classification: action=skip-promotion matched_rule_id=$MATCHED_RULE_ID pattern_id=$PATTERN_ID" >&2
    ;;
  refinement)
    echo "apply-classification: action=update-existing rule_id=$MATCHED_RULE_ID pattern_id=$PATTERN_ID" >&2
    ;;
  adjacent)
    echo "apply-classification: action=log-only auto_promote=false pattern_id=$PATTERN_ID" >&2
    if [[ -n "$LOG" ]]; then
      mkdir -p "$(dirname "$LOG")"
      cat "$DECISION" >> "$LOG"
    fi
    ;;
  novel)
    echo "apply-classification: action=pending-rule awaiting=evidence pattern_id=$PATTERN_ID" >&2
    ;;
  conflict)
    echo "apply-classification: action=conflict-surfaced pattern_id=$PATTERN_ID" >&2
    if [[ -n "$DECISIONS_LOG" ]]; then
      mkdir -p "$(dirname "$DECISIONS_LOG")"
      cat "$DECISION" >> "$DECISIONS_LOG"
    fi
    ;;
  *)
    echo "apply-classification: unknown_label=$LABEL (expected one of same|refinement|adjacent|novel|conflict)" >&2
    exit 2
    ;;
esac
