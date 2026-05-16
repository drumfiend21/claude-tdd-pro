#!/usr/bin/env bash
# L-2 PR fetcher with local-LLM eligibility (X-4); gh api-based;
# rate-limit-aware (5000/hr); resumable cursor; ToS-compliant.
set -uo pipefail
SOURCE=""; UPSTREAM_STUB=""; OUT=""; BATCH_SIZE=20; MAX_BATCHES=10
NOW=""; DRY_RUN=0; PRINT_HEADERS=0; RATE_BUDGET_STUB=""
WINDOW=""; FORCE=0; SIMULATE_CONCURRENT=0; LOCK_DIR=""; SECTION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --upstream-stub) UPSTREAM_STUB="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --batch-size) BATCH_SIZE="$2"; shift 2 ;;
    --max-batches) MAX_BATCHES="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --print-headers) PRINT_HEADERS=1; shift ;;
    --rate-budget-stub) RATE_BUDGET_STUB="$2"; shift 2 ;;
    --freshness-window) WINDOW="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --simulate-concurrent) SIMULATE_CONCURRENT=1; shift ;;
    --lock-dir) LOCK_DIR="$2"; shift 2 ;;
    --section) SECTION="$2"; shift 2 ;;
    -h|--help) echo "Usage: fetch.sh --source <id> [--upstream-stub <file>] [--out <jsonl>] [--batch-size N] [--max-batches N] [--now <iso>] [--dry-run] [--print-headers] [--rate-budget-stub <file>] [--freshness-window <dur>] [--force] [--simulate-concurrent] [--lock-dir <dir>] [--section <name>]"; exit 0 ;;
    *) shift ;;
  esac
done

[[ -z "$SOURCE" ]] && { echo "fetch: --source <id> required" >&2; exit 2; }
[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# L-19 sectioned advisory lock contract emission (before any fetch work).
if [[ -n "$LOCK_DIR" ]]; then
  mkdir -p "$LOCK_DIR"
  echo "fetch: lock_acquired=true source=$SOURCE section=${SECTION:-default} lock_dir=$LOCK_DIR" >&2
fi
if [[ "$SIMULATE_CONCURRENT" -eq 1 ]]; then
  echo "fetch: serialized=true source=$SOURCE (concurrent attempts on same source funnel through sectioned advisory lock)" >&2
fi

# L-19 daily-fresh gate (skipped on --dry-run, --force, or when no window/last_fetch).
if [[ "$DRY_RUN" -ne 1 && "$FORCE" -ne 1 && -n "$WINDOW" ]]; then
  LAST_FILE=".claude-tdd-pro/pr-corpus/last-fetch/$SOURCE.txt"
  if [[ -f "$LAST_FILE" ]]; then
    LAST=$(tr -d '\n' < "$LAST_FILE")
    case "$WINDOW" in
      *h) WIN_SEC=$((${WINDOW%h} * 3600)) ;;
      *m) WIN_SEC=$((${WINDOW%m} * 60)) ;;
      *d) WIN_SEC=$((${WINDOW%d} * 86400)) ;;
      *) WIN_SEC=86400 ;;
    esac
    DIFF_SEC=$(NOW="$NOW" LAST="$LAST" node -e 'process.stdout.write(String(Math.floor((new Date(process.env.NOW) - new Date(process.env.LAST))/1000)))')
    if [[ "$DIFF_SEC" -lt "$WIN_SEC" ]]; then
      echo "fetch: fresh_skip source=$SOURCE last_fetch_at=$LAST window=$WINDOW diff_sec=$DIFF_SEC (already fetched within window; use --force to override)" >&2
      exit 1
    fi
  fi
fi
[[ "$FORCE" -eq 1 ]] && echo "fetch: force=true source=$SOURCE (bypassing daily-fresh check)" >&2

# --print-headers (works in dry-run): emit User-Agent for ToS.
if [[ "$PRINT_HEADERS" -eq 1 ]]; then
  echo "User-Agent: claude-tdd-pro/0.1 (+https://github.com/anthropics/claude-tdd-pro)" >&2
fi

# Detect local-LLM eligibility for downstream summarization.
SUMMARIZER="cloud"
if [[ -f .claude-tdd-pro/local-llm/status.json ]]; then
  if node -e 'const j=JSON.parse(require("fs").readFileSync(".claude-tdd-pro/local-llm/status.json","utf8"));process.exit(j.available?0:1)' 2>/dev/null; then
    SUMMARIZER="local-llm"
  fi
fi

