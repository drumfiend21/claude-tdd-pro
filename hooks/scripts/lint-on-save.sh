#!/usr/bin/env bash
# PostToolUse hook: lint the file just edited/written.
#
# Behavior: read the tool input from stdin (JSON), find the edited
# file path, run the project's eslint against it. Exits 0 unless lint
# fails — in which case exits 2 to surface the error to the model.
#
# Scope: only acts on JS/TS/JSX/TSX/PY files. Other file types pass
# through silently.
#
# Tolerance: only blocks on ERRORS, not warnings. Pre-existing warnings
# in the codebase shouldn't make every edit fail.
#
# Skips when:
#   - No project-level lint config exists (don't impose on projects
#     that don't use lint).
#   - File path can't be parsed from input.
#   - File doesn't exist (e.g., was just deleted).

set -euo pipefail

# Read JSON input from stdin
INPUT="$(cat)"

# Extract file path from typical PostToolUse input shape:
# { "tool_input": { "file_path": "..." }, ... }
# We try a few likely keys.
FILE=$(printf '%s' "$INPUT" | jq -r '
  .tool_input.file_path
  // .tool_input.path
  // .tool_input.notebook_path
  // empty
' 2>/dev/null || true)

if [[ -z "$FILE" ]]; then
  exit 0
fi
if [[ ! -f "$FILE" ]]; then
  exit 0
fi

# Only act on supported extensions
case "$FILE" in
  *.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs)
    LANG="js"
    ;;
  *.py)
    LANG="py"
    ;;
  *)
    exit 0
    ;;
esac

# Find project root (first dir containing package.json or pyproject.toml,
# walking up from the file).
DIR=$(dirname "$FILE")
PROJECT_ROOT=""
while [[ "$DIR" != "/" && "$DIR" != "." ]]; do
  if [[ -f "$DIR/package.json" || -f "$DIR/pyproject.toml" ]]; then
    PROJECT_ROOT="$DIR"
    break
  fi
  DIR=$(dirname "$DIR")
done

if [[ -z "$PROJECT_ROOT" ]]; then
  exit 0
fi

cd "$PROJECT_ROOT"

if [[ "$LANG" == "js" ]]; then
  # Only run if the project has eslint installed and a config exists.
  if [[ ! -f "eslint.config.js" && ! -f ".eslintrc.json" && ! -f ".eslintrc.js" ]]; then
    exit 0
  fi
  if [[ ! -d "node_modules/eslint" ]]; then
    exit 0
  fi

  # Run eslint with --max-warnings=Infinity (only block on real errors).
  OUTPUT=$(npx eslint "$FILE" 2>&1) || EC=$?
  EC=${EC:-0}

  if [[ $EC -ne 0 ]]; then
    # Surface the lint error to the model via stderr + exit 2.
    echo "[lint-on-save] eslint reported errors in $FILE:" >&2
    echo "$OUTPUT" >&2
    exit 2
  fi
fi

if [[ "$LANG" == "py" ]]; then
  # Only run if ruff is available (preferred) or flake8 as fallback.
  if command -v ruff >/dev/null 2>&1; then
    OUTPUT=$(ruff check "$FILE" 2>&1) || EC=$?
    EC=${EC:-0}
  elif command -v flake8 >/dev/null 2>&1; then
    OUTPUT=$(flake8 "$FILE" 2>&1) || EC=$?
    EC=${EC:-0}
  else
    exit 0
  fi

  if [[ $EC -ne 0 ]]; then
    echo "[lint-on-save] linter reported errors in $FILE:" >&2
    echo "$OUTPUT" >&2
    exit 2
  fi
fi

exit 0
