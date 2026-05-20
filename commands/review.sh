#!/usr/bin/env bash
# H-6 /review legacy shim — deprecated; forwards to /review-panel.
# Records the migration to .claude-tdd-pro/warnings.jsonl per the
# user-visible deprecation contract.
set -uo pipefail
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
mkdir -p .claude-tdd-pro
printf 'event=command-deprecation old=/review new=/review-panel at=%s\n' "$NOW" >> .claude-tdd-pro/warnings.jsonl
echo "review: deprecated — use /review-panel (this command forwards there)" >&2
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
exec bash "$SCRIPT_DIR/review-panel.sh" "$@"
