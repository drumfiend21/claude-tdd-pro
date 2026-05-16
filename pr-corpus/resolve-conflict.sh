#!/usr/bin/env bash
# L-13 operator conflict resolver. Marks a decisions.jsonl entry as resolved
# with optional --justification audit trail; resolved entries are retained.
set -uo pipefail
PATTERN=""; RES=""; JUST=""; LOG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pattern) PATTERN="$2"; shift 2 ;;
    --resolution) RES="$2"; shift 2 ;;
    --justification) JUST="$2"; shift 2 ;;
    --log) LOG="$2"; shift 2 ;;
    -h|--help) echo "Usage: resolve-conflict.sh --pattern <id> --resolution <decision> [--justification <text>] --log <jsonl>"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$LOG" || ! -f "$LOG" ]] && { echo "resolve-conflict: --log <jsonl> required (must exist)" >&2; exit 2; }
[[ -z "$PATTERN" || -z "$RES" ]] && { echo "resolve-conflict: --pattern and --resolution required" >&2; exit 2; }

PATTERN="$PATTERN" RES="$RES" JUST="$JUST" LOG="$LOG" node -e '
const fs = require("fs");
const lines = fs.readFileSync(process.env.LOG, "utf8").trim().split("\n").filter(Boolean);
const out = [];
let updated = 0;
for (const l of lines) {
  let o; try { o = JSON.parse(l); } catch { out.push(l); continue; }
  if (o.pattern_id === process.env.PATTERN) {
    o.resolved = true;
    o.resolution = process.env.RES;
    if (process.env.JUST) o.justification = process.env.JUST;
    o.resolved_at = new Date().toISOString();
    updated++;
  }
  out.push(JSON.stringify(o));
}
fs.writeFileSync(process.env.LOG, out.join("\n") + "\n");
process.stderr.write(`resolve-conflict: resolved=true pattern=${process.env.PATTERN} resolution=${process.env.RES} entries_updated=${updated}\n`);
'
