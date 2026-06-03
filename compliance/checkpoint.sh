#!/usr/bin/env bash
# Merkle-chain checkpoint emitter.
#
# Two invocation modes:
#   L-14 single-file:    --audit-log <jsonl> --out <json>
#       writes one checkpoint.json with merkle_root + included_events.
#   O-5 directory:       --audit-log <jsonl> --checkpoint-dir <dir>
#                        [--interval N] [--signing-stub T] [--now ISO]
#                        [--record-in-log]
#       writes <dir>/checkpoint-<N>.json (N = entry count) with
#       merkle_root + signature + included_events + interval +
#       computed_at + events; optionally appends a checkpoint-event
#       back to the audit-log itself.
set -uo pipefail

AUDIT_LOG=""
OUT=""
CHECKPOINT_DIR=""
INTERVAL=100
SIGNING_STUB=""
NOW=""
RECORD_IN_LOG=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --audit-log) AUDIT_LOG="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --checkpoint-dir) CHECKPOINT_DIR="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --signing-stub) SIGNING_STUB="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    --record-in-log) RECORD_IN_LOG=1; shift ;;
    -h|--help)
      echo "Usage: checkpoint.sh --audit-log <jsonl> (--out <json> | --checkpoint-dir <dir>) [--interval N] [--signing-stub T] [--now ISO] [--record-in-log]" >&2
      exit 0
      ;;
    *) shift ;;
  esac
done

[[ -z "$AUDIT_LOG" || ! -f "$AUDIT_LOG" ]] && { echo "checkpoint: --audit-log <jsonl> required" >&2; exit 2; }

if [[ -n "$OUT" && -z "$CHECKPOINT_DIR" ]]; then
  # L-14 single-file mode (legacy).
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
  exit $?
fi

[[ -z "$CHECKPOINT_DIR" ]] && { echo "checkpoint: --out <json> or --checkpoint-dir <dir> required" >&2; exit 2; }
[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

mkdir -p "$CHECKPOINT_DIR"
COUNT=$(wc -l < "$AUDIT_LOG" | tr -d ' ')
CHECKPOINT_OUT="$CHECKPOINT_DIR/checkpoint-${COUNT}.json"

AUDIT_LOG="$AUDIT_LOG" CHECKPOINT_OUT="$CHECKPOINT_OUT" SIGNING_STUB="$SIGNING_STUB" COUNT="$COUNT" INTERVAL="$INTERVAL" NOW="$NOW" node -e '
const fs = require("fs");
const crypto = require("crypto");
const log = fs.readFileSync(process.env.AUDIT_LOG, "utf8");
const lines = log.split("\n").filter(s => s.length > 0);
const events = lines.map(l => { try { return JSON.parse(l); } catch (e) { return { raw: l }; } });
const merkleRoot = crypto.createHash("sha256").update(events.map(e => JSON.stringify(e)).join("\n")).digest("hex");
const checkpoint = {
  merkle_root: merkleRoot,
  signature: process.env.SIGNING_STUB || "",
  included_events: Number(process.env.COUNT),
  interval: Number(process.env.INTERVAL),
  computed_at: process.env.NOW,
  events: events,
};
fs.writeFileSync(process.env.CHECKPOINT_OUT, JSON.stringify(checkpoint));
'

if [[ "$RECORD_IN_LOG" -eq 1 ]]; then
  printf '{"event":"checkpoint","at":"%s","ref":"%s"}\n' "$NOW" "$(basename "$CHECKPOINT_OUT")" >> "$AUDIT_LOG"
fi

echo "checkpoint: emitted=$CHECKPOINT_OUT included_events=$COUNT interval=$INTERVAL" >&2
