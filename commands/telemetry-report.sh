#!/usr/bin/env bash
# Production telemetry reader / report.
#
# Reads ~/.claude-tdd-pro/telemetry.jsonl and reports operational
# statistics: uptime, event counts by type, error rate, p50/p95
# latencies. This is the "production observability" surface the
# Musk-team review demanded.
#
# Usage:
#   commands/telemetry-report.sh [--since <iso-or-relative>]
#                                [--event <name>]
#                                [--format json|text]

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
LOG_DIR="${TELEMETRY_LOG_DIR:-$HOME/.claude-tdd-pro}"
LOG_FILE="$LOG_DIR/telemetry.jsonl"

SINCE=""
EVENT=""
FORMAT="text"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) SINCE="$2"; shift 2 ;;
    --event) EVENT="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: telemetry-report.sh [--since <iso>] [--event <name>] [--format json|text]" >&2
      exit 0 ;;
    *) echo "telemetry-report: unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ ! -f "$LOG_FILE" ]] && {
  echo "No telemetry yet. Run an instrumented operation (suite, install, fitness gate) first." >&2
  echo "Log file path: $LOG_FILE" >&2
  exit 0
}

LOG_FILE="$LOG_FILE" SINCE="$SINCE" EVENT="$EVENT" FORMAT="$FORMAT" node -e '
  const fs = require("fs");
  const file = process.env.LOG_FILE;
  const since = process.env.SINCE;
  const event = process.env.EVENT;
  const format = process.env.FORMAT || "text";

  const lines = fs.readFileSync(file, "utf8").split("\n").filter(Boolean);
  const events = [];
  for (const line of lines) {
    try {
      const ev = JSON.parse(line);
      if (since && ev.ts < since) continue;
      if (event && ev.event !== event) continue;
      events.push(ev);
    } catch {}
  }

  // Aggregate.
  const stats = {
    total_events: events.length,
    by_event: {},
    by_severity: { info: 0, warn: 0, error: 0 },
    error_rate: 0,
    first_ts: events[0]?.ts || null,
    last_ts: events[events.length - 1]?.ts || null,
    sessions: new Set(),
    versions: new Set(),
  };
  for (const e of events) {
    stats.by_event[e.event] = (stats.by_event[e.event] || 0) + 1;
    stats.by_severity[e.severity || "info"] = (stats.by_severity[e.severity || "info"] || 0) + 1;
    if (e.session) stats.sessions.add(e.session);
    if (e.version) stats.versions.add(e.version);
  }
  stats.sessions = stats.sessions.size;
  stats.versions = [...stats.versions];
  stats.error_rate = events.length > 0
    ? (stats.by_severity.error / events.length).toFixed(3)
    : "0.000";

  // Latency stats for events that carry elapsed_s field.
  const latencies = events
    .filter(e => e.fields?.elapsed_s != null)
    .map(e => parseFloat(e.fields.elapsed_s))
    .filter(n => !isNaN(n))
    .sort((a, b) => a - b);
  if (latencies.length > 0) {
    stats.latency_p50_s = latencies[Math.floor(latencies.length * 0.5)];
    stats.latency_p95_s = latencies[Math.floor(latencies.length * 0.95)];
    stats.latency_max_s = latencies[latencies.length - 1];
  }

  if (format === "json") {
    process.stdout.write(JSON.stringify(stats, null, 2) + "\n");
    process.exit(0);
  }
  console.log("=== Production telemetry report ===");
  console.log(`Window:        ${stats.first_ts} → ${stats.last_ts}`);
  console.log(`Total events:  ${stats.total_events}`);
  console.log(`Sessions:      ${stats.sessions}`);
  console.log(`Versions seen: ${stats.versions.join(", ") || "none"}`);
  console.log(`Error rate:    ${stats.error_rate} (${stats.by_severity.error} of ${stats.total_events})`);
  if (stats.latency_p50_s != null) {
    console.log(`Latency p50:   ${stats.latency_p50_s}s`);
    console.log(`Latency p95:   ${stats.latency_p95_s}s`);
    console.log(`Latency max:   ${stats.latency_max_s}s`);
  }
  console.log("");
  console.log("Events by type:");
  for (const [k, v] of Object.entries(stats.by_event).sort((a, b) => b[1] - a[1])) {
    console.log(`  ${k.padEnd(30)} ${v}`);
  }
'
