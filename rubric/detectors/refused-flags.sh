#!/usr/bin/env bash
# refused-flags.sh — flag any committed/staged content containing
# explicitly refused command-line flags. These belong to the
# "reject-bad-tooling" skill. Per skills/reject-bad-tooling/SKILL.md.

set -uo pipefail
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
RULE_ID="${RULE_ID:-g-sec-002-no-dangerously-skip-permissions}"
SEVERITY="${SEVERITY:-P0}"

# Patterns that indicate the agent (or a config) is reaching for a
# refused tool.
patterns=(
  '--dangerously-skip-permissions'
  '--no-verify'
  'npm audit fix --force'
)

if git -C "$PROJECT_DIR" diff --cached --quiet 2>/dev/null; then
  diff_args=( "HEAD" )
else
  diff_args=( "--cached" )
fi

diff_text="$(git -C "$PROJECT_DIR" diff "${diff_args[@]}" 2>/dev/null || true)"
[[ -z "$diff_text" ]] && exit 0

added="$(echo "$diff_text" | grep -E '^\+' | grep -v '^\+\+\+' || true)"

for p in "${patterns[@]}"; do
  if echo "$added" | grep -qF "$p"; then
    msg="diff introduces refused pattern: $p"
    printf '{"rule":"%s","severity":"%s","file":"","line":0,"msg":"%s"}\n' \
      "$RULE_ID" "$SEVERITY" "${msg//\"/\\\"}"
  fi
done
