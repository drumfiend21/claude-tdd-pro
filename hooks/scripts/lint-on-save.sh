#!/usr/bin/env bash
# PostToolUse hook: lint the file just edited/written.
#
# SECURITY MODEL
# --------------
# This hook runs after every model-driven Edit/Write. The model can
# write arbitrary file paths and contents, including malicious ones.
# We must NOT execute any code outside the user's intended workspace.
#
# Defenses:
#   1. Reject paths outside CLAUDE_PROJECT_DIR / pwd.
#   2. Reject if any ancestor up to the workspace root is a symlink
#      (prevents /tmp/evil/.../safe.js → real path elsewhere attacks).
#   3. Skip vendor / build / VCS directories outright.
#   4. Use the project-local resolved binary, never `npx` (which would
#      install + execute attacker-controlled packages on registry
#      compromise or local-install miss).
#   5. Hard timeout via the harness (10s, set in hooks.json).
#   6. Validate the extracted path matches a strict character allowlist.
#
# Failure mode: any defense-trip is a silent exit 0. We never block
# the model on lint configuration issues. Only real lint ERRORS
# (eslint exit non-zero with output) surface to the model via exit 2.

set -uo pipefail   # NO `-e` here — we manage exit codes explicitly
                    # (see "broken set -e + ||" footgun in security audit)

# ─── 1. Read JSON input from stdin ──────────────────────────────
INPUT="$(cat)"

# Use Node (already required for ESLint) instead of jq — avoids the
# hard `jq` dependency that silently no-oped on macOS without it.
if ! command -v node >/dev/null 2>&1; then
  exit 0
fi

FILE=$(printf '%s' "$INPUT" | node -e '
  let raw = "";
  process.stdin.on("data", c => raw += c);
  process.stdin.on("end", () => {
    try {
      const j = JSON.parse(raw);
      const p = j.tool_input?.file_path
              || j.tool_input?.path
              || j.tool_input?.notebook_path
              || "";
      // Strict allowlist on the extracted path. Reject anything with
      // shell metacharacters / control bytes.
      if (!/^[A-Za-z0-9._/\-~ ]+$/.test(p)) { process.exit(0); }
      process.stdout.write(p);
    } catch { process.exit(0); }
  });
' 2>/dev/null)

[[ -z "$FILE" ]] && exit 0
[[ ! -f "$FILE" ]] && exit 0

# ─── 2. Skip vendor / build / VCS dirs early ────────────────────
case "$FILE" in
  */node_modules/*|*/.git/*|*/dist/*|*/build/*|*/.next/*|*/coverage/*|*/.cache/*|*/vendor/*|*/__pycache__/*|*/.venv/*)
    exit 0
    ;;
esac

# ─── 3. Only act on supported extensions ────────────────────────
case "$FILE" in
  *.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs) LANG="js" ;;
  *.py)                              LANG="py" ;;
  *)                                 exit 0    ;;
esac

# ─── 4. Determine workspace root + sanity check ─────────────────
# Prefer CLAUDE_PROJECT_DIR (set by harness); fall back to PWD.
WORKSPACE="${CLAUDE_PROJECT_DIR:-$PWD}"

# Resolve real (symlink-followed) paths, then assert containment.
REAL_WS=$(cd "$WORKSPACE" 2>/dev/null && pwd -P) || exit 0
REAL_DIR=$(cd "$(dirname "$FILE")" 2>/dev/null && pwd -P) || exit 0
REAL_FILE="$REAL_DIR/$(basename "$FILE")"

case "$REAL_FILE" in
  "$REAL_WS"/*) ;;     # OK: inside workspace
  *)            exit 0 ;;
esac

# ─── 5. Reject if any ancestor up to workspace is a symlink ─────
# A symlinked ancestor means the path containment check above can
# be tricked by following the link to an attacker-controlled location.
p="$REAL_FILE"
while [[ "$p" != "$REAL_WS" && "$p" != "/" && -n "$p" ]]; do
  if [[ -L "$p" ]]; then exit 0; fi
  p=$(dirname "$p")
done

# ─── 6. Find project root (package.json or pyproject.toml) ──────
DIR="$REAL_DIR"
PROJECT_ROOT=""
while [[ "$DIR" != "$REAL_WS/.." && "$DIR" != "/" && -n "$DIR" ]]; do
  if [[ -f "$DIR/package.json" || -f "$DIR/pyproject.toml" ]]; then
    PROJECT_ROOT="$DIR"
    break
  fi
  DIR=$(dirname "$DIR")
done

[[ -z "$PROJECT_ROOT" ]] && exit 0

# ─── 7. Run linter ──────────────────────────────────────────────
if [[ "$LANG" == "js" ]]; then
  # Skip if no eslint config or no installed eslint binary.
  CONFIG=""
  for c in eslint.config.js eslint.config.mjs eslint.config.cjs .eslintrc.json .eslintrc.js .eslintrc.cjs .eslintrc.yaml .eslintrc.yml; do
    if [[ -f "$PROJECT_ROOT/$c" ]]; then CONFIG="$c"; break; fi
  done
  [[ -z "$CONFIG" ]] && exit 0

  ESLINT_BIN="$PROJECT_ROOT/node_modules/.bin/eslint"
  [[ ! -x "$ESLINT_BIN" ]] && exit 0  # never `npx`; that's the RCE vector

  CACHE_DIR="$PROJECT_ROOT/node_modules/.cache/claude-tdd-pro/eslint/"
  mkdir -p "$CACHE_DIR" 2>/dev/null || true

  # Use the project-local resolved binary directly. Run from project
  # root (cd is now safe — root is identified by package.json existence
  # AND we already proved REAL_FILE is inside REAL_WS).
  cd "$PROJECT_ROOT" || exit 0

  set +e
  OUTPUT=$("$ESLINT_BIN" --cache --cache-location "$CACHE_DIR" "$REAL_FILE" 2>&1)
  EC=$?
  set -e

  if [[ $EC -ne 0 ]]; then
    {
      echo "[lint-on-save] eslint reported errors in:"
      echo "  $REAL_FILE"
      echo
      echo "$OUTPUT"
    } >&2
    exit 2
  fi
fi

if [[ "$LANG" == "py" ]]; then
  # Prefer ruff (faster, modern); fall back to flake8.
  if command -v ruff >/dev/null 2>&1; then
    cd "$PROJECT_ROOT" || exit 0
    set +e
    OUTPUT=$(ruff check "$REAL_FILE" 2>&1)
    EC=$?
    set -e
  elif command -v flake8 >/dev/null 2>&1; then
    cd "$PROJECT_ROOT" || exit 0
    set +e
    OUTPUT=$(flake8 "$REAL_FILE" 2>&1)
    EC=$?
    set -e
  else
    exit 0
  fi

  if [[ $EC -ne 0 ]]; then
    {
      echo "[lint-on-save] python linter reported errors in:"
      echo "  $REAL_FILE"
      echo
      echo "$OUTPUT"
    } >&2
    exit 2
  fi
fi

exit 0
