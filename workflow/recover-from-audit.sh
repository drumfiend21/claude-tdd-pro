#!/usr/bin/env bash
# W-3 recover workflow state by replaying audit-log transitions.
set -uo pipefail
AUDIT_LOG=""; OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --audit-log) AUDIT_LOG="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    -h|--help) echo "Usage: recover-from-audit.sh --audit-log <jsonl> --out <state.json>"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$AUDIT_LOG" || ! -f "$AUDIT_LOG" ]] && { echo "workflow-recover: --audit-log <jsonl> required" >&2; exit 2; }
[[ -z "$OUT" ]] && { echo "workflow-recover: --out <state.json> required" >&2; exit 2; }

mkdir -p "$(dirname "$OUT")"
AUDIT_LOG="$AUDIT_LOG" OUT="$OUT" node -e '
const fs = require("fs");
const lines = fs.readFileSync(process.env.AUDIT_LOG, "utf8").trim().split("\n").filter(Boolean);
const history = [];
let current = null;
for (const l of lines) {
  let o; try { o = JSON.parse(l); } catch { continue; }
  if (o.event !== "workflow-transition") continue;
  history.push({ from: o.from, to: o.to, at: o.at });
  current = o.to;
}
fs.writeFileSync(process.env.OUT, JSON.stringify({ current_state: current, history }));
process.stderr.write(`workflow-recover: current_state=${current} replayed=${history.length} state_file=${process.env.OUT}\n`);
'
