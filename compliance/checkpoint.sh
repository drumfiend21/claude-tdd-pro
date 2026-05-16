#!/usr/bin/env bash
# L-14 merkle-chain checkpoint emitter. Reads audit-log.jsonl and writes a
# checkpoint.json with merkle_root and included_events count.
set -uo pipefail
AUDIT_LOG=""; OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --audit-log) AUDIT_LOG="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    -h|--help) echo "Usage: checkpoint.sh --audit-log <jsonl> --out <json>"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$AUDIT_LOG" || ! -f "$AUDIT_LOG" ]] && { echo "checkpoint: --audit-log <jsonl> required" >&2; exit 2; }
[[ -z "$OUT" ]] && { echo "checkpoint: --out <json> required" >&2; exit 2; }

AUDIT_LOG="$AUDIT_LOG" OUT="$OUT" node -e '
const fs = require("fs");
const crypto = require("crypto");
const lines = fs.readFileSync(process.env.AUDIT_LOG, "utf8").trim().split("\n").filter(Boolean);
const root = crypto.createHash("sha256").update(lines.join("\n")).digest("hex");
const checkpoint = {
  merkle_root: root,
  included_events: lines.length,
  generated_at: new Date().toISOString(),
};
fs.writeFileSync(process.env.OUT, JSON.stringify(checkpoint));
process.stderr.write(`checkpoint: merkle_root=${root} included_events=${lines.length}\n`);
'
