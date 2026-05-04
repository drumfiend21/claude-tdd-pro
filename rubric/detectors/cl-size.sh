#!/usr/bin/env bash
# cl-size.sh — flag a CL that exceeds Google's small-CL guideline.
#
# Per docs/standards/google-eng-practices.md#size--scope-rules:
#   - ~100 lines is fine
#   - ~1000 lines is usually too large
#   - We default to 400 added+removed lines as the soft cap
#
# Inputs (from runner.sh env):
#   RULE_ID, SEVERITY, MODE
# Output: one JSON-line finding per violation.

set -uo pipefail
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
RULE_ID="${RULE_ID:-g-eng-004-cl-size}"
SEVERITY="${SEVERITY:-P1}"
MAX="${1:-400}"

# Use staged diff if anything is staged; otherwise diff against HEAD.
if git -C "$PROJECT_DIR" diff --cached --quiet 2>/dev/null; then
  diff_args=( "HEAD" )
else
  diff_args=( "--cached" )
fi

stats="$(git -C "$PROJECT_DIR" diff "${diff_args[@]}" --shortstat 2>/dev/null || true)"
[[ -z "$stats" ]] && exit 0

# stats looks like: " 3 files changed, 240 insertions(+), 12 deletions(-)"
ins="$(echo "$stats" | grep -oE '[0-9]+ insertion' | grep -oE '^[0-9]+' || echo 0)"
dels="$(echo "$stats" | grep -oE '[0-9]+ deletion' | grep -oE '^[0-9]+' || echo 0)"
total=$(( ins + dels ))

if (( total > MAX )); then
  msg="diff is ${total} lines (cap=${MAX}) — split per google-eng-practices small-CL rule"
  printf '{"rule":"%s","severity":"%s","file":"","line":0,"msg":"%s"}\n' \
    "$RULE_ID" "$SEVERITY" "$msg"
fi
