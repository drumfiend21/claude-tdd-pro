#!/usr/bin/env bash
# L-13 decisions.jsonl reader. Default: pending only. --include-resolved adds
# resolved entries (audit-traceability retention).
set -uo pipefail
LOG=""; INCLUDE_RESOLVED=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --log) LOG="$2"; shift 2 ;;
    --include-resolved) INCLUDE_RESOLVED=1; shift ;;
    -h|--help) echo "Usage: list-decisions.sh --log <jsonl> [--include-resolved]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$LOG" || ! -f "$LOG" ]] && { echo "list-decisions: --log <jsonl> required (must exist)" >&2; exit 2; }

LOG="$LOG" INC="$INCLUDE_RESOLVED" node -e '
const fs = require("fs");
const lines = fs.readFileSync(process.env.LOG, "utf8").trim().split("\n").filter(Boolean);
const inc = process.env.INC === "1";
let pending = 0, resolved = 0;
for (const l of lines) {
  let o; try { o = JSON.parse(l); } catch { continue; }
  if (o.resolved) {
    resolved++;
    if (inc) process.stderr.write(JSON.stringify(o) + "\n");
  } else {
    pending++;
    process.stderr.write(JSON.stringify(o) + "\n");
  }
}
process.stderr.write(`list-decisions: pending=${pending} resolved_count=${resolved}\n`);
'
