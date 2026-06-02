#!/usr/bin/env bash
# scripts/verify-no-regression.sh — gates that prove the runner optimization
# preserved exact functional behavior + did not touch unrelated repo files.
#
# Five gates, each pass/fail:
#   1. arch-unchanged:    docs/architecture-v1.9.md untouched by perf commit
#   2. memory-unchanged:  docs/memory/ + CLAUDE.md untouched by perf commit
#   3. specs-unchanged:   evals/specs/*.json untouched by perf commit
#                         (perf must not patch specs to accommodate the
#                         optimization — only evals/runner.sh and .gitignore)
#   4. equivalence:       new runner --no-cache --no-parallel produces
#                         bit-identical output to the pre-perf runner
#                         (extracted from git) for a representative filter
#   5. serial-mode-clean: --no-parallel run on full suite is functionally
#                         equivalent to a serial baseline run (same pass/fail)
#
# Exit 0 on all-pass; exit 1 with diagnostics on first failure.

set -uo pipefail

PLUGIN_ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
PERF_COMMIT=${PERF_COMMIT:-b3205cd}   # the runner-optimization commit
BASELINE_COMMIT=${BASELINE_COMMIT:-f14a986}  # last commit before perf
FILTER=${FILTER:-cl408}                # representative slice for equivalence

cd "$PLUGIN_ROOT"

fail=0
report() {
  local gate="$1" status="$2" detail="$3"
  printf '  [%s] %-22s %s\n' "$status" "$gate" "$detail"
  [[ "$status" == FAIL ]] && fail=1
}

echo "verify-no-regression.sh"
echo "  baseline-commit: $BASELINE_COMMIT"
echo "  perf-commit:     $PERF_COMMIT"
echo "  HEAD:            $(git rev-parse --short HEAD)"
echo

# ---- Gate 1: arch unchanged by perf commit ----
arch_diff=$(git diff "$BASELINE_COMMIT" "$PERF_COMMIT" -- docs/architecture-v1.9.md | wc -l | tr -d ' ')
if [[ "$arch_diff" -eq 0 ]]; then
  report arch-unchanged PASS "docs/architecture-v1.9.md untouched ($arch_diff diff lines)"
else
  report arch-unchanged FAIL "docs/architecture-v1.9.md has $arch_diff diff lines in perf commit"
fi

# ---- Gate 2: memory + CLAUDE.md unchanged by perf commit ----
mem_diff=$(git diff "$BASELINE_COMMIT" "$PERF_COMMIT" -- docs/memory/ CLAUDE.md | wc -l | tr -d ' ')
if [[ "$mem_diff" -eq 0 ]]; then
  report memory-unchanged PASS "docs/memory/ + CLAUDE.md untouched ($mem_diff diff lines)"
else
  report memory-unchanged FAIL "docs/memory/ or CLAUDE.md has $mem_diff diff lines in perf commit"
fi

# ---- Gate 3: specs unchanged by perf commit ----
specs_diff=$(git diff "$BASELINE_COMMIT" "$PERF_COMMIT" -- evals/specs/ | wc -l | tr -d ' ')
if [[ "$specs_diff" -eq 0 ]]; then
  report specs-unchanged PASS "evals/specs/ untouched ($specs_diff diff lines)"
else
  report specs-unchanged FAIL "evals/specs/ has $specs_diff diff lines in perf commit (specs should not be patched for runner perf)"
fi

# ---- Gate 4: equivalence on representative filter ----
# Stage the baseline runner side-by-side with the real one so its
# relative-path logic ($SCRIPT_DIR/specs and $SCRIPT_DIR/..) still
# resolves to the live plugin tree. Restore the original on exit.
tmpd=$(mktemp -d -t verify-regression.XXXXXX)
baseline_runner="evals/runner.baseline.sh"
git show "$BASELINE_COMMIT":evals/runner.sh > "$baseline_runner" 2>/dev/null
chmod +x "$baseline_runner"
trap 'rm -rf "$tmpd"; rm -f "$baseline_runner"' EXIT

old_out="$tmpd/old.out"
new_out="$tmpd/new.out"
bash "$baseline_runner" --filter "$FILTER" > "$old_out" 2>&1
old_exit=$?
bash evals/runner.sh --no-cache --no-parallel --filter "$FILTER" > "$new_out" 2>&1
new_exit=$?

if [[ "$old_exit" -eq "$new_exit" ]] && diff -q "$old_out" "$new_out" >/dev/null 2>&1; then
  report equivalence PASS "filter=$FILTER bit-identical output, both exit=$old_exit"
else
  echo "    --- diff (first 10 lines) ---"
  diff "$old_out" "$new_out" | head -10 | sed 's/^/    /'
  report equivalence FAIL "filter=$FILTER outputs differ OR exits differ (old=$old_exit new=$new_exit)"
fi

# ---- Gate 5: serial mode on full suite produces same pass/fail ----
serial_out="$tmpd/serial.out"
bash evals/runner.sh --no-cache --no-parallel > "$serial_out" 2>&1
serial_exit=$?
serial_results=$(grep -E '^Results: ' "$serial_out" | tail -1)
serial_pass=$(echo "$serial_results" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+')
serial_fail=$(echo "$serial_results" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+')

parallel_out="$tmpd/parallel.out"
bash evals/runner.sh --no-cache > "$parallel_out" 2>&1
parallel_exit=$?
parallel_results=$(grep -E '^Results: ' "$parallel_out" | tail -1)
parallel_pass=$(echo "$parallel_results" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+')
parallel_fail=$(echo "$parallel_results" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+')

if [[ "$serial_pass" == "$parallel_pass" && "$serial_fail" == "$parallel_fail" && "$serial_exit" == "$parallel_exit" ]]; then
  report serial-mode-clean PASS "serial=${serial_pass}/${serial_fail} == parallel=${parallel_pass}/${parallel_fail} (exit=$serial_exit)"
else
  report serial-mode-clean FAIL "serial=${serial_pass}/${serial_fail} (exit=$serial_exit) vs parallel=${parallel_pass}/${parallel_fail} (exit=$parallel_exit)"
fi

echo
if [[ "$fail" -eq 0 ]]; then
  echo "verify-no-regression: ALL GATES PASS"
  exit 0
fi
echo "verify-no-regression: FAILED" >&2
exit 1
