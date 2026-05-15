#!/usr/bin/env bash
# L-3 triage filter: ≥2 substantive comments; reviewer requested changes
# OR iterative push; merged; not bot/docs.
set -uo pipefail
PR_FILES=()
OUT=""
CLASSIFY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr) PR_FILES+=("$2"); shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --classify-comments) CLASSIFY=1; shift ;;
    -h|--help) echo "Usage: triage.sh --pr <json> [--pr <json>...] [--out <jsonl>] [--classify-comments]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ ${#PR_FILES[@]} -eq 0 ]] && { echo "triage: --pr <file> required" >&2; exit 2; }

for pr in "${PR_FILES[@]}"; do
  PR="$pr" CLASSIFY="$CLASSIFY" OUT="$OUT" node -e '
    const fs = require("fs");
    const j = JSON.parse(fs.readFileSync(process.env.PR, "utf8"));
    let substantive = j.substantive_comments != null ? j.substantive_comments : 0;
    if (process.env.CLASSIFY === "1" && Array.isArray(j.comments)) {
      const boilerplate = /^\s*(LGTM|\+1|thanks|nice|cool|👍|🚀)\s*$/i;
      substantive = j.comments.filter(c => !boilerplate.test(c.body || "")).length;
    }
    let decision = "accept", reason = "", signals = [];
    if (j.merged === false || j.state === "closed") {
      decision = "reject"; reason = "not-merged";
    } else if (j.author_type === "Bot") {
      decision = "reject"; reason = "bot-author";
    } else if (j.docs_only === true) {
      decision = "reject"; reason = "docs-only";
    } else if (substantive < 2) {
      decision = "reject"; reason = "insufficient-comments";
    } else {
      if (j.reviewer_requested_changes === true) signals.push("reviewer-requested-changes");
      if ((j.iterative_pushes || 0) > 0) signals.push("iterative-pushes");
      if (signals.length === 0) signals.push("substantive-comments");
    }
    process.stderr.write(`triage: number=${j.number} decision=${decision} reason=${reason} signals=${signals.join(",")} substantive_comments=${substantive}\n`);
    if (process.env.OUT) {
      fs.appendFileSync(process.env.OUT, JSON.stringify({number: j.number, decision, reason, signals, substantive_comments: substantive}) + "\n");
    }
  '
done
