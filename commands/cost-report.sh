#!/usr/bin/env bash
# H-12 continuous cost telemetry rollup -- /cost-report drill-down command.
#
# Reads cost-rollup/{daily,weekly}/*.json and emits per-dimension reports
# (skill | subagent | rule | profile | model). Aggregates the H-1 per-call
# telemetry written by the underlying skill/subagent/rule invocations.
#
# Usage:
#   cost-report.sh [--window=<daily|weekly>] [--by=<dimension>]
#                  [--format=<text|json|tui>]
#                  [--rollup-dir=<path>]
#
# Exit codes:
#   0  report emitted
#   2  usage error
set -uo pipefail

WINDOW="daily"
BY="skill"
FORMAT="text"
ROLLUP_DIR="${CLAUDE_PLUGIN_ROOT:-.}/cost-rollup"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --window=*) WINDOW="${1#--window=}"; shift ;;
    --window) WINDOW="$2"; shift 2 ;;
    --by=*) BY="${1#--by=}"; shift ;;
    --by) BY="$2"; shift 2 ;;
    --format=*) FORMAT="${1#--format=}"; shift ;;
    --format) FORMAT="$2"; shift 2 ;;
    --rollup-dir=*) ROLLUP_DIR="${1#--rollup-dir=}"; shift ;;
    --rollup-dir) ROLLUP_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: cost-report.sh [--window=<daily|weekly>] [--by=<skill|subagent|rule|profile|model>] [--format=<text|json|tui>] [--rollup-dir=<path>]" >&2
      exit 0
      ;;
    *) echo "cost-report: unknown arg: $1" >&2; exit 2 ;;
  esac
done

case "$WINDOW" in daily|weekly) ;; *) echo "cost-report: invalid --window: $WINDOW" >&2; exit 2 ;; esac
case "$BY" in skill|subagent|rule|profile|model) ;; *) echo "cost-report: invalid --by: $BY" >&2; exit 2 ;; esac
case "$FORMAT" in text|json|tui) ;; *) echo "cost-report: invalid --format: $FORMAT" >&2; exit 2 ;; esac

WINDOW_DIR="$ROLLUP_DIR/$WINDOW"
[[ ! -d "$WINDOW_DIR" ]] && { echo "cost-report: rollup window dir not found: $WINDOW_DIR" >&2; exit 2; }

WINDOW_DIR="$WINDOW_DIR" BY="$BY" FORMAT="$FORMAT" WINDOW="$WINDOW" node -e '
  const fs = require("fs");
  const path = require("path");
  const dim = process.env.BY;
  const fmt = process.env.FORMAT;
  const wdir = process.env.WINDOW_DIR;
  const totals = {};
  for (const f of fs.readdirSync(wdir).filter(n => n.endsWith(".json")).sort()) {
    const doc = JSON.parse(fs.readFileSync(path.join(wdir, f), "utf8"));
    for (const e of (doc.entries || [])) {
      const k = e[dim] || "unknown";
      totals[k] = totals[k] || { tokens_in: 0, tokens_out: 0, invocations: 0 };
      totals[k].tokens_in += (e.tokens_in || 0);
      totals[k].tokens_out += (e.tokens_out || 0);
      totals[k].invocations += (e.invocations || 1);
    }
  }
  if (fmt === "json") {
    process.stdout.write(JSON.stringify({ window: process.env.WINDOW, by: dim, totals }));
  } else if (fmt === "tui") {
    process.stderr.write(`cost-report tui window=${process.env.WINDOW} by=${dim}\n`);
    for (const [k, v] of Object.entries(totals)) {
      process.stderr.write(`  [${k}] tokens_in=${v.tokens_in} tokens_out=${v.tokens_out} invocations=${v.invocations}\n`);
    }
  } else {
    process.stderr.write(`cost-report: window=${process.env.WINDOW} by=${dim}\n`);
    for (const [k, v] of Object.entries(totals)) {
      process.stderr.write(`${k}: tokens_in=${v.tokens_in} tokens_out=${v.tokens_out} invocations=${v.invocations}\n`);
    }
  }
'
exit 0
