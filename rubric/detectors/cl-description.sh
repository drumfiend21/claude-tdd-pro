#!/usr/bin/env bash
# cl-description.sh — verify the staged commit message matches Google's
# CL-description shape: imperative summary <= 72 chars + blank line +
# body. Per docs/standards/google-eng-practices.md#clpr-description-format

set -uo pipefail
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
RULE_ID="${RULE_ID:-g-eng-005-cl-description-shape}"
SEVERITY="${SEVERITY:-P1}"

emit() {
  local msg="$1"
  printf '{"rule":"%s","severity":"%s","file":"","line":0,"msg":"%s"}\n' \
    "$RULE_ID" "$SEVERITY" "${msg//\"/\\\"}"
}

# Use the prepared commit-msg if present (during a commit hook); else
# the most recent commit message.
if [[ -f "$PROJECT_DIR/.git/COMMIT_EDITMSG" && -s "$PROJECT_DIR/.git/COMMIT_EDITMSG" ]]; then
  msg_text="$(cat "$PROJECT_DIR/.git/COMMIT_EDITMSG")"
else
  msg_text="$(git -C "$PROJECT_DIR" log -1 --pretty=%B 2>/dev/null || true)"
fi
[[ -z "$msg_text" ]] && exit 0

first_line="$(echo "$msg_text" | sed -n '1p')"
second_line="$(echo "$msg_text" | sed -n '2p')"
third_line="$(echo "$msg_text" | sed -n '3p')"

# 1. First line length cap (Google says "short, focused"; 72 is the
#    widely accepted cap that keeps `git log` readable).
len="${#first_line}"
if (( len > 72 )); then
  emit "subject is ${len} chars (cap 72) — shorten per Google CL-description rule"
fi

# 2. Imperative mood — heuristic: reject leading -ing gerunds and
#    "Fixed/Added/Removed" past-tense.
if echo "$first_line" | grep -qE '^[A-Za-z]+ing\b' ; then
  emit "subject begins with a gerund; rewrite in imperative mood"
fi
if echo "$first_line" | grep -qE '^(Fixed|Added|Removed|Updated|Changed)\b' ; then
  emit "subject is past tense; use imperative ('Fix' not 'Fixed')"
fi

# 3. Vacuous subjects.
case "$first_line" in
  "Fix bug"|"WIP"|"wip"|"Update"|"Phase 1"|"Phase 2") emit "subject is uninformative ('$first_line')" ;;
esac

# 4. Blank-line separator after subject.
if [[ -n "$second_line" ]]; then
  emit "missing blank line after subject (line 2 must be empty)"
fi

# 5. Require a body (the "why") — Google rejects empty bodies.
if [[ -z "$third_line" && "$(echo "$msg_text" | wc -l | tr -d ' ')" -lt 3 ]]; then
  emit "missing body — explain WHY this change, not just WHAT"
fi
