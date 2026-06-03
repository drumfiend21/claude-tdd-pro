#!/usr/bin/env bash
# One-command installer for Claude TDD Pro.
#
# Usage from a project root:
#   curl -fsSL https://raw.githubusercontent.com/drumfiend21/claude-tdd-pro/main/scripts/install.sh | bash
# Or locally if the repo is already cloned:
#   bash scripts/install.sh [--target <app-dir>] [--with-grok] [--with-lsp]
#
# Does (in parallel where safe):
#   1. Clones / updates ~/.claude-tdd-pro (and optionally ~/.grok-claude-tdd-pro)
#   2. Installs hooks into <target>/.claude/settings.json
#   3. Exports Cursor rules to <target>/
#   4. Writes a default profile
#   5. (Optional) Symlinks LSP binary to ~/.local/bin
#   6. Skips the cold rubric suite — runs it in the background after setup
#      so the operator can start coding immediately.
#
# Target: 2 minutes wall-clock on a normal connection.

set -uo pipefail

TARGET="$(pwd)"
WITH_GROK=0
WITH_LSP=0
PROFILE="standard"
CLONE_DIR="$HOME/.claude-tdd-pro"
GROK_DIR="$HOME/.grok-claude-tdd-pro"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --with-grok) WITH_GROK=1; shift ;;
    --with-lsp) WITH_LSP=1; shift ;;
    --profile) PROFILE="$2"; shift 2 ;;
    -h|--help)
      cat <<USAGE
Usage: install.sh [--target <app-dir>] [--with-grok] [--with-lsp] [--profile <name>]

  --target <dir>     Project directory to wire up (default: cwd)
  --with-grok        Also install grok-claude-tdd-pro harness alongside
  --with-lsp         Symlink lsp/tdd-pro-lsp/tdd-pro-lsp into ~/.local/bin
  --profile <name>   Default profile (default: standard)

The cold rubric suite is run in the background after setup completes.
Watch ~/.claude-tdd-pro-install.log if you want to see progress.
USAGE
      exit 0 ;;
    *) echo "install: unknown flag: $1" >&2; exit 2 ;;
  esac
done

log() { printf '[install] %s\n' "$*" >&2; }

# Step 1 — clone or update plugin(s) in parallel.
log "fetching plugin(s)..."
{
  if [[ -d "$CLONE_DIR/.git" ]]; then
    git -C "$CLONE_DIR" pull --ff-only --quiet origin main || true
  else
    git clone --quiet --depth 1 https://github.com/drumfiend21/claude-tdd-pro.git "$CLONE_DIR"
  fi
} &
PID_PLUGIN=$!

if [[ "$WITH_GROK" -eq 1 ]]; then
  {
    if [[ -d "$GROK_DIR/.git" ]]; then
      git -C "$GROK_DIR" pull --ff-only --quiet origin main || true
    else
      git clone --quiet --depth 1 https://github.com/drumfiend21/grok-claude-tdd-pro.git "$GROK_DIR"
    fi
  } &
  PID_GROK=$!
fi

wait "$PID_PLUGIN"
[[ "$WITH_GROK" -eq 1 ]] && wait "$PID_GROK"

export CLAUDE_PLUGIN_ROOT="$CLONE_DIR"
log "plugin at $CLONE_DIR"
[[ "$WITH_GROK" -eq 1 ]] && log "grok harness at $GROK_DIR"

# Step 2 — install hooks (no dry-run prompt — fast path)
mkdir -p "$TARGET/.claude"
bash "$CLONE_DIR/commands/install-hooks.sh" --scope project --settings-path "$TARGET/.claude/settings.json" >/dev/null 2>&1 || {
  log "hooks install failed; check $TARGET/.claude/settings.json"
}
log "hooks installed at $TARGET/.claude/settings.json"

# Step 3 — export Cursor rules
bash "$CLONE_DIR/commands/export-rules.sh" --target "$TARGET/.cursorrules" >/dev/null 2>&1 || {
  log "cursor rule export failed; you can re-run: $CLONE_DIR/commands/export-rules.sh cursor --out $TARGET"
}
log "cursor rules at $TARGET/.cursorrules"

# Step 4 — profile
mkdir -p "$TARGET/.claude-tdd-pro"
[[ ! -f "$TARGET/.claude-tdd-pro/userConfig.yaml" ]] && printf 'profile: %s\n' "$PROFILE" > "$TARGET/.claude-tdd-pro/userConfig.yaml"
log "profile: $PROFILE (edit $TARGET/.claude-tdd-pro/userConfig.yaml to change)"

# Step 5 — (Optional) LSP symlink
if [[ "$WITH_LSP" -eq 1 ]]; then
  mkdir -p "$HOME/.local/bin"
  ln -sf "$CLONE_DIR/lsp/tdd-pro-lsp/tdd-pro-lsp" "$HOME/.local/bin/tdd-pro-lsp"
  log "LSP binary at $HOME/.local/bin/tdd-pro-lsp (ensure ~/.local/bin is on PATH)"
fi

# Step 6 — (Optional) sync grok harness pin
if [[ "$WITH_GROK" -eq 1 ]]; then
  log "syncing grok harness plugin cache..."
  (cd "$GROK_DIR" && bash scripts/sync-plugin.sh --ensure >/dev/null 2>&1) || {
    log "grok sync-plugin failed; run manually: cd $GROK_DIR && ./scripts/sync-plugin.sh --ensure"
  }
fi

# Step 7 — kick off the cold rubric suite in the background.
log "starting background suite verification (writes to ~/.claude-tdd-pro-install.log)..."
( bash "$CLONE_DIR/evals/runner.sh" >"$HOME/.claude-tdd-pro-install.log" 2>&1 ) &

cat <<DONE >&2

[install] ✓ ready in $(($SECONDS))s — open $TARGET in Cursor and start coding.

Verify later (background suite results):
  tail -1 ~/.claude-tdd-pro-install.log

Useful commands:
  bash \$CLAUDE_PLUGIN_ROOT/commands/doctor.sh           # health check
  bash \$CLAUDE_PLUGIN_ROOT/commands/space-report.sh     # SPACE dashboard
  bash \$CLAUDE_PLUGIN_ROOT/evals/runner.sh              # full suite
DONE
