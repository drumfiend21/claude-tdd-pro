#!/usr/bin/env bash
# tests-coupled.sh — Google eng-practices: tests in the SAME CL as
# behavior change, not a follow-up. We approximate "behavior change"
# as edits to non-test source files; if any such file is touched and
# no test file is touched in the same diff, flag it.
#
# Excludes pure docs / config / generated changes.

set -uo pipefail
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
RULE_ID="${RULE_ID:-g-eng-003-tests-with-change}"
SEVERITY="${SEVERITY:-P0}"

emit() {
  local msg="$1"
  printf '{"rule":"%s","severity":"%s","file":"","line":0,"msg":"%s"}\n' \
    "$RULE_ID" "$SEVERITY" "${msg//\"/\\\"}"
}

# Use staged diff if anything is staged; else uncommitted vs HEAD.
if git -C "$PROJECT_DIR" diff --cached --quiet 2>/dev/null; then
  diff_args=( "HEAD" )
else
  diff_args=( "--cached" )
fi

changed="$(git -C "$PROJECT_DIR" diff "${diff_args[@]}" --name-only 2>/dev/null || true)"
[[ -z "$changed" ]] && exit 0

src_changed=0
test_changed=0
behavior_files=""

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  case "$f" in
    *.test.ts|*.test.tsx|*.test.js|*.test.jsx|*.spec.ts|*.spec.tsx|*.spec.js|*.spec.jsx) test_changed=1 ;;
    test_*.py|*_test.py|tests/*) test_changed=1 ;;
    *.md|*.json|*.yaml|*.yml|*.toml|*.lock|*.txt|*.cfg|*.ini|.gitignore|.gitattributes) ;;  # docs/config: ignore
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.py|*.go|*.java|*.rs|*.rb)
      src_changed=1; behavior_files+="${f}, " ;;
    *) ;;
  esac
done <<< "$changed"

if (( src_changed == 1 && test_changed == 0 )); then
  emit "behavior changed in source (${behavior_files%, }) but no test files in same diff (Google eng-practices: tests-with-change)"
fi
