#!/usr/bin/env bash
# L-11 operator clear of an anti-poisoning flag with justification audit trail.
set -uo pipefail
PATTERN=""; FLAG=""; JUSTIFICATION=""; LOG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pattern) PATTERN="$2"; shift 2 ;;
    --flag) FLAG="$2"; shift 2 ;;
    --justification) JUSTIFICATION="$2"; shift 2 ;;
    --log) LOG="$2"; shift 2 ;;
    -h|--help) echo "Usage: safeguards-clear.sh --pattern <id> --flag <name> --justification <text> --log <jsonl>"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$LOG" || ! -f "$LOG" ]] && { echo "safeguards-clear: --log <jsonl> required (must exist)" >&2; exit 2; }
[[ -z "$PATTERN" || -z "$FLAG" ]] && { echo "safeguards-clear: --pattern and --flag required" >&2; exit 2; }
[[ -z "$JUSTIFICATION" ]] && { echo "safeguards-clear: --justification required (audit trail)" >&2; exit 2; }

PATTERN="$PATTERN" FLAG="$FLAG" JUSTIFICATION="$JUSTIFICATION" LOG="$LOG" node -e '
const fs = require("fs");
const lines = fs.readFileSync(process.env.LOG, "utf8").trim().split("\n").filter(Boolean);
const out = [];
let cleared = 0;
for (const l of lines) {
  let o;
  try { o = JSON.parse(l); } catch { out.push(l); continue; }
  if (o.pattern_id === process.env.PATTERN && o.flag === process.env.FLAG) {
    o.cleared = true;
    o.justification = process.env.JUSTIFICATION;
    o.cleared_at = new Date().toISOString();
    cleared++;
  }
  out.push(JSON.stringify(o));
}
fs.writeFileSync(process.env.LOG, out.join("\n") + "\n");
process.stderr.write(`safeguards-clear: cleared=true pattern=${process.env.PATTERN} flag=${process.env.FLAG} entries_updated=${cleared}\n`);
'
