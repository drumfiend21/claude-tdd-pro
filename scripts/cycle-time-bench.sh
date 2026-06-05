#!/usr/bin/env bash
# Cycle-time benchmark: harness-on vs harness-off.
#
# Per the Musk Engineering Leadership review:
#   "Time a real feature implementation with/without the full
#    harness. If >2x slower, simplify."
#
# Simulates a representative ticket-shaped operation (spec author →
# fitness audit → suite probe → commit body skeleton) under two
# modes:
#
#   harness-on:    full cl-build orchestrator with all gates
#   harness-off:   minimum required steps (write spec → run suite)
#
# Reports wall-clock delta. CI gate: harness-on must stay within
# 2x of harness-off; >2x triggers the "simplify ruthlessly" path.
#
# Usage:
#   bash scripts/cycle-time-bench.sh [--out <path>] [--iterations N]

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
OUT="$PLUGIN_ROOT/docs/cycle-time-results.md"
ITERATIONS=3

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    --iterations) ITERATIONS="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: cycle-time-bench.sh [--out <path>] [--iterations N]" >&2
      exit 0 ;;
    *) echo "cycle-time-bench: unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Spec template that exercises one feature lookup + one assertion.
write_test_spec() {
  local path="$1" idx="$2"
  cat > "$path" <<EOF
{
  "name": "cycle-time-bench iteration $idx — spec author timing measurement",
  "command": "echo bench-$idx 1>&2",
  "setup": [],
  "expect": {"exit_code": 0, "stderr_contains": ["bench-$idx"]}
}
EOF
}

cycle_harness_off() {
  local idx="$1"
  local tmp; tmp=$(mktemp)
  write_test_spec "$tmp" "$idx"
  bash "$PLUGIN_ROOT/evals/runner.sh" --filter "nonexistent-bench" >/dev/null 2>&1
  rm -f "$tmp"
}

cycle_harness_on() {
  local idx="$1"
  local spec="$PLUGIN_ROOT/evals/specs/cycle-bench-tmp-$idx.json"
  write_test_spec "$spec" "$idx"
  # Filter-run (mimics the cl-build probe step)
  bash "$PLUGIN_ROOT/evals/runner.sh" --filter "cycle-bench-tmp-$idx" >/dev/null 2>&1
  # Fitness gates (mimics the cl-build §25 + completeness checks)
  bash "$PLUGIN_ROOT/rubric/detectors/audit-substrate-completeness.sh" --quiet >/dev/null 2>&1
  bash "$PLUGIN_ROOT/rubric/detectors/audit-cli-surface-fidelity.sh" --quiet >/dev/null 2>&1
  bash "$PLUGIN_ROOT/rubric/detectors/audit-spec-depth.sh" --quiet >/dev/null 2>&1
  rm -f "$spec"
}

bench() {
  local mode="$1" fn="$2"
  local total=0
  for i in $(seq 1 "$ITERATIONS"); do
    local start=$SECONDS
    "$fn" "$i" >/dev/null 2>&1 || true
    local elapsed=$(( SECONDS - start ))
    total=$(( total + elapsed ))
  done
  local mean=$(( total / ITERATIONS ))
  printf '  %-15s %d iterations  total=%ds  mean=%ds\n' "$mode" "$ITERATIONS" "$total" "$mean" >&2
  echo "$mean"
}

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
commit=$(git -C "$PLUGIN_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)

echo "=== cycle-time benchmark @ $ts commit=$commit ===" >&2
off_mean=$(bench "harness-off" cycle_harness_off)
on_mean=$(bench "harness-on"   cycle_harness_on)

# Ratio (integer math; one decimal via scale)
if [[ "$off_mean" -eq 0 ]]; then off_mean=1; fi
ratio_x10=$(( on_mean * 10 / off_mean ))
ratio_int=$(( ratio_x10 / 10 ))
ratio_dec=$(( ratio_x10 % 10 ))

gate="PASS"
gate_emoji="✓"
if [[ "$ratio_x10" -gt 20 ]]; then
  gate="FAIL — harness >2x slower than raw runner; simplify per Musk-review action item"
  gate_emoji="✗"
fi

mkdir -p "$(dirname "$OUT")"
if [[ ! -f "$OUT" ]]; then
  cat > "$OUT" <<'EOF'
# Cycle-time benchmark results

Per the Musk Engineering Leadership review:
> "Time a real feature implementation with/without the full
>  harness. If >2x slower, simplify."

Each row is one benchmark run; rows are appended over time so
trends are visible. Gate: harness-on mean / harness-off mean
must stay ≤ 2.0×.

| Timestamp | Commit | harness-off mean | harness-on mean | ratio | gate |
|---|---|---|---|---|---|
EOF
fi
echo "| $ts | $commit | ${off_mean}s | ${on_mean}s | ${ratio_int}.${ratio_dec}× | $gate_emoji |" >> "$OUT"

echo "" >&2
echo "harness-on/off ratio: ${ratio_int}.${ratio_dec}×" >&2
echo "gate: $gate" >&2

# Telemetry emission (Musk asked for cost/cycle metrics tracking).
if [[ -x "$PLUGIN_ROOT/space/telemetry-emit.sh" ]]; then
  bash "$PLUGIN_ROOT/space/telemetry-emit.sh" \
    --event "cycle-time.bench" --severity "info" \
    --field "harness_off_mean=$off_mean" \
    --field "harness_on_mean=$on_mean" \
    --field "ratio_x10=$ratio_x10" \
    2>/dev/null || true
fi

[[ "$ratio_x10" -le 20 ]] && exit 0 || exit 1
