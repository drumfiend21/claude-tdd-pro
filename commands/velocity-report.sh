#!/usr/bin/env bash
# Q-10 velocity-uplift report per §26 v1.11.
#
# Reads the Q-12 agent-invocations log and reports per-skill (or
# per-prompt-id) cycle-time deltas vs. a baseline window. Surfaces
# the "leadership-reportable" productivity narrative (e.g., the
# Wayfair-style "~65% uplift" figure operators need.)
#
# Cycle-time = average latency_ms per invocation.
# Delta     = (recent_avg - baseline_avg) / baseline_avg
# Negative delta = uplift (faster); positive delta = regression.
#
# Privacy: --export requires the same Q-6 redaction filter as
# /space-export (not enforced here; downstream).
#
# Usage:
#   velocity-report.sh [--by <skill|prompt_id>] [--baseline-days <N>]
#                       [--recent-days <N>] [--now <iso>]
#                       [--format text|json] [--log <path>]
#                       [--export] [--dry-run]
set -uo pipefail

BY="prompt_id"
BASELINE_DAYS=30
RECENT_DAYS=7
NOW_ISO=""
FORMAT="text"
LOG="${Q12_LOG_PATH:-.claude-tdd-pro/agent-invocations.jsonl}"
EXPORT=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --by) BY="$2"; shift 2 ;;
    --baseline-days) BASELINE_DAYS="$2"; shift 2 ;;
    --recent-days) RECENT_DAYS="$2"; shift 2 ;;
    --now) NOW_ISO="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --log) LOG="$2"; shift 2 ;;
    --export) EXPORT=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      echo "Usage: velocity-report.sh [--by <skill|prompt_id>] [--baseline-days <N>] [--recent-days <N>] [--now <iso>] [--format text|json] [--log <path>] [--export] [--dry-run]" >&2
      exit 0
      ;;
    *) echo "velocity-report: unknown arg: $1" >&2; exit 2 ;;
  esac
done

case "$BY" in skill|prompt_id|subagent_id) ;; *) echo "velocity-report: --by must be skill|prompt_id|subagent_id" >&2; exit 2 ;; esac
case "$FORMAT" in text|json) ;; *) echo "velocity-report: --format must be text|json" >&2; exit 2 ;; esac

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "velocity-report: dry_run=true by=$BY baseline_days=$BASELINE_DAYS recent_days=$RECENT_DAYS" >&2
  exit 0
fi

[[ ! -f "$LOG" ]] && { echo "velocity-report: no log at $LOG (run agents first)" >&2; exit 0; }
[[ -z "$NOW_ISO" ]] && NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)

LOG="$LOG" BY="$BY" BASELINE_DAYS="$BASELINE_DAYS" RECENT_DAYS="$RECENT_DAYS" \
NOW_ISO="$NOW_ISO" FORMAT="$FORMAT" EXPORT="$EXPORT" node -e '
  const fs = require("fs");
  const dim = process.env.BY === "skill" ? "subagent_id" : process.env.BY;
  const now = new Date(process.env.NOW_ISO).getTime();
  const recentMs = parseInt(process.env.RECENT_DAYS, 10) * 86400e3;
  const baselineMs = parseInt(process.env.BASELINE_DAYS, 10) * 86400e3;
  const recentStart = now - recentMs;
  const baselineStart = now - baselineMs;
  const baselineEnd = recentStart;

  const groups = {};
  for (const l of fs.readFileSync(process.env.LOG, "utf8").split("\n").filter(Boolean)) {
    const e = JSON.parse(l);
    const t = new Date(e.ts).getTime();
    const k = e[dim] || "unknown";
    groups[k] = groups[k] || { recent: [], baseline: [] };
    if (t >= recentStart) groups[k].recent.push(e.latency_ms || 0);
    else if (t >= baselineStart && t < baselineEnd) groups[k].baseline.push(e.latency_ms || 0);
  }

  const rows = [];
  for (const [k, v] of Object.entries(groups)) {
    if (v.recent.length === 0 || v.baseline.length === 0) continue;
    const rAvg = v.recent.reduce((a,b)=>a+b,0) / v.recent.length;
    const bAvg = v.baseline.reduce((a,b)=>a+b,0) / v.baseline.length;
    const delta = (rAvg - bAvg) / bAvg;
    rows.push({ key: k, baseline_avg_ms: Math.round(bAvg), recent_avg_ms: Math.round(rAvg), delta_pct: Math.round(delta * 1000) / 10, uplift_pct: -Math.round(delta * 1000) / 10 });
  }
  rows.sort((a, b) => a.delta_pct - b.delta_pct);

  if (process.env.FORMAT === "json") {
    const out = {
      generated_at: process.env.NOW_ISO,
      by: process.env.BY,
      baseline_days: parseInt(process.env.BASELINE_DAYS, 10),
      recent_days: parseInt(process.env.RECENT_DAYS, 10),
      rows
    };
    process.stdout.write(JSON.stringify(out));
  } else {
    process.stderr.write(`velocity-report: by=${process.env.BY} baseline=${process.env.BASELINE_DAYS}d recent=${process.env.RECENT_DAYS}d\n`);
    for (const r of rows) {
      const tag = r.uplift_pct >= 5 ? "[UPLIFT]" : r.uplift_pct <= -5 ? "[REGRESSION]" : "[NEUTRAL]";
      process.stderr.write(`  ${tag} ${r.key} baseline_avg_ms=${r.baseline_avg_ms} recent_avg_ms=${r.recent_avg_ms} uplift_pct=${r.uplift_pct}\n`);
    }
    if (rows.length === 0) {
      process.stderr.write(`  (no key has both baseline and recent windows populated; need ${process.env.BASELINE_DAYS}-day + ${process.env.RECENT_DAYS}-day coverage)\n`);
    }
  }

  if (process.env.EXPORT === "1") {
    process.stderr.write(`velocity-report: export=true (downstream must apply Q-6 redaction filter before sharing)\n`);
  }
'
