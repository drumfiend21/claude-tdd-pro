#!/usr/bin/env bash
# standards/auto-refresh-daily.sh — S-17 first-use-of-day auto-refresh
# per §16: "First-use-of-day auto-refresh standards/auto-refresh-daily.sh."
#
# Walks .claude-tdd-pro/standards-last-fetch/*.txt; for each daily
# source whose marker is older than 24h, runs --upstream-stub and on
# success updates the marker. Failures leave the prior marker
# untouched. Rate-limited via --token-budget + --tokens-per-fetch.
# Telemetry emitted as JSONL via --emit-telemetry.
#
# Usage:
#   auto-refresh-daily.sh --now <iso> --upstream-stub <path>
#                          [--source-id <id>]
#                          [--token-budget N --tokens-per-fetch N]
#                          [--emit-telemetry <jsonl>]
#                          [--report]

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
NOW_ISO=""
UPSTREAM=""
SOURCE_ID=""
TOKEN_BUDGET=0
TOKENS_PER_FETCH=0
EMIT_TELEMETRY=""
REPORT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --now) NOW_ISO="$2"; shift 2 ;;
    --upstream-stub) UPSTREAM="$2"; shift 2 ;;
    --source-id) SOURCE_ID="$2"; shift 2 ;;
    --token-budget) TOKEN_BUDGET="$2"; shift 2 ;;
    --tokens-per-fetch) TOKENS_PER_FETCH="$2"; shift 2 ;;
    --emit-telemetry) EMIT_TELEMETRY="$2"; shift 2 ;;
    --report) REPORT=1; shift ;;
    *) echo "auto-refresh-daily: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$NOW_ISO" ]] && { echo "auto-refresh-daily: --now <iso> required" >&2; exit 2; }
[[ -z "$UPSTREAM" ]] && { echo "auto-refresh-daily: --upstream-stub <path> required" >&2; exit 2; }
mkdir -p .claude-tdd-pro/standards-last-fetch

echo "auto-refresh-daily: auto-refresh started at $NOW_ISO" >&2

PLUGIN_ROOT_FOR_NODE="$PLUGIN_ROOT" NOW_ISO="$NOW_ISO" UPSTREAM="$UPSTREAM" \
SOURCE_ID="$SOURCE_ID" TOKEN_BUDGET="$TOKEN_BUDGET" TOKENS_PER_FETCH="$TOKENS_PER_FETCH" \
EMIT_TELEMETRY="$EMIT_TELEMETRY" REPORT="$REPORT" node -e '
  const fs = require("fs");
  const path = require("path");
  const { execSync } = require("child_process");
  const pluginRoot = process.env.PLUGIN_ROOT_FOR_NODE;
  const nowIso = process.env.NOW_ISO;
  const now = new Date(nowIso).getTime();
  const upstream = process.env.UPSTREAM;
  const onlyId = process.env.SOURCE_ID;
  const tokenBudget = parseInt(process.env.TOKEN_BUDGET || "0", 10);
  const tokensPerFetch = parseInt(process.env.TOKENS_PER_FETCH || "0", 10);
  const emitTelemetry = process.env.EMIT_TELEMETRY;
  const report = process.env.REPORT === "1";

  // Load fetch_frequency from catalog (sources.yaml + STANDARDS-URLS.yaml).
  const freqMap = {};
  const catalogs = [
    path.join(pluginRoot, "standards/sources.yaml"),
    ".claude-tdd-pro/STANDARDS-URLS.yaml"
  ];
  for (const c of catalogs) {
    if (!fs.existsSync(c)) continue;
    const blocks = fs.readFileSync(c, "utf8").split(/^- id:/m).slice(1);
    for (const blk of blocks) {
      const idMatch = blk.match(/^\s*([a-zA-Z0-9_-]+)/);
      const ffMatch = blk.match(/fetch_frequency:\s*(\S+)/);
      if (idMatch && ffMatch) freqMap[idMatch[1]] = ffMatch[1];
    }
  }

  function fetchFrequencyFor(id) {
    if (freqMap[id]) return freqMap[id];
    if (/^weekly-/.test(id) || /-weekly$/.test(id)) return "weekly";
    if (/^monthly-/.test(id) || /-monthly$/.test(id)) return "monthly";
    return "daily";
  }

  // Discover candidate sources. If no markers exist (first run), seed
  // from the catalog so first-use-of-day actually refreshes.
  const markerDir = ".claude-tdd-pro/standards-last-fetch";
  let candidates = [];
  if (onlyId) {
    candidates = [onlyId];
  } else if (fs.existsSync(markerDir) && fs.readdirSync(markerDir).length > 0) {
    candidates = fs.readdirSync(markerDir).map(f => f.replace(/\.txt$/, ""));
  } else {
    // First-run seeding from catalog.
    candidates = Object.keys(freqMap);
    for (const id of candidates) {
      // Stamp an old marker so the age check fires.
      fs.writeFileSync(path.join(markerDir, `${id}.txt`), "1970-01-01T00:00:00Z");
    }
  }

  let attempted = 0, succeeded = 0, failed = 0, tokensSpent = 0;
  const lines = [];

  for (const id of candidates) {
    const ff = fetchFrequencyFor(id);
    if (ff !== "daily") {
      lines.push(`auto-refresh-daily: ${id} skipped (frequency=${ff})`);
      continue;
    }
    const markerPath = path.join(markerDir, `${id}.txt`);
    if (!fs.existsSync(markerPath)) continue;
    const lastFetch = new Date(fs.readFileSync(markerPath, "utf8").trim()).getTime();
    const ageHours = (now - lastFetch) / 3600000;
    if (ageHours <= 24) continue;

    if (tokenBudget > 0 && tokensPerFetch > 0 && tokensSpent + tokensPerFetch > tokenBudget) {
      lines.push(`auto-refresh-daily: budget exhausted (${tokensSpent}/${tokenBudget} tokens used); ${id} deferred`);
      break;
    }
    attempted += 1;
    try {
      execSync(`"${upstream}" "${id}"`, { stdio: "ignore" });
      fs.writeFileSync(markerPath, nowIso);
      succeeded += 1;
      lines.push(`auto-refresh-daily: ${id} ok (refreshed)`);
      tokensSpent += tokensPerFetch;
      if (emitTelemetry) {
        fs.mkdirSync(path.dirname(emitTelemetry), { recursive: true });
        fs.appendFileSync(emitTelemetry,
          JSON.stringify({ source_id: id, ts: nowIso, tokens_used: tokensPerFetch || 0, status: "ok" }) + "\n");
      }
    } catch {
      failed += 1;
      lines.push(`auto-refresh-daily: ${id} failed (upstream non-zero); marker preserved`);
      if (emitTelemetry) {
        fs.appendFileSync(emitTelemetry,
          JSON.stringify({ source_id: id, ts: nowIso, tokens_used: 0, status: "failed" }) + "\n");
      }
    }
  }

  if (report) {
    lines.push(`auto-refresh-daily: summary attempted=${attempted} succeeded=${succeeded} failed=${failed} tokens=${tokensSpent}`);
  }
  for (const l of lines) process.stderr.write(l + "\n");
  process.exit(0);
'
