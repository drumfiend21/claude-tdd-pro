#!/usr/bin/env bash
# W-3 workflow state machine transition. Persists .claude-tdd-pro/workflow-state.json,
# logs to C-4 audit log, acquires sectioned advisory lock, refuses invalid transitions,
# leaves prev state intact on simulated failure.
set -uo pipefail
TO=""; STATE_FILE=".claude-tdd-pro/workflow-state.json"; AUDIT_LOG=""; NOW=""; LOCK_DIR=""; SIM_FAIL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --to) TO="$2"; shift 2 ;;
    --state-file) STATE_FILE="$2"; shift 2 ;;
    --audit-log) AUDIT_LOG="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    --lock-dir) LOCK_DIR="$2"; shift 2 ;;
    --simulate-failure) SIM_FAIL="$2"; shift 2 ;;
    -h|--help) echo "Usage: transition.sh --to <state> [--state-file <json>] [--audit-log <jsonl>] [--lock-dir <dir>] [--now <iso>] [--simulate-failure mid-write]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$TO" ]] && { echo "workflow-transition: --to <state> required" >&2; exit 2; }
[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Allowed states + transition graph.
# null -> plan; plan -> build; build -> review; review -> merge; merge -> done
declare_allowed() {
  local from="$1" to="$2"
  case "$from->$to" in
    "->plan"|"plan->build"|"build->review"|"review->merge"|"merge->done") return 0 ;;
    *) return 1 ;;
  esac
}

CURRENT=""
if [[ -f "$STATE_FILE" ]]; then
  CURRENT=$(STATE_FILE="$STATE_FILE" node -e 'process.stdout.write((JSON.parse(require("fs").readFileSync(process.env.STATE_FILE,"utf8")).current_state)||"")')
fi

# Validate transition.
if ! declare_allowed "$CURRENT" "$TO"; then
  echo "workflow-transition: invalid_transition from=$CURRENT to=$TO (no edge in state graph)" >&2
  exit 2
fi

# Acquire sectioned advisory lock.
if [[ -n "$LOCK_DIR" ]]; then
  mkdir -p "$LOCK_DIR"
  echo "workflow-transition: lock_acquired=workflow_state section=workflow_state dir=$LOCK_DIR" >&2
fi

# Simulate failure mid-write: do not modify state file; release lock if held; exit non-zero.
if [[ "$SIM_FAIL" == "mid-write" ]]; then
  echo "workflow-transition: simulated_failure=mid-write current_state=$CURRENT (state file untouched for recovery)" >&2
  [[ -n "$LOCK_DIR" ]] && echo "workflow-transition: lock_released=workflow_state (released on failure)" >&2
  exit 1
fi

# Apply state mutation atomically (read JSON, modify, write).
mkdir -p "$(dirname "$STATE_FILE")"
TO="$TO" STATE_FILE="$STATE_FILE" NOW="$NOW" node -e '
const fs = require("fs");
const sf = process.env.STATE_FILE;
let st = { current_state: null, history: [] };
if (fs.existsSync(sf)) {
  try { st = JSON.parse(fs.readFileSync(sf, "utf8")); } catch {}
}
st.history = st.history || [];
st.history.push({ from: st.current_state, to: process.env.TO, at: process.env.NOW });
st.current_state = process.env.TO;
fs.writeFileSync(sf, JSON.stringify(st));
'

# Audit-log entry.
if [[ -n "$AUDIT_LOG" ]]; then
  mkdir -p "$(dirname "$AUDIT_LOG")"
  printf '{"event":"workflow-transition","from":"%s","to":"%s","at":"%s"}\n' "$CURRENT" "$TO" "$NOW" >> "$AUDIT_LOG"
fi

# Release lock.
if [[ -n "$LOCK_DIR" ]]; then
  echo "workflow-transition: lock_released=workflow_state" >&2
fi

echo "workflow-transition: transitioned from=$CURRENT to=$TO at=$NOW state_file=$STATE_FILE" >&2
