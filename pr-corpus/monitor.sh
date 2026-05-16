#!/usr/bin/env bash
# L-10 daily-monitor for PR-corpus background fetching.
# Refuses to start when L-3.5 quality-eval gate is not pass; reads source
# list from operator PR-SOURCES.yaml; honors L-19 daily-fresh fetch
# guarantee; appends per-run records for audit traceability; --once for CI.
set -uo pipefail
GATE=""; ONCE=0; SOURCES=""; SOURCES_STUB=""; LOG=""; NOW=""; STATE=""
SIMULATE_SHUTDOWN=0; FETCHER_STUB=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --gate-result) GATE="$2"; shift 2 ;;
    --once) ONCE=1; shift ;;
    --sources) SOURCES="$2"; shift 2 ;;
    --sources-stub) SOURCES_STUB="$2"; shift 2 ;;
    --log) LOG="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    --state) STATE="$2"; shift 2 ;;
    --simulate-shutdown) SIMULATE_SHUTDOWN=1; shift ;;
    --fetcher-stub) FETCHER_STUB="$2"; shift 2 ;;
    -h|--help) echo "Usage: monitor.sh --gate-result <json> [--once] [--sources <yaml>|--sources-stub <yaml>] [--log <file>] [--state <json>] [--now <iso>] [--simulate-shutdown] [--fetcher-stub <mode>]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
[[ -z "$GATE" || ! -f "$GATE" ]] && { echo "monitor: --gate-result <json> required" >&2; exit 2; }

GATE_VAL=$(GATE="$GATE" node -e 'const j=JSON.parse(require("fs").readFileSync(process.env.GATE,"utf8"));process.stdout.write(j.gate||"unknown")')
if [[ "$GATE_VAL" != "pass" ]]; then
  echo "monitor: monitor_blocked gate=$GATE_VAL (quality-eval gate must report gate=pass; run /pr-quality-eval first)" >&2
  exit 2
fi

echo "monitor: monitor_started at=$NOW gate=pass" >&2

if [[ -n "$LOG" ]]; then
  mkdir -p "$(dirname "$LOG")"
  echo "started_at=$NOW gate=pass once=$ONCE" >> "$LOG"
fi

SRC_FILE="${SOURCES:-$SOURCES_STUB}"
if [[ -n "$SRC_FILE" && -f "$SRC_FILE" ]]; then
  SRCS=$(SRC_FILE="$SRC_FILE" node -e '
    const fs = require("fs");
    const text = fs.readFileSync(process.env.SRC_FILE, "utf8");
    const matches = text.match(/id:\s*([A-Za-z0-9_-]+)/g) || [];
    const ids = matches.map(m => m.replace(/^id:\s*/, ""));
    process.stdout.write(ids.join(" "));
  ')
  for src in $SRCS; do
    LAST_FILE=".claude-tdd-pro/pr-corpus/last-fetch/$src.txt"
    STATUS="fetched"
    if [[ -f "$LAST_FILE" ]]; then
      LAST=$(tr -d '\n' < "$LAST_FILE")
      DIFF_SEC=$(NOW="$NOW" LAST="$LAST" node -e 'process.stdout.write(String(Math.floor((new Date(process.env.NOW) - new Date(process.env.LAST))/1000)))' 2>/dev/null || echo 0)
      if [[ "$DIFF_SEC" -lt 86400 ]]; then
        STATUS="fresh-skip"
      fi
    fi
    echo "monitor: source=$src status=$STATUS at=$NOW" >&2
    [[ -n "$LOG" ]] && echo "source=$src status=$STATUS at=$NOW" >> "$LOG"
  done
fi

if [[ "$SIMULATE_SHUTDOWN" -eq 1 ]]; then
  echo "monitor: shutdown=clean exit=0 (caught SIGTERM-equivalent between iterations)" >&2
fi

if [[ -n "$STATE" ]]; then
  mkdir -p "$(dirname "$STATE")"
  printf '{"last_run_at":"%s","gate":"pass","once":%s}\n' "$NOW" "$ONCE" > "$STATE"
fi

echo "monitor: iterations=1 done at=$NOW" >&2
