#!/usr/bin/env bash
# Cycle-time + scale benchmark.
#
# Per the simulated Musk-team review (Mark Juncosa):
#   "Cycle time IS the product. Every fitness function, every gate,
#    every documentation pass should answer: does this reduce cycle
#    time, or extend it. If it extends, justify hard."
#
# Measures wall-clock for the operations that define the operator
# inner loop and writes a row to docs/bench-results.md.
#
# Usage:
#   scripts/bench.sh [--out <path>] [--quick]
#
# Measurements:
#   1. install.sh init --yes (cold)            target: <60s
#   2. install.sh init --yes (warm, no-op)     target: <1s
#   3. evals/runner.sh full (warm cache)       target: <30s
#   4. evals/runner.sh --filter (10 specs)     target: <1s
#   5. cl-build.sh on a synthetic 1-feature CL target: <30s
#   6. fitness-trend.sh                        target: <60s

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
OUT="$PLUGIN_ROOT/docs/bench-results.md"
QUICK=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    --quick) QUICK=1; shift ;;
    -h|--help)
      echo "Usage: bench.sh [--out <path>] [--quick]" >&2
      exit 0 ;;
    *) echo "bench: unknown arg: $1" >&2; exit 2 ;;
  esac
done

timed() {
  local label="$1"; shift
  local start=$SECONDS
  "$@" >/dev/null 2>&1
  local rc=$?
  local elapsed=$(( SECONDS - start ))
  printf '  %-50s %3ds  rc=%d\n' "$label" "$elapsed" "$rc"
  echo "$label,$elapsed,$rc"
}

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
commit=$(git -C "$PLUGIN_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)

echo "=== Benchmark @ $ts commit=$commit ===" >&2

results=()
results+=("$(timed 'runner full suite (warm)' bash "$PLUGIN_ROOT/evals/runner.sh")")
results+=("$(timed 'runner filter (cl414-Q-1)' bash "$PLUGIN_ROOT/evals/runner.sh" --filter "cl414-Q-1")")
results+=("$(timed 'audit-substrate-completeness' bash "$PLUGIN_ROOT/rubric/detectors/audit-substrate-completeness.sh")")
results+=("$(timed 'audit-cli-surface-fidelity' bash "$PLUGIN_ROOT/rubric/detectors/audit-cli-surface-fidelity.sh")")
results+=("$(timed 'audit-spec-depth' bash "$PLUGIN_ROOT/rubric/detectors/audit-spec-depth.sh")")
results+=("$(timed 'install.sh doctor' bash "$PLUGIN_ROOT/scripts/install.sh" doctor)")
results+=("$(timed 'fitness-trend (dry-run)' bash "$PLUGIN_ROOT/scripts/fitness-trend.sh" --dry-run)")

# Append to bench-results.md
mkdir -p "$(dirname "$OUT")"
if [[ ! -f "$OUT" ]]; then
  cat > "$OUT" <<'EOF'
# Benchmark results

Per docs/SLO.md and scripts/bench.sh. Each row is one benchmark run;
rows are appended over time so trends are visible.

| Timestamp | Commit | full-suite | filter | sub-comp | cli-fid | spec-depth | doctor | fitness-trend |
|---|---|---|---|---|---|---|---|---|
EOF
fi

# Compose the row.
row="| $ts | $commit "
for r in "${results[@]}"; do
  elapsed=$(echo "$r" | tail -1 | awk -F, '{print $2}')
  row+="| ${elapsed}s "
done
row+="|"
echo "$row" >> "$OUT"

echo "" >&2
echo "Benchmark complete. Results appended to $OUT" >&2
