#!/usr/bin/env bash
# X-4 cost-report — reads .claude-tdd-pro/local-llm/stats.json and emits a
# reduction percentage + target-band tag plus aggregate tokens_avoided.
set -uo pipefail
STATS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stats) STATS="$2"; shift 2 ;;
    -h|--help) echo "Usage: cost-report.sh --stats <json>"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$STATS" || ! -f "$STATS" ]] && { echo "local-llm-cost-report: --stats <json> required" >&2; exit 2; }

STATS="$STATS" node -e '
const j = JSON.parse(require("fs").readFileSync(process.env.STATS, "utf8"));
let avoided = 0;
if (Array.isArray(j.routed_operations)) {
  for (const r of j.routed_operations) avoided += (r.tokens_avoided || 0);
} else if (typeof j.avoided_daily_tokens === "number") {
  avoided = j.avoided_daily_tokens;
}
let pct = null;
if (typeof j.baseline_daily_tokens === "number" && j.baseline_daily_tokens > 0) {
  pct = Math.round(100 * (j.avoided_daily_tokens || avoided) / j.baseline_daily_tokens);
}
let line = `local-llm-cost-report: tokens_avoided=${avoided}`;
if (pct !== null) {
  line += ` reduction_pct=${pct} target_band=30-50`;
  if (pct >= 30 && pct <= 50) line += " in_band=true";
  else line += " in_band=false";
}
process.stderr.write(line + "\n");
'
