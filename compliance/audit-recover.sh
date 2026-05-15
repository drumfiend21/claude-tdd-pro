#!/usr/bin/env bash
# compliance/audit-recover.sh — C-4 audit log recovery per §16:
# "compliance/audit-recover.sh".
#
# Truncates .claude-tdd-pro/audit.jsonl to the line count recorded in
# the latest checkpoint under compliance/audit-checkpoints/. Used to
# repair a tampered/corrupted log.
#
# Usage:
#   audit-recover.sh --truncate-to-last-checkpoint

set -uo pipefail

MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --truncate-to-last-checkpoint) MODE="truncate"; shift ;;
    *) echo "audit-recover: unknown flag: $1" >&2; exit 2 ;;
  esac
done
[[ "$MODE" != "truncate" ]] && { echo "audit-recover: --truncate-to-last-checkpoint required" >&2; exit 2; }

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
