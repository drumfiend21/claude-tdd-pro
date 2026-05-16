#!/usr/bin/env bash
# L-13 conflict surfacer. Appends a reconciler decision to decisions.jsonl
# with surfaced_at timestamp and resolved=false marker.
set -uo pipefail
DEC=""; LOG=""; NOW=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --decision) DEC="$2"; shift 2 ;;
    --log) LOG="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    -h|--help) echo "Usage: surface-conflict.sh --decision <json> --log <jsonl> [--now <iso>]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$DEC" || ! -f "$DEC" ]] && { echo "surface-conflict: --decision <json> required" >&2; exit 2; }
[[ -z "$LOG" ]] && { echo "surface-conflict: --log <jsonl> required" >&2; exit 2; }
[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

mkdir -p "$(dirname "$LOG")"
DEC="$DEC" LOG="$LOG" NOW="$NOW" node -e '
const fs = require("fs");
const d = JSON.parse(fs.readFileSync(process.env.DEC, "utf8"));
const rec = {
  pattern_id: d.pattern_id,
  existing_rule_id: d.matched_rule_id || d.existing_rule_id || "",
  classification: d.classification || "conflict",
  proposed_resolution: d.proposed_resolution || "",
  surfaced_at: process.env.NOW,
  resolved: false
};
fs.appendFileSync(process.env.LOG, JSON.stringify(rec) + "\n");
process.stderr.write(`surface-conflict: surfaced=true pattern=${rec.pattern_id} existing_rule=${rec.existing_rule_id}\n`);
'
