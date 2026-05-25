#!/usr/bin/env bash
# compliance/audit-recover.sh — audit log recovery.
#
# Two invocation modes:
#   C-4 legacy:   --truncate-to-last-checkpoint
#       Reads `.claude-tdd-pro/audit.jsonl` + latest checkpoint under
#       `compliance/audit-checkpoints/`, truncates the log to the
#       checkpoint's `last_line_number`. Used to repair a tampered or
#       corrupted log.
#   O-5 replay:   --checkpoint-dir <dir> --signing-stub <expected> --out <file>
#       Walks signed checkpoints in chronological order, verifies each
#       `signature` against the expected stub, and replays the verified
#       checkpoints' `events` arrays into --out. Reconstructs the audit
#       log up to the last verified checkpoint.
set -uo pipefail

MODE=""
CHECKPOINT_DIR=""
STUB=""
OUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --truncate-to-last-checkpoint) MODE="truncate"; shift ;;
    --checkpoint-dir) CHECKPOINT_DIR="$2"; MODE="${MODE:-replay}"; shift 2 ;;
    --signing-stub) STUB="$2"; MODE="${MODE:-replay}"; shift 2 ;;
    --out) OUT="$2"; MODE="${MODE:-replay}"; shift 2 ;;
    -h|--help)
      echo "Usage: audit-recover.sh (--truncate-to-last-checkpoint | --checkpoint-dir <dir> --signing-stub <expected> --out <file>)" >&2
      exit 0
      ;;
    *) echo "audit-recover: unknown flag: $1" >&2; exit 2 ;;
  esac
done

if [[ "$MODE" = "truncate" ]]; then
  LOG_PATH=".claude-tdd-pro/audit.jsonl"
  CKPT_DIR="compliance/audit-checkpoints"
  [[ ! -f "$LOG_PATH" ]] && { echo "audit-recover: no log to recover" >&2; exit 0; }
  [[ ! -d "$CKPT_DIR" ]] && { echo "audit-recover: no checkpoints" >&2; exit 0; }
  LATEST=$(ls "$CKPT_DIR"/*.json 2>/dev/null | sort | tail -1)
  [[ -z "$LATEST" ]] && { echo "audit-recover: no checkpoint files" >&2; exit 0; }
  LAST_LINE=$(node -e 'const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));process.stdout.write(String(j.last_line_number||0))' "$LATEST")
  [[ -z "$LAST_LINE" ]] && { echo "audit-recover: checkpoint missing last_line_number" >&2; exit 1; }
  head -n "$LAST_LINE" "$LOG_PATH" > "$LOG_PATH.tmp" && mv "$LOG_PATH.tmp" "$LOG_PATH"
  echo "audit-recover: truncated log to $LAST_LINE lines (per checkpoint $LATEST)" >&2
  exit 0
fi

if [[ "$MODE" = "replay" ]]; then
  [[ -z "$CHECKPOINT_DIR" || ! -d "$CHECKPOINT_DIR" ]] && { echo "audit-recover: --checkpoint-dir <dir> required" >&2; exit 2; }
  [[ -z "$OUT" ]] && { echo "audit-recover: --out <file> required" >&2; exit 2; }
  : > "$OUT"
  ORDER=$(for f in "$CHECKPOINT_DIR"/checkpoint-*.json; do [[ -f "$f" ]] && echo "$f"; done | sort -t- -k2 -n)
  for f in $ORDER; do
    CHECKPOINT="$f" STUB="$STUB" OUT="$OUT" node -e '
const fs = require("fs");
const ck = JSON.parse(fs.readFileSync(process.env.CHECKPOINT, "utf8"));
if (String(ck.signature || "") !== process.env.STUB) {
  process.stderr.write("recover: skip "+process.env.CHECKPOINT+" signature_invalid\n");
  process.exit(0);
}
const events = ck.events || [];
for (const ev of events) {
  fs.appendFileSync(process.env.OUT, JSON.stringify(ev) + "\n");
}
process.stderr.write("recover: replayed events="+events.length+" from="+process.env.CHECKPOINT+"\n");
'
  done
  echo "audit-recover: done out=$OUT" >&2
  exit 0
fi

echo "audit-recover: one of --truncate-to-last-checkpoint or --checkpoint-dir/--out required" >&2
exit 2
