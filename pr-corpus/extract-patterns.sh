#!/usr/bin/env bash
# L-4 pattern extractor invoker (substrate stub; production calls
# the pr-pattern-extractor subagent via agents/_runner.sh).
set -uo pipefail
PR=""; OUT=""; DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr) PR="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) echo "Usage: extract-patterns.sh --pr <json> --out <json> [--dry-run]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$PR" || ! -f "$PR" ]] && { echo "extract-patterns: --pr required" >&2; exit 2; }
[[ -z "$OUT" ]] && { echo "extract-patterns: --out required" >&2; exit 2; }

PR="$PR" OUT="$OUT" DRY_RUN="$DRY_RUN" node -e '
const fs = require("fs");
const pr = JSON.parse(fs.readFileSync(process.env.PR, "utf8"));
const dry = process.env.DRY_RUN === "1";
const comments = pr.comments || [];
// Stub extraction: surface one pattern per non-trivial comment.
const patterns = [];
for (let i = 0; i < comments.length; i++) {
  const body = comments[i].body || "";
  if (body.length < 10) continue;
  patterns.push({
    id: `p-${pr.number}-${i + 1}`,
    pr_number: pr.number,
    category: "other",
    verbatim_quote: body,
    rationale: "stub: derived from review comment",
    usefulness_estimate: 3,
    evidence: { comment_index: i },
  });
}
fs.writeFileSync(process.env.OUT, JSON.stringify(patterns));
process.stderr.write(`extract-patterns: pr=${pr.number} patterns=${patterns.length} dry_run=${dry}\n`);
'
