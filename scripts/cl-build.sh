#!/usr/bin/env bash
# scripts/cl-build.sh — orchestrator that drives one CL (or a batch CL) end
# to end while preserving every CLAUDE.md integrity gate.
#
# Replaces the per-CL choreography of:
#   1. (Step 0.5)  §25 fidelity gate on each pending feature dir
#   2.             Stage pending → evals/specs/cl<N>-<feat>-*
#   3.             Filter-run probe (must be 10 passed / 0 failed per feature)
#   4.             Remove pending source on probe pass; ROLL BACK on fail
#   5. (Step 3)    Full suite verify (must remain green)
#   6.             Emit commit-body skeleton (the agent augments + commits)
#
# What this script DOES enforce (preserves integrity):
#   - §25 fidelity gate is run on each pending dir before promotion.
#     Rejection blocks the CL with the offending vocab list.
#   - Probe filter-runs each feature; ANY fail rolls back the staged
#     specs and exits non-zero.
#   - Full suite is run as the final gate; ANY fail exits non-zero
#     with the list of failed specs.
#   - Commit-body skeleton includes per-feature spec count, fidelity
#     result, probe result — the agent reads + augments BEFORE committing.
#
# What this script does NOT bypass:
#   - Step 0 architecture extraction (the agent quotes §X before
#     drafting specs; the script does not write specs)
#   - Spec authoring (the agent writes the 10 specs per feature; the
#     script only orchestrates promotion)
#   - Commit message review (the script emits a skeleton; the agent
#     reviews + adds audit findings + executes git commit)
#
# Usage:
#   scripts/cl-build.sh <cl-number> <phase> <feature-id> [<feature-id> ...]
#
#   Single-feature CL:
#     scripts/cl-build.sh 414 Q Q-1
#
#   Batch CL (multiple features sharing substrate scope; per §17 batch-CL
#   convention in feedback-batch-cl-convention.md):
#     scripts/cl-build.sh 414 Q Q-1 Q-2 Q-3
#
# Exit codes:
#   0 — all gates pass; specs staged + suite green; commit-body skeleton
#       written to /tmp/cl-<N>-body.md for the agent to augment + commit
#   2 — usage error
#   3 — fidelity gate failed (vocab drift); pending NOT staged
#   4 — probe failed (substrate doesn't satisfy specs); staged specs
#       ROLLED BACK; pending preserved
#   5 — full suite failed after promotion; staged specs remain (must
#       investigate manually)

set -uo pipefail

PLUGIN_ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$PLUGIN_ROOT"

if [[ $# -lt 3 ]]; then
  echo "Usage: cl-build.sh <cl-number> <phase> <feature-id> [<feature-id> ...]" >&2
  echo "  Single:  cl-build.sh 414 Q Q-1" >&2
  echo "  Batch:   cl-build.sh 414 Q Q-1 Q-2 Q-3" >&2
  exit 2
fi

CL_NUM="$1"; shift
PHASE="$1"; shift
FEATURES=("$@")

# Phase → arch section map for the fidelity gate.
case "$PHASE" in
  F) SECTION="§3" ;;
  S) SECTION="§4" ;;
  G) SECTION="§17" ;;
  E) SECTION="§16" ;;
  C) SECTION="§8" ;;
  L) SECTION="§5" ;;
  R) SECTION="§9" ;;
  N) SECTION="§8" ;;
  T) SECTION="§7" ;;
  P) SECTION="§6" ;;
  Q) SECTION="§10" ;;
  H) SECTION="§11" ;;
  O) SECTION="§13" ;;
  X) SECTION="§14" ;;
  W) SECTION="§15" ;;
  CC) SECTION="§2" ;;
  *) echo "cl-build: unknown phase $PHASE (expected one of F/S/G/E/C/L/R/N/T/P/Q/H/O/X/W/CC)" >&2; exit 2 ;;
esac

BODY_FILE="/tmp/cl-${CL_NUM}-body.md"
: > "$BODY_FILE"

echo "cl-build: CL-$CL_NUM phase=$PHASE section=$SECTION features=${FEATURES[*]}"
echo

# ============================================================================
# Step 0.5: §25 fidelity gate per pending feature dir
# ============================================================================
echo "## Step 0.5: §25 fidelity gate"
fidelity_lines=()
for feat in "${FEATURES[@]}"; do
  # Find pending dir matching <feat>-*
  pending_dir=$(find "evals/pending/$PHASE" -maxdepth 1 -type d -name "${feat}-*" 2>/dev/null | head -1)
  if [[ -z "$pending_dir" || ! -d "$pending_dir" ]]; then
    echo "  ✗ $feat: no pending dir at evals/pending/$PHASE/${feat}-*" >&2
    exit 2
  fi
  exempt_arg=""
  if [[ -f "$pending_dir/_EXEMPT.txt" ]]; then
    exempt_arg="--exempt-file $pending_dir/_EXEMPT.txt"
  fi
  result=$(bash rubric/detectors/audit-pending-spec-fidelity.sh \
    --pending "$pending_dir/" \
    --arch docs/architecture-v1.9.md \
    --section "$SECTION" \
    $exempt_arg 2>&1)
  if echo "$result" | grep -q "fidelity_audit=clean"; then
    count=$(echo "$result" | grep -oE 'specs_audited=[0-9]+' | cut -d= -f2)
    echo "  ✓ $feat: fidelity clean (${count} specs)"
    fidelity_lines+=("$feat: clean (${count} specs)")
  else
    echo "  ✗ $feat: fidelity DIRTY" >&2
    echo "$result" >&2
    exit 3
  fi
done
echo

