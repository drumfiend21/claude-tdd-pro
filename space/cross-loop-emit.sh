#!/usr/bin/env bash
# Q-7 cross-loop emitter: aggregates friction events and emits
# rubric-loop action cards per architecture section 16 Q-7.
set -uo pipefail
TARGET=""; THRESHOLD=5; SINCE="1d"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --threshold) THRESHOLD="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    -h|--help) echo "Usage: cross-loop-emit.sh --target <name> [--threshold <n>] [--since <window>]"; exit 0 ;;
    *) shift ;;
  esac
done

case "$TARGET" in
  rubric-action-cards)
    EVENTS=".claude-tdd-pro/friction/events.jsonl"
    OUT=".claude-tdd-pro/rubric-runs/action-cards.yaml"
    [[ ! -f "$EVENTS" ]] && { echo "cross-loop-emit: no events" >&2; exit 0; }
    THRESHOLD="$THRESHOLD" EVENTS="$EVENTS" OUT="$OUT" node -e '
      const fs = require("fs");
      const path = require("path");
      const lines = fs.readFileSync(process.env.EVENTS, "utf8").trim().split("\n").filter(Boolean);
      const counts = {};
      for (const l of lines) {
        try {
          const j = JSON.parse(l);
          if (j.event !== "inline-suppression" || !j.rule_id) continue;
          counts[j.rule_id] = (counts[j.rule_id] || 0) + 1;
        } catch {}
      }
      const t = parseInt(process.env.THRESHOLD, 10);
      const cards = [];
      for (const [rule_id, n] of Object.entries(counts)) {
        if (n < t) continue;
        cards.push(`- rule_id: ${rule_id}\n  suppression_count: ${n}\n  source_loop: friction-tracker\n  recommendation: review whether ${rule_id} should be relaxed or refined`);
      }
      fs.mkdirSync(path.dirname(process.env.OUT), { recursive: true });
      fs.writeFileSync(process.env.OUT, cards.join("\n") + "\n");
      process.stderr.write(`cross-loop-emit: wrote ${cards.length} action card(s) to ${process.env.OUT}\n`);
    '
    ;;
  *)
    echo "cross-loop-emit: unknown target $TARGET (valid: rubric-action-cards)" >&2
    exit 2
    ;;
esac
