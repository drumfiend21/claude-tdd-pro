#!/usr/bin/env bash
# standards/freshness-gate.sh — S-13 daily-fresh fetch guarantee per §16:
#   "Daily-fresh fetch guarantee (per-operation gate + first-use-of-day)."
#
# Per §2.17 live freshness contract status enum:
#   fresh-within-fetch-frequency | stale-warn-degraded | offline-cached
#   | operator-bypass
#
# Markers:
#   .claude-tdd-pro/standards-last-fetch/<source-id>.txt   ISO timestamp
#   .claude-tdd-pro/standards-last-fuod/<YYYY-MM-DD>.txt   marker file
#   .claude-tdd-pro/standards-cache/<source-id>.html       cached content
#
# Usage:
#   freshness-gate.sh --source-id <id> --fetch-frequency <freq>
#                     --now <iso> [--upstream-stub <path>] [--no-network]
#                     [--strict] [--skip-fresh] [--emit-status <path>]
#                     [--emit-audit <jsonl>]
#   freshness-gate.sh --check-first-use-of-day --now <iso>
#                     --upstream-stub <path>
#
# Exit: 0 fresh / 1 stale (blocked) / 2 strict-mode hard fail.

set -uo pipefail

SOURCE_ID=""
FETCH_FREQUENCY=""
NOW_ISO=""
UPSTREAM_STUB=""
NO_NETWORK=0
STRICT=0
SKIP_FRESH=0
EMIT_STATUS=""
EMIT_AUDIT=""
CHECK_FUOD=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-id) SOURCE_ID="$2"; shift 2 ;;
    --fetch-frequency) FETCH_FREQUENCY="$2"; shift 2 ;;
    --now) NOW_ISO="$2"; shift 2 ;;
    --upstream-stub) UPSTREAM_STUB="$2"; shift 2 ;;
    --no-network) NO_NETWORK=1; shift ;;
    --strict) STRICT=1; shift ;;
    --skip-fresh) SKIP_FRESH=1; shift ;;
    --emit-status) EMIT_STATUS="$2"; shift 2 ;;
    --emit-audit) EMIT_AUDIT="$2"; shift 2 ;;
    --check-first-use-of-day) CHECK_FUOD=1; shift ;;
    *) echo "freshness-gate: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$NOW_ISO" ]] && { echo "freshness-gate: --now <iso> required" >&2; exit 2; }
mkdir -p .claude-tdd-pro/standards-last-fetch .claude-tdd-pro/standards-last-fuod

# First-use-of-day mode.
if [[ "$CHECK_FUOD" -eq 1 ]]; then
  TODAY=$(echo "$NOW_ISO" | cut -dT -f1)
  MARKER=".claude-tdd-pro/standards-last-fuod/${TODAY}.txt"
  if [[ -f "$MARKER" ]]; then
    echo "freshness-gate: already refreshed today (${TODAY}); skipping first-use-of-day" >&2
    exit 0
  fi
  echo "freshness-gate: first use of day (${TODAY}); auto-refresh kicked off" >&2
  if [[ -n "$UPSTREAM_STUB" && -x "$UPSTREAM_STUB" ]]; then
    "$UPSTREAM_STUB" >/dev/null 2>&1 || true
  fi
  echo "$NOW_ISO" > "$MARKER"
  exit 0
fi

# Per-operation gate mode.
[[ -z "$SOURCE_ID" ]] && { echo "freshness-gate: --source-id <id> required" >&2; exit 2; }
[[ -z "$FETCH_FREQUENCY" ]] && { echo "freshness-gate: --fetch-frequency required" >&2; exit 2; }

