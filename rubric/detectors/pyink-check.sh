#!/usr/bin/env bash
# pyink-check.sh — verify Python files match the google/pyink formatter.
# Skips silently if pyink (or black, as a near-equivalent fallback) is
# not installed.

set -uo pipefail
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
RULE_ID="${RULE_ID:-g-py-010-format-pyink}"
SEVERITY="${SEVERITY:-P1}"

emit_skip() {
  printf '{"rule":"%s","severity":"SKIP","file":"","line":0,"msg":"%s"}\n' "$RULE_ID" "$1"
}

if command -v pyink >/dev/null 2>&1; then
  fmt="pyink"
elif command -v black >/dev/null 2>&1; then
  fmt="black"
else
  emit_skip "pyink/black not installed"
  exit 0
fi

py_files="$(git -C "$PROJECT_DIR" ls-files '*.py' 2>/dev/null | head -200)"
[[ -z "$py_files" ]] && exit 0

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  if ! "$fmt" --check --quiet "${PROJECT_DIR}/${f}" 2>/dev/null; then
    msg="not formatted by ${fmt}"
    printf '{"rule":"%s","severity":"%s","file":"%s","line":0,"msg":"%s"}\n' \
      "$RULE_ID" "$SEVERITY" "$f" "$msg"
  fi
done <<< "$py_files"
