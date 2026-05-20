#!/usr/bin/env bash
# W-3 validate state file against the §2.15 contract: current_state must be
# one of {plan, build, review, merge, done} (or null on first-touch).
set -uo pipefail
STATE_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --state-file) STATE_FILE="$2"; shift 2 ;;
    -h|--help) echo "Usage: validate-state.sh --state-file <json|/dev/stdin>"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$STATE_FILE" ]] && { echo "workflow-validate-state: --state-file required" >&2; exit 2; }

STATE_FILE="$STATE_FILE" node -e '
const sf = process.env.STATE_FILE;
const data = require("fs").readFileSync(sf, "utf8");
const j = JSON.parse(data);
const allowed = new Set(["plan", "build", "review", "merge", "done", null]);
if (!allowed.has(j.current_state)) {
  process.stderr.write(`workflow-validate-state: invalid_state=${j.current_state} (expected one of plan|build|review|merge|done)\n`);
  process.exit(1);
}
process.stderr.write(`workflow-validate-state: valid=true current_state=${j.current_state}\n`);
'
