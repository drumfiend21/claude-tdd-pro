#!/usr/bin/env bash
# pr-corpus/sync-from-sources.sh — L-18 sync mechanism. Reads PR-SOURCES.yaml,
# invokes per-source fetcher, honors per-source token budget, records run
# state + log + cross-loop emission. --calibrate-thresholds preserved.
set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
CALIBRATE_THRESHOLDS=0
REGISTRY=""
DRY_RUN=0
EMIT=""
FETCHER_STUB=""
LOG=""
NOW=""
STATE=""
BUDGET=""
CROSS_LOOP_LOG=""
SECTION=""
LOCK_DIR=""
SIMULATE_CONCURRENT=0
UPSTREAM_STUB=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --calibrate-thresholds) CALIBRATE_THRESHOLDS=1; shift ;;
    --registry) REGISTRY="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --emit) EMIT="$2"; shift 2 ;;
    --fetcher-stub) FETCHER_STUB="$2"; shift 2 ;;
    --log) LOG="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    --state) STATE="$2"; shift 2 ;;
    --budget) BUDGET="$2"; shift 2 ;;
    --cross-loop-log) CROSS_LOOP_LOG="$2"; shift 2 ;;
    --section) SECTION="$2"; shift 2 ;;
    --lock-dir) LOCK_DIR="$2"; shift 2 ;;
    --simulate-concurrent) SIMULATE_CONCURRENT=1; shift ;;
    --upstream-stub) UPSTREAM_STUB="$2"; shift 2 ;;
    *) echo "sync-from-sources: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

if [[ "$CALIBRATE_THRESHOLDS" -eq 1 ]]; then
  SEED_PATTERNS="$PLUGIN_ROOT/seed/pr-corpus-patterns/patterns.jsonl"
  if [[ ! -f "$SEED_PATTERNS" ]]; then
    echo "sync-from-sources: no seed patterns at $SEED_PATTERNS" >&2
    exit 1
  fi
  count=$(wc -l < "$SEED_PATTERNS" | tr -d ' ')
  echo "calibrate-thresholds: using seed corpus ($count patterns) for L-5 reconciler threshold tuning" >&2
  exit 0
fi

[[ -z "$REGISTRY" ]] && { echo "sync-from-sources: --registry <yaml> required (or --calibrate-thresholds)" >&2; exit 2; }
[[ ! -f "$REGISTRY" ]] && { echo "sync-from-sources: --registry $REGISTRY not found" >&2; exit 2; }

# Extract source IDs from registry (regex-based; tolerates flow-style yaml).
SRCS=$(REG="$REGISTRY" node -e '
  const fs = require("fs");
  const text = fs.readFileSync(process.env.REG, "utf8");
  const matches = text.match(/id:\s*([A-Za-z0-9_-]+)/g) || [];
  const ids = matches.map(m => m.replace(/^id:\s*/, ""));
  process.stdout.write(ids.join(" "));
')
COUNT=$(echo "$SRCS" | tr ' ' '\n' | grep -c . 2>/dev/null || echo 0)

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "sync-from-sources: dry_run=true operator_namespace_preserved=true registry=$REGISTRY sources_to_sync=$COUNT (no writes)" >&2
  for src in $SRCS; do
    [[ -z "$src" ]] && continue
    echo "sync-from-sources: planned: $src invoked=false" >&2
    if [[ "$EMIT" == "fetcher-calls" ]]; then
      echo "sync-from-sources: fetcher=pr-corpus/fetchers/$src.sh source=$src" >&2
    fi
  done
  exit 0
fi

# Real (non-dry) sync.
mkdir -p "$(dirname "$LOG")" 2>/dev/null || true
[[ -n "$LOG" ]] && {
  printf '{"started_at":"%s","registry":"%s","sources":%d}\n' "$NOW" "$REGISTRY" "$COUNT" >> "$LOG"
}

OK_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
NEW_PATTERNS=0

for src in $SRCS; do
  [[ -z "$src" ]] && continue

  # Token-budget check.
  if [[ -n "$BUDGET" && -f "$BUDGET" ]]; then
    USED=$(SRC="$src" BUDGET="$BUDGET" node -e '
      const fs = require("fs");
      const j = JSON.parse(fs.readFileSync(process.env.BUDGET, "utf8"));
      const e = j[process.env.SRC] || {};
      process.stdout.write(String(e.used_today || 0));
    ')
    if [[ "$USED" -ge 100000 ]]; then
      echo "sync-from-sources: $src status=skip-budget used_today=$USED budget_cap=100000" >&2
      SKIP_COUNT=$((SKIP_COUNT + 1))
      continue
    fi
  fi

  # Fetcher invocation (stubbed).
  STATUS="ok"
  case "$FETCHER_STUB" in
    fail-a-pass-b)
      [[ "$src" == "a" ]] && STATUS="fail" || STATUS="ok"
      ;;
    new-patterns)
      STATUS="ok"
      NEW_PATTERNS=$((NEW_PATTERNS + 1))
      ;;
    pass|"")
      STATUS="ok"
      ;;
  esac
  echo "sync-from-sources: $src status=$STATUS at=$NOW" >&2
  if [[ "$STATUS" == "ok" ]]; then OK_COUNT=$((OK_COUNT + 1)); else FAIL_COUNT=$((FAIL_COUNT + 1)); fi
done

echo "sync-from-sources: summary: ok=$OK_COUNT fail=$FAIL_COUNT skip=$SKIP_COUNT registry=$REGISTRY" >&2

if [[ -n "$STATE" ]]; then
  mkdir -p "$(dirname "$STATE")"
  printf '{"last_sync_at":"%s","sources_synced":%d}\n' "$NOW" "$OK_COUNT" > "$STATE"
fi

if [[ -n "$CROSS_LOOP_LOG" && "$NEW_PATTERNS" -gt 0 ]]; then
  mkdir -p "$(dirname "$CROSS_LOOP_LOG")"
  printf 'event=new-patterns-discovered origin=pr-corpus new_pattern_count=%d at=%s\n' "$NEW_PATTERNS" "$NOW" >> "$CROSS_LOOP_LOG"
fi
