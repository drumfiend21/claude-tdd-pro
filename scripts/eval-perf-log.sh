#!/usr/bin/env bash
# scripts/eval-perf-log.sh — instrumentation wrapper for evals/runner.sh.
#
# Runs the runner under `time`, captures stdout + stderr + exit + wall/cpu
# time + the runner's own --stats line, and appends one JSONL record to
# .claude-tdd-pro/eval-perf.jsonl. Use to collect before/after timing
# samples and to monitor cache-hit rate as the suite grows.
#
# Usage:
#   bash scripts/eval-perf-log.sh                 # full suite, default
#   bash scripts/eval-perf-log.sh cl408           # filter
#   bash scripts/eval-perf-log.sh --no-cache      # disable cache
#   bash scripts/eval-perf-log.sh --no-parallel   # force serial
#   bash scripts/eval-perf-log.sh --label cold    # custom label in record
#
# Output:
#   .claude-tdd-pro/eval-perf.jsonl appended with one line per run, e.g.
#   {"ts":"2026-06-02T16:00:00Z","label":"cached","args":"",
#    "real_s":57.3,"user_s":66.4,"sys_s":24.6,"exit":0,
#    "pass":3679,"fail":0,"workers":4,"parallel_specs":3675,
#    "serial_specs":4,"cache":1,"cache_hits":3669,"cache_misses":10,
#    "tree_sha":"abc123def456","commit":"ae63a94"}

set -uo pipefail

PLUGIN_ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
LOG_FILE="$PLUGIN_ROOT/.claude-tdd-pro/eval-perf.jsonl"
mkdir -p "$(dirname "$LOG_FILE")"

LABEL=""
RUNNER_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --label) LABEL="$2"; shift 2 ;;
    *) RUNNER_ARGS+=("$1"); shift ;;
  esac
done

# Always add --stats so the runner emits its instrumentation line.
RUNNER_ARGS+=("--stats")

OUT_FILE=$(mktemp -t eval-perf-out.XXXXXX)
trap 'rm -f "$OUT_FILE"' EXIT

START_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
START_TS=$(date +%s.%N)
# Capture wall time ourselves (the bash builtin `time` is a keyword, and
# /usr/bin/time isn't installed in all containers; date +%s.%N is portable).
# user/sys timing is reported by `times` after the subshell exits.
bash "$PLUGIN_ROOT/evals/runner.sh" "${RUNNER_ARGS[@]}" > "$OUT_FILE" 2>&1
EXIT_CODE=$?
END_TS=$(date +%s.%N)
REAL_S=$(awk "BEGIN{printf \"%.3f\", $END_TS - $START_TS}")
# user/sys not portable without /usr/bin/time; emit 0 placeholders.
USER_S=0
SYS_S=0

# Parse runner output.
RESULTS_LINE=$(grep -E '^Results: [0-9]+ passed, [0-9]+ failed' "$OUT_FILE" | tail -1)
PASS=$(echo "$RESULTS_LINE" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' || echo 0)
FAIL=$(echo "$RESULTS_LINE" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' || echo 0)

STATS_LINE=$(grep -E '^STATS:' "$OUT_FILE" | tail -1)
WORKERS=$(echo "$STATS_LINE" | grep -oE 'workers=[0-9]+' | cut -d= -f2 || echo 0)
PAR_SPECS=$(echo "$STATS_LINE" | grep -oE 'parallel_specs=[0-9]+' | cut -d= -f2 || echo 0)
SER_SPECS=$(echo "$STATS_LINE" | grep -oE 'serial_specs=[0-9]+' | cut -d= -f2 || echo 0)
CACHE=$(echo "$STATS_LINE" | grep -oE 'cache=[0-9]+' | cut -d= -f2 || echo 0)
HITS=$(echo "$STATS_LINE" | grep -oE 'cache_hits=[0-9]+' | cut -d= -f2 || echo 0)
MISSES=$(echo "$STATS_LINE" | grep -oE 'cache_misses=[0-9]+' | cut -d= -f2 || echo 0)
TREE_SHA=$(echo "$STATS_LINE" | grep -oE 'tree_sha=[a-f0-9]+' | cut -d= -f2 || echo "")

COMMIT=$(cd "$PLUGIN_ROOT" && git rev-parse --short HEAD 2>/dev/null || echo "")

# Args for the record (without the auto-added --stats).
ARGS_JSON=$(printf '%s ' "${RUNNER_ARGS[@]}" | sed 's/--stats//' | sed 's/ *$//' | sed 's/"/\\"/g')

printf '{"ts":"%s","label":"%s","args":"%s","real_s":%s,"user_s":%s,"sys_s":%s,"exit":%d,"pass":%d,"fail":%d,"workers":%d,"parallel_specs":%d,"serial_specs":%d,"cache":%d,"cache_hits":%d,"cache_misses":%d,"tree_sha":"%s","commit":"%s"}\n' \
  "$START_ISO" "$LABEL" "$ARGS_JSON" \
  "$REAL_S" "$USER_S" "$SYS_S" \
  "$EXIT_CODE" "$PASS" "$FAIL" \
  "$WORKERS" "$PAR_SPECS" "$SER_SPECS" \
  "$CACHE" "$HITS" "$MISSES" \
  "$TREE_SHA" "$COMMIT" \
  >> "$LOG_FILE"

# Echo the new record + a one-line human summary to stderr.
tail -1 "$LOG_FILE" >&2
echo "perf-log: label=$LABEL real=${REAL_S}s pass=$PASS fail=$FAIL cache_hits=$HITS misses=$MISSES (appended to $LOG_FILE)" >&2

exit "$EXIT_CODE"
