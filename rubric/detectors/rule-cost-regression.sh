#!/usr/bin/env bash
# H-12 rule-cost regression detector.
#
# Flags rules whose tokens-per-check exceeds 2x their 30-day median.
# Severity: warn per §11 H-12. Reads a per-rule cost history file
# (jsonl, one entry per check) and the candidate current value.
#
# Usage:
#   rule-cost-regression.sh --rule <id> --history <jsonl> --current <int>
#
# Exit codes:
#   0  within threshold (no regression)
#   1  regression detected (tokens_per_check > 2x median)
#   2  usage error
set -uo pipefail

RULE=""
HISTORY=""
CURRENT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rule) RULE="$2"; shift 2 ;;
    --history) HISTORY="$2"; shift 2 ;;
    --current) CURRENT="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: rule-cost-regression.sh --rule <id> --history <jsonl> --current <int>" >&2
      exit 0
      ;;
    *) echo "rule-cost-regression: unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$RULE" ]] && { echo "rule-cost-regression: --rule required" >&2; exit 2; }
[[ -z "$HISTORY" || ! -f "$HISTORY" ]] && { echo "rule-cost-regression: --history file required" >&2; exit 2; }
[[ -z "$CURRENT" ]] && { echo "rule-cost-regression: --current <int> required" >&2; exit 2; }

RULE="$RULE" HISTORY="$HISTORY" CURRENT="$CURRENT" node -e '
  const fs = require("fs");
  const cur = parseInt(process.env.CURRENT, 10);
  const lines = fs.readFileSync(process.env.HISTORY, "utf8").split("\n").filter(Boolean);
  const samples = lines.map(l => JSON.parse(l))
    .filter(e => e.rule === process.env.RULE)
    .map(e => e.tokens_per_check)
    .filter(n => typeof n === "number")
    .sort((a, b) => a - b);
  if (samples.length === 0) {
    process.stderr.write(`rule-cost-regression: no history for rule=${process.env.RULE}; passing\n`);
    process.exit(0);
  }
  const median = samples[Math.floor(samples.length / 2)];
  const threshold = median * 2;
  if (cur > threshold) {
    process.stderr.write(`rule-cost-regression: severity=warn rule=${process.env.RULE} current=${cur} median=${median} threshold=${threshold}\n`);
    process.exit(1);
  }
  process.stderr.write(`rule-cost-regression: rule=${process.env.RULE} current=${cur} median=${median} within_threshold=true\n`);
  process.exit(0);
'