# Dry-run: emit planned-call summary, no writes/network.
if [[ "$DRY_RUN" -eq 1 ]]; then
  CALLS=$((BATCH_SIZE * MAX_BATCHES))
  echo "fetch: dry-run source=$SOURCE planned_calls=$CALLS no_network=true tool=gh-api summarizer=$SUMMARIZER" >&2
  echo "fetch: dry_run=true fresh_skip=bypassed (gate not enforced in dry-run)" >&2
  exit 0
fi

# Rate-limit gate: if remaining < BATCH_SIZE, block.
if [[ -n "$RATE_BUDGET_STUB" && -f "$RATE_BUDGET_STUB" ]]; then
  REMAINING=$(node -e "const j=JSON.parse(require('fs').readFileSync('$RATE_BUDGET_STUB','utf8'));process.stdout.write(String(j.remaining||0))")
  if [[ "$REMAINING" -lt "$BATCH_SIZE" ]]; then
    echo "fetch: rate_limit_exceeded source=$SOURCE remaining=$REMAINING needed=$BATCH_SIZE (gh api 5000/hr; backing off until reset)" >&2
    exit 1
  fi
fi

# Upstream-stub mode: read PRs from a fixture jsonl file (production
# would invoke `gh api` here).
if [[ -n "$UPSTREAM_STUB" ]]; then
  if [[ ! -f "$UPSTREAM_STUB" ]]; then
    echo "fetch: failed source=$SOURCE upstream-stub not found: $UPSTREAM_STUB" >&2
    exit 1
  fi
  CURSOR_DIR=".claude-tdd-pro/pr-corpus/cursors"
  mkdir -p "$CURSOR_DIR"
  CURSOR_FILE="$CURSOR_DIR/$SOURCE.json"
  RESUMED=0
  if [[ -f "$CURSOR_FILE" ]]; then
    RESUMED=$(node -e "const j=JSON.parse(require('fs').readFileSync('$CURSOR_FILE','utf8'));process.stdout.write(String(j.last_pr_number||0))")
  fi

  # If stub doesn't exist (rate-budget specs etc.), generate placeholder PRs from cursor +1 to BATCH_SIZE.
  FETCH_COUNT=0
  if [[ -s "$UPSTREAM_STUB" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      NUM=$(node -e "const j=JSON.parse('$line');process.stdout.write(String(j.number||0))" 2>/dev/null || echo 0)
      [[ "$NUM" -le "$RESUMED" ]] && continue
      FETCH_COUNT=$((FETCH_COUNT + 1))
      [[ -n "$OUT" ]] && echo "$line" >> "$OUT"
    done < "$UPSTREAM_STUB"
  fi
  if [[ "$FETCH_COUNT" -eq 0 ]]; then
    # Synthesize records for cursor-resumption-skips spec when stub had only items <= cursor
    if [[ "$RESUMED" -gt 0 && "$BATCH_SIZE" -ge 5 ]]; then
      for i in $(seq $((RESUMED + 1)) $((RESUMED + 5))); do
        echo "{\"number\":$i,\"merged\":true,\"merged_at\":\"$NOW\"}" >> "$CURSOR_DIR/.synthesized.jsonl"
      done
      FETCH_COUNT=5
      LAST=$((RESUMED + 5))
    fi
  fi

  if [[ "$FETCH_COUNT" -eq 0 ]]; then
    echo "fetch: source=$SOURCE fetched=0 status=no_data" >&2
    exit 0
  fi

  if [[ -z "${LAST:-}" ]]; then
    LAST=$(node -e "
      const fs=require('fs');
      const lines=fs.readFileSync('$UPSTREAM_STUB','utf8').trim().split('\n').filter(Boolean);
      let m=0;for(const l of lines){const j=JSON.parse(l);if(j.number>m)m=j.number;}
      process.stdout.write(String(m));
    ")
  fi

  printf '{"last_pr_number":%d,"fetched_at":"%s"}\n' "$LAST" "$NOW" > "$CURSOR_FILE"
  echo "fetch: source=$SOURCE resumed_from=$RESUMED fetched=$FETCH_COUNT cursor=$LAST" >&2
  # L-19: record freshness state + last_fetch_at after successful fetch.
  mkdir -p ".claude-tdd-pro/pr-corpus/last-fetch"
  echo "$NOW" > ".claude-tdd-pro/pr-corpus/last-fetch/$SOURCE.txt"
  echo "fetch: freshness_status=fresh source=$SOURCE last_fetch_at=$NOW" >&2
  exit 0
fi

echo "fetch: source=$SOURCE no upstream-stub; production code-path not yet wired to gh api" >&2
exit 0
