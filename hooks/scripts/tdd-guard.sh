#!/usr/bin/env bash
# PreToolUse hook: TDD guard.
#
# Blocks Edit/Write to source files when no failing test names that
# file. Permits writes to: test files themselves, brand-new files
# (no equivalent test exists yet AND none should be expected for this
# file class), config files, docs, and anything outside the project's
# `src/` (or equivalent) directory.
#
# Activation control:
#   - Plugin-enabled by default (Google eng-practices treats
#     tests-with-change as mandatory; the plugin's default should match
#     the bar it claims to enforce). Opt out per-project by creating
#     `.claude-tdd-pro/tdd-guard.disabled`, or set
#     CLAUDE_TDD_PRO_GUARD=off in env.
#   - The /tdd-guard slash command toggles this.
#
# Detection logic:
#   - Looks for `.claude-tdd-pro/last-test-run.json` written by a test
#     reporter (or by the user's own pre-edit `npm test`).
#   - If absent OR all tests passing, BLOCK with guidance.
#   - If a failing test names the file (heuristic: failing test path
#     mirrors the source file path), ALLOW.
#   - Test files / config / docs / first-time creation: ALLOW.

set -uo pipefail

# W-8 flag-style invocation: --feature-id + --tdd-state mode (PreToolUse on
# commit). This branch is exclusive: if any of the W-8 flags is present we
# do not consume stdin. The legacy Edit/Write hook below still reads stdin.
if [[ "${1:-}" == "--feature-id" ]] || [[ "${1:-}" == "--root" ]] || [[ "${1:-}" == "--tdd-state" ]] || [[ "${1:-}" == "--allow-red-test" ]]; then
  FEATURE_ID=""; TDD_STATE=""; ROOT=""; ALLOW_RED=0; AUDIT_LOG=""; OPERATOR=""; NOW=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --feature-id) FEATURE_ID="$2"; shift 2 ;;
      --tdd-state) TDD_STATE="$2"; shift 2 ;;
      --root) ROOT="$2"; shift 2 ;;
      --allow-red-test) ALLOW_RED=1; shift ;;
      --audit-log) AUDIT_LOG="$2"; shift 2 ;;
      --operator) OPERATOR="$2"; shift 2 ;;
      --now) NOW="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  [[ -z "$TDD_STATE" || ! -f "$TDD_STATE" ]] && { echo "tdd-guard: --tdd-state <json> required" >&2; exit 2; }

  # --allow-red-test bypass path: log to audit, allow commit.
  if [[ "$ALLOW_RED" -eq 1 ]]; then
    if [[ -n "$AUDIT_LOG" ]]; then
      mkdir -p "$(dirname "$AUDIT_LOG")"
      printf '{"event":"tdd-guard-bypass","feature_id":"%s","operator":"%s","at":"%s"}\n' "$FEATURE_ID" "$OPERATOR" "$NOW" >> "$AUDIT_LOG"
    fi
    echo "tdd-guard: commit_allowed feature_id=$FEATURE_ID bypass=true operator=$OPERATOR (logged to C-4 audit)" >&2
    exit 0
  fi

  # Inspect tdd-state: red_tests, regressions, scope drift.
  RED_COUNT=$(TDD_STATE="$TDD_STATE" node -e 'const j=JSON.parse(require("fs").readFileSync(process.env.TDD_STATE,"utf8"));process.stdout.write(String((j.red_tests||[]).length))')
  if [[ "$RED_COUNT" -gt 0 ]]; then
    echo "tdd-guard: commit_blocked feature_id=$FEATURE_ID red_tests_remaining=$RED_COUNT (TDD red phase still active)" >&2
    exit 2
  fi
  REGRESS=$(TDD_STATE="$TDD_STATE" node -e 'const j=JSON.parse(require("fs").readFileSync(process.env.TDD_STATE,"utf8"));process.stdout.write(((j.regressions||[])[0])||"")')
  if [[ -n "$REGRESS" ]]; then
    echo "tdd-guard: commit_blocked feature_id=$FEATURE_ID regression=$REGRESS (implementation broke a previously-green spec)" >&2
    exit 2
  fi
  UNDECLARED=$(TDD_STATE="$TDD_STATE" node -e '
    const j = JSON.parse(require("fs").readFileSync(process.env.TDD_STATE, "utf8"));
    const declared = new Set(j.declared_scope || []);
    const actual = j.actual_scope || [];
    for (const a of actual) if (!declared.has(a)) { process.stdout.write(a); process.exit(0); }
    process.stdout.write("");
  ')
  if [[ -n "$UNDECLARED" ]]; then
    echo "tdd-guard: commit_blocked feature_id=$FEATURE_ID scope_drift undeclared_path=$UNDECLARED (implementation touches paths outside W-7 declared scope)" >&2
    exit 2
  fi

  echo "tdd-guard: commit_allowed feature_id=$FEATURE_ID red_tests=0 regressions=0 scope=clean" >&2
  exit 0
fi

# Read JSON input
INPUT="$(cat)"

# Quick disable: no Node? no jq? — bail out without blocking.
if ! command -v node >/dev/null 2>&1; then exit 0; fi

# Extract file path
FILE=$(printf '%s' "$INPUT" | node -e '
  let raw = "";
  process.stdin.on("data", c => raw += c);
  process.stdin.on("end", () => {
    try {
      const j = JSON.parse(raw);
      const p = j.tool_input?.file_path || j.tool_input?.path || "";
      if (!/^[A-Za-z0-9._/\-~ ]+$/.test(p)) { process.exit(0); }
      process.stdout.write(p);
    } catch { process.exit(0); }
  });
' 2>/dev/null)

[[ -z "$FILE" ]] && exit 0

# Determine project root
WORKSPACE="${CLAUDE_PROJECT_DIR:-$PWD}"
DIR=$(cd "$(dirname "$FILE")" 2>/dev/null && pwd -P) || exit 0
WS=$(cd "$WORKSPACE" 2>/dev/null && pwd -P) || exit 0

# Activation gate — guard is ON by default (matches Google
# eng-practices "tests-with-change" requirement). Opt out per-project
# via .claude-tdd-pro/tdd-guard.disabled, or env CLAUDE_TDD_PRO_GUARD=off.
if [[ "${CLAUDE_TDD_PRO_GUARD:-}" == "off" ]]; then
  exit 0
fi
if [[ -f "$WS/.claude-tdd-pro/tdd-guard.disabled" ]]; then
  exit 0
fi

# ─── Permitted file classes (always allow) ─────────────────────
case "$FILE" in
  # Test files themselves
  *.test.*|*.spec.*|*_test.py|*/tests/*|*/__tests__/*|*/test/*)
    exit 0 ;;
  # Config files
  *.config.*|.eslintrc*|.prettierrc*|tsconfig*.json|vite.config.*|vitest.config.*|jest.config.*|package.json|pyproject.toml|requirements*.txt|*.toml|*.yaml|*.yml|*.json|*.lock)
    exit 0 ;;
  # Docs
  *.md|*.mdx|*.rst|*.txt|README*|CHANGELOG*|LICENSE*|CONTRIBUTING*|CLAUDE.md)
    exit 0 ;;
  # Build / vendor / VCS
  */node_modules/*|*/.git/*|*/dist/*|*/build/*|*/.next/*|*/coverage/*|*/__pycache__/*|*/.venv/*)
    exit 0 ;;
esac

# Only guard real source files
case "$FILE" in
  *.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs|*.py) ;;
  *) exit 0 ;;
esac

# ─── Brand-new file? (creation, not modification) ──────────────
if [[ ! -f "$FILE" ]]; then
  # New file. Allow — creation often happens before its test exists.
  # The full TDD discipline lives in the skill, not the hook.
  exit 0
fi

# ─── Look for a recent test run ──────────────────────────────────
LAST_RUN="$WS/.claude-tdd-pro/last-test-run.json"

if [[ ! -f "$LAST_RUN" ]]; then
  cat >&2 <<EOF
[tdd-guard] BLOCKING: no test run record found.

TDD discipline requires a failing test naming this file before edits.

To proceed:
  (a) Run your tests once: \`npm test\` (writes .claude-tdd-pro/last-test-run.json
      via the test-reporter setup), OR
  (b) Disable the guard for this session: rm .claude-tdd-pro/tdd-guard.enabled
      OR set CLAUDE_TDD_PRO_GUARD=off in env.

Context: this hook is triggered by claude-tdd-pro because the project
has tdd-guard.enabled. If you don't want strict enforcement, delete
that file or unset the env var.

File you tried to edit: $FILE
EOF
  exit 2
fi

# ─── Check: is there a failing test naming this file? ──────────
# Heuristic: failing test path contains the source file's basename
# (without extension), OR the failing test message references the file.
BASE=$(basename "$FILE")
NAME="${BASE%.*}"

GUARD_RESULT=$(node -e '
  const fs = require("fs");
  const lr = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
  const name = process.argv[2];
  const file = process.argv[3];
  const fails = (lr.failed || lr.failures || []);
  const matches = fails.some(f => {
    const s = JSON.stringify(f).toLowerCase();
    return s.includes(name.toLowerCase()) || s.includes(file.toLowerCase());
  });
  process.stdout.write(matches ? "ALLOW" : (fails.length ? "MISMATCH" : "ALL_GREEN"));
' "$LAST_RUN" "$NAME" "$FILE" 2>/dev/null) || GUARD_RESULT="UNKNOWN"

case "$GUARD_RESULT" in
  ALLOW) exit 0 ;;
  ALL_GREEN)
    cat >&2 <<EOF
[tdd-guard] BLOCKING: all tests pass.

TDD discipline: write a failing test that exercises the change you're
about to make, run it (confirm red), THEN edit production code.

File you tried to edit: $FILE

To proceed: write a test that fails for the change you intend, then
run \`npm test\` to refresh .claude-tdd-pro/last-test-run.json.
EOF
    exit 2
    ;;
  MISMATCH)
    cat >&2 <<EOF
[tdd-guard] BLOCKING: failing tests exist but none names this file.

Failing tests are present, but none of them mention '$NAME' or
'$FILE'. Either:
  - The test you're red-green'ing names a different file (write a
    test for THIS file instead), OR
  - The failing test references this file by an unusual identifier
    that the heuristic missed (rerun the test or rephrase the
    description), OR
  - You're fixing an unrelated bug — use /fix-bug instead of editing
    cold.

File you tried to edit: $FILE
EOF
    exit 2
    ;;
  *) exit 0 ;;  # parse error / unknown — fail open, don't block on bugs
esac