SOURCE_ID="$SOURCE_ID" FETCH_FREQUENCY="$FETCH_FREQUENCY" NOW_ISO="$NOW_ISO" \
UPSTREAM_STUB="$UPSTREAM_STUB" NO_NETWORK="$NO_NETWORK" STRICT="$STRICT" \
SKIP_FRESH="$SKIP_FRESH" EMIT_STATUS="$EMIT_STATUS" EMIT_AUDIT="$EMIT_AUDIT" node -e '
  const fs = require("fs");
  const path = require("path");
  const { execSync } = require("child_process");
  const id = process.env.SOURCE_ID;
  const ff = process.env.FETCH_FREQUENCY;
  const now = new Date(process.env.NOW_ISO).getTime();
  const upstream = process.env.UPSTREAM_STUB;
  const noNetwork = process.env.NO_NETWORK === "1";
  const strict = process.env.STRICT === "1";
  const skipFresh = process.env.SKIP_FRESH === "1";
  const emitStatus = process.env.EMIT_STATUS;
  const emitAudit = process.env.EMIT_AUDIT;

  const windowHours = { hourly: 1, daily: 24, weekly: 168, monthly: 720 }[ff];
  if (!windowHours) {
    process.stderr.write(`freshness-gate: unknown fetch-frequency \"${ff}\"\n`);
    process.exit(2);
  }

  const markerPath = `.claude-tdd-pro/standards-last-fetch/${id}.txt`;
  let lastFetch = null;
  if (fs.existsSync(markerPath)) {
    lastFetch = new Date(fs.readFileSync(markerPath, "utf8").trim()).getTime();
  }
  const ageHours = lastFetch ? (now - lastFetch) / 3600000 : Infinity;
  const isFresh = ageHours <= windowHours;

  let status;
  let exitCode = 0;

  if (skipFresh) {
    status = "operator-bypass";
    if (emitAudit) {
      fs.mkdirSync(path.dirname(emitAudit), { recursive: true });
      fs.appendFileSync(emitAudit,
        JSON.stringify({ source_id: id, ts: process.env.NOW_ISO, action: "skip-fresh", note: "operator bypass via --skip-fresh" }) + "\n");
    }
    exitCode = 0;
  } else if (isFresh) {
    status = "fresh-within-fetch-frequency";
    exitCode = 0;
  } else {
    // Stale. Try to refresh unless --no-network.
    if (!noNetwork && upstream && fs.existsSync(upstream)) {
      try {
        execSync(`"${upstream}"`, { stdio: "ignore" });
        fs.writeFileSync(markerPath, process.env.NOW_ISO);
        status = "fresh-within-fetch-frequency";
        exitCode = 0;
      } catch {
        // Upstream failed.
        const cachePath = `.claude-tdd-pro/standards-cache/${id}.html`;
        if (fs.existsSync(cachePath)) {
          status = "offline-cached";
          exitCode = 0;
        } else {
          status = "stale-warn-degraded";
          process.stderr.write(`freshness-gate: source ${id} stale (age ${Math.round(ageHours)}h, ${ff} window ${windowHours}h); upstream failed; warn-degraded\n`);
          exitCode = strict ? 2 : 0;
          if (strict) process.stderr.write(`freshness-gate: --strict mode rejects stale-warn-degraded\n`);
        }
      }
    } else if (noNetwork) {
      const cachePath = `.claude-tdd-pro/standards-cache/${id}.html`;
      if (fs.existsSync(cachePath)) {
        status = "offline-cached";
        exitCode = 0;
      } else {
        status = "stale-warn-degraded";
        process.stderr.write(`freshness-gate: source ${id} stale (no-network, no cache)\n`);
        exitCode = strict ? 2 : 1;
      }
    } else {
      status = "stale";
      process.stderr.write(`freshness-gate: source ${id} stale (age ${Math.round(ageHours)}h, ${ff} window ${windowHours}h); refresh required\n`);
      exitCode = 1;
    }
  }

  if (emitStatus) {
    fs.mkdirSync(path.dirname(emitStatus), { recursive: true });
    fs.writeFileSync(emitStatus, JSON.stringify({ source_id: id, freshness_at_generation: status, age_hours: Math.round(ageHours), now: process.env.NOW_ISO }));
  }
  process.exit(exitCode);
'