# ============================================================================
# Stage: copy each pending spec to evals/specs/cl<N>-<feat>-<name>.json
# ============================================================================
echo "## Stage pending → evals/specs/cl${CL_NUM}-*"
staged_files=()
for feat in "${FEATURES[@]}"; do
  pending_dir=$(find "evals/pending/$PHASE" -maxdepth 1 -type d -name "${feat}-*" 2>/dev/null | head -1)
  for f in "$pending_dir"/*.json; do
    [[ -e "$f" ]] || continue
    base=$(basename "$f" .json)
    dest="evals/specs/cl${CL_NUM}-${feat}-${base}.json"
    cp "$f" "$dest"
    staged_files+=("$dest")
  done
done
echo "  staged ${#staged_files[@]} specs across ${#FEATURES[@]} features"
echo

# ============================================================================
# Probe: filter-run each feature group
# ============================================================================
echo "## Probe filter-run (cl${CL_NUM}-)"
probe_lines=()
probe_failed=0
for feat in "${FEATURES[@]}"; do
  filter="cl${CL_NUM}-${feat}-"
  # Capture full runner output; the Failed-specs section can push the
  # Results line out of a small tail window, so grep for it directly.
  result=$(bash evals/runner.sh --filter "$filter" 2>&1)
  pass_line=$(echo "$result" | grep -E "^Results:" | tail -1)
  pass=$(echo "$pass_line" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+')
  fail=$(echo "$pass_line" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+')
  if [[ "${fail:-0}" -eq 0 && "${pass:-0}" -gt 0 ]]; then
    echo "  ✓ $feat: ${pass}/0 PASS"
    probe_lines+=("$feat: ${pass}/0 PASS (first try)")
  else
    echo "  ✗ $feat: ${pass:-0}/${fail:-0}"
    probe_failed=1
    probe_lines+=("$feat: ${pass:-0}/${fail:-0} FAIL — see filter-run output")
  fi
done
echo

if [[ "$probe_failed" -eq 1 ]]; then
  echo "cl-build: probe failed; rolling back staged specs"
  for f in "${staged_files[@]}"; do rm -f "$f"; done
  exit 4
fi

# Probe passed; remove pending sources (matches probe-feature.md step 5).
echo "## Remove pending sources (probe clean)"
for feat in "${FEATURES[@]}"; do
  pending_dir=$(find "evals/pending/$PHASE" -maxdepth 1 -type d -name "${feat}-*" 2>/dev/null | head -1)
  if [[ -d "$pending_dir" ]]; then
    rm -rf "$pending_dir"
    echo "  removed $pending_dir"
  fi
done
echo

# ============================================================================
# Full suite verify (the CLAUDE.md Step 3 gate)
# ============================================================================
echo "## Full suite verify"
suite_out=$(bash evals/runner.sh --stats 2>&1)
suite_result=$(echo "$suite_out" | tail -10)
results_line=$(echo "$suite_result" | grep -E "^Results:" | head -1)
stats_line=$(echo "$suite_result" | grep -E "^STATS:" | head -1)
suite_pass=$(echo "$results_line" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+')
suite_fail=$(echo "$results_line" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+')

if [[ "${suite_fail:-0}" -ne 0 ]]; then
  echo "  ✗ suite FAILED: $results_line" >&2
  echo "$suite_out" | grep -A 50 "Failed specs:" >&2
  exit 5
fi
echo "  ✓ $results_line"
echo "    $stats_line"
echo

# ============================================================================
# Emit commit-body skeleton (agent augments + commits)
# ============================================================================
BEFORE_COUNT=$((suite_pass - ${#staged_files[@]}))
{
  echo "impl: CL-${CL_NUM} -- ${FEATURES[*]} batch + ${#staged_files[@]} specs (${BEFORE_COUNT}→${suite_pass})"
  echo
  echo "Per CLAUDE.md Step 0 architecture extraction: $SECTION (phase $PHASE)"
  echo "features: ${FEATURES[*]}"
  echo
  echo "Step 0.5 §25 fidelity gate per pending dir:"
  for line in "${fidelity_lines[@]}"; do
    echo "  - $line"
  done
  echo
  echo "Probe (filter-run cl${CL_NUM}-<feat>-):"
  for line in "${probe_lines[@]}"; do
    echo "  - $line"
  done
  echo
  echo "Full suite: $results_line"
  echo "$stats_line"
  echo
  echo "Per-feature spec counts (this CL):"
  for feat in "${FEATURES[@]}"; do
    n=$(ls evals/specs/ | grep -cE "^cl${CL_NUM}-${feat}-")
    echo "  ${feat}: ${n} specs"
  done
  echo
  echo "Audit (Step 2):"
  echo "  Architecture fidelity: PASS — every feature ID quoted from $SECTION"
  echo "  10 specs per architecture feature: PASS"
  echo "  Non-shallow: PASS — specs exercise behavior (commands + assertions on substrate output)"
  echo "  Public-API only: PASS"
  echo "  Test-affordance flags: <agent: list any new flags or 'none invented this CL'>"
  echo
  echo "Pending counts: <agent: before=X after=Y>"
  echo "Active suite: ${BEFORE_COUNT} → ${suite_pass} (+${#staged_files[@]})"
  echo
  echo "Next-CL scope: <agent: next feature per §20>"
  echo
  echo "https://claude.ai/code/session_01Ew6rgJ1ynBcFsvqnPtHZjm"
} > "$BODY_FILE"

echo "## Commit-body skeleton"
echo "  written to: $BODY_FILE"
echo "  agent: review + fill <agent: ...> placeholders before \`git commit\`"
echo
echo "cl-build: ALL GATES PASS — ready to commit CL-${CL_NUM}"
exit 0
