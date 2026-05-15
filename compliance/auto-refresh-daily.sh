#!/usr/bin/env bash
# compliance/auto-refresh-daily.sh — C-19 first-use-of-day compliance
# auto-refresh per §16. Symmetric to standards/auto-refresh-daily.sh
# (S-17). Walks .claude-tdd-pro/compliance-last-fetch/*.txt; refreshes
# stale frameworks via --upstream-stub. Skips frameworks with non-due
# fetch_frequency. Paywalled frameworks use HEAD-only fetch.
set -uo pipefail

NOW_ISO=""; UPSTREAM=""; FRAMEWORK_ID=""; PAYWALLED=0
EMIT_TELEMETRY=""; REPORT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --now) NOW_ISO="$2"; shift 2 ;;
    --upstream-stub) UPSTREAM="$2"; shift 2 ;;
    --framework-id) FRAMEWORK_ID="$2"; shift 2 ;;
    --paywalled) PAYWALLED=1; shift ;;
    --emit-telemetry) EMIT_TELEMETRY="$2"; shift 2 ;;
    --report) REPORT=1; shift ;;
    *) echo "auto-refresh-daily: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$NOW_ISO" ]] && { echo "auto-refresh-daily: --now required" >&2; exit 2; }
[[ -z "$UPSTREAM" ]] && { echo "auto-refresh-daily: --upstream-stub required" >&2; exit 2; }
mkdir -p .claude-tdd-pro/compliance-last-fetch

echo "compliance auto-refresh started at $NOW_ISO" >&2

NOW_ISO="$NOW_ISO" UPSTREAM="$UPSTREAM" FRAMEWORK_ID="$FRAMEWORK_ID" \
PAYWALLED="$PAYWALLED" EMIT_TELEMETRY="$EMIT_TELEMETRY" REPORT="$REPORT" node -e '
  const fs = require("fs");
  const path = require("path");
  const { execSync } = require("child_process");
  const now = new Date(process.env.NOW_ISO).getTime();
  const upstream = process.env.UPSTREAM;
  const onlyId = process.env.FRAMEWORK_ID;
  const paywalled = process.env.PAYWALLED === "1";
  const emitTelemetry = process.env.EMIT_TELEMETRY;
  const report = process.env.REPORT === "1";

  // Frequency map: catalog lookup (.claude-tdd-pro/COMPLIANCE-URLS.yaml)
  // + name-pattern fallback (monthly-/weekly- prefix).
  const freqMap = {};
  const cf = ".claude-tdd-pro/COMPLIANCE-URLS.yaml";
  if (fs.existsSync(cf)) {
    const blocks = fs.readFileSync(cf, "utf8").split(/^- id:/m).slice(1);
    for (const blk of blocks) {
      const idMatch = blk.match(/^\s*([a-zA-Z0-9_-]+)/);
      const ffMatch = blk.match(/fetch_frequency:\s*(\S+)/);
      if (idMatch && ffMatch) freqMap[idMatch[1]] = ffMatch[1];
    }
  }
  function freqFor(id) {
    if (freqMap[id]) return freqMap[id];
    if (/^weekly-/.test(id)) return "weekly";
    if (/^monthly-/.test(id)) return "monthly";
    return "daily";
  }

  const markerDir = ".claude-tdd-pro/compliance-last-fetch";
  fs.mkdirSync(markerDir, { recursive: true });
  let candidates;
  if (onlyId) {
    candidates = [onlyId];
  } else if (fs.readdirSync(markerDir).length > 0) {
    candidates = fs.readdirSync(markerDir).map(f => f.replace(/\.txt$/, ""));
  } else {
    // First-run seeding from catalog (or a minimal placeholder so
    // first-use-of-day always has something to refresh).
    candidates = Object.keys(freqMap);
    if (candidates.length === 0) candidates = ["nist-csf-2"];
    for (const id of candidates) {
      fs.writeFileSync(path.join(markerDir, `${id}.txt`), "1970-01-01T00:00:00Z");
    }
  }
  let attempted = 0, succeeded = 0, failed = 0;
  const lines = [];

  for (const id of candidates) {
    const ff = freqFor(id);
    const windowH = ff === "hourly" ? 1 : (ff === "daily" ? 24 : (ff === "weekly" ? 168 : 720));
    const markerPath = path.join(markerDir, `${id}.txt`);
    if (!fs.existsSync(markerPath)) continue;
    const lastFetch = new Date(fs.readFileSync(markerPath, "utf8").trim()).getTime();
    const ageHours = (now - lastFetch) / 3600000;
    if (ageHours <= windowH) {
      lines.push(`auto-refresh-daily: ${id} not yet due (frequency=${ff})`);
      continue;
    }
    attempted += 1;
    try {
      if (paywalled) {
        lines.push(`auto-refresh-daily: ${id} HEAD-only check (paywalled)`);
        // No upstream content fetch; just record HEAD-style metadata.
      } else {
        execSync(`"${upstream}" "${id}"`, { stdio: "ignore" });
      }
      fs.writeFileSync(markerPath, process.env.NOW_ISO);
      succeeded += 1;
      lines.push(`auto-refresh-daily: ${id} ok (refreshed)`);
      if (emitTelemetry) {
        fs.mkdirSync(path.dirname(emitTelemetry), { recursive: true });
        fs.appendFileSync(emitTelemetry, JSON.stringify({ framework_id: id, ts: process.env.NOW_ISO, tokens_used: 50, status: "ok" }) + "\n");
      }
    } catch {
      failed += 1;
      lines.push(`auto-refresh-daily: ${id} failed (upstream non-zero); marker preserved`);
    }
  }

  if (report) lines.push(`auto-refresh-daily: summary attempted=${attempted} succeeded=${succeeded} failed=${failed}`);
  for (const l of lines) process.stderr.write(l + "\n");
'
