#!/usr/bin/env bash
# W-3 show current workflow state + history length.
set -uo pipefail
STATE_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --state-file) STATE_FILE="$2"; shift 2 ;;
    -h|--help) echo "Usage: show-state.sh --state-file <json>"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$STATE_FILE" || ! -f "$STATE_FILE" ]] && { echo "workflow-show-state: --state-file <json> required" >&2; exit 2; }

STATE_FILE="$STATE_FILE" node -e '
const st = JSON.parse(require("fs").readFileSync(process.env.STATE_FILE, "utf8"));
const h = (st.history || []).length;
process.stderr.write(`workflow-show-state: current_state=${st.current_state} history_length=${h} state_file=${process.env.STATE_FILE}\n`);
'
