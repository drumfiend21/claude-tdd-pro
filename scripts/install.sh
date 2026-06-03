#!/usr/bin/env bash
# Claude TDD Pro one-liner installer with interactive prompts.
#
# Usage (from any project root):
#   curl -fsSL https://raw.githubusercontent.com/drumfiend21/claude-tdd-pro/main/scripts/install.sh | bash
#
# Or download and run:
#   curl -fsSL .../install.sh -o /tmp/install.sh && bash /tmp/install.sh
#
# Prompts the operator for each decision (profile, harness, LSP, target).
# Defaults shown in brackets; press Enter to accept.
#
# Target wall-clock: <60 seconds to ready-in-Cursor.

set -uo pipefail

START_SECONDS=$SECONDS

CLONE_DIR="$HOME/.claude-tdd-pro"
GROK_DIR="$HOME/.grok-claude-tdd-pro"

# Detect TTY availability robustly. Three cases:
#  (a) stdin is a TTY → just read from stdin
#  (b) piped from curl but /dev/tty is a real terminal → use /dev/tty
#  (c) no TTY at all (CI, container) → defaults only
PROMPTS_AVAILABLE=0
READ_FROM=""
if [[ -t 0 ]]; then
  PROMPTS_AVAILABLE=1
  READ_FROM=""        # empty = read from stdin
elif [[ -e /dev/tty ]] && exec 3<>/dev/tty 2>/dev/null; then
  PROMPTS_AVAILABLE=1
  READ_FROM="/dev/fd/3"
fi

prompt() {
  local var_name="$1" question="$2" default="$3"
  local answer=""
  if [[ "$PROMPTS_AVAILABLE" -eq 1 ]]; then
    if [[ -n "$READ_FROM" ]]; then
      printf '%s [%s]: ' "$question" "$default" >&3
      IFS= read -r answer <&3 || answer=""
    else
      printf '%s [%s]: ' "$question" "$default" >&2
      IFS= read -r answer || answer=""
    fi
  fi
  [[ -z "$answer" ]] && answer="$default"
  printf -v "$var_name" '%s' "$answer"
}

prompt_yn() {
  local var_name="$1" question="$2" default="$3"   # default: y or n
  local answer=""
  local hint="[y/N]"
  [[ "$default" == "y" ]] && hint="[Y/n]"
  if [[ "$PROMPTS_AVAILABLE" -eq 1 ]]; then
    if [[ -n "$READ_FROM" ]]; then
      printf '%s %s: ' "$question" "$hint" >&3
      IFS= read -r answer <&3 || answer=""
    else
      printf '%s %s: ' "$question" "$hint" >&2
      IFS= read -r answer || answer=""
    fi
  fi
  [[ -z "$answer" ]] && answer="$default"
  case "${answer:0:1}" in y|Y) printf -v "$var_name" '1' ;; *) printf -v "$var_name" '0' ;; esac
}

# ──────────────────────────────────────────────────────────────────────
# Interactive prompts
# ──────────────────────────────────────────────────────────────────────

cat <<'BANNER' >&2
┌──────────────────────────────────────────────────────────────────┐
│  Claude TDD Pro installer                                        │
│  Target: <60s to ready-in-Cursor                                 │
└──────────────────────────────────────────────────────────────────┘
BANNER

prompt    TARGET       "Target project directory"                       "$(pwd)"
prompt    PROFILE      "Profile (standard|strict|financial|regulated|government|react|node|library)" "standard"
prompt_yn WITH_GROK    "Install grok-claude-tdd-pro harness (outer-loop research/decompose/dispatch)?" "n"
prompt_yn WITH_LSP     "Symlink LSP binary into ~/.local/bin (inline Cursor diagnostics)?"             "y"

# Confirm and go.
if [[ "$PROMPTS_AVAILABLE" -eq 1 ]]; then
  cat >&2 <<SUMMARY

Plan:
  target:    $TARGET
  profile:   $PROFILE
  grok:      $( [[ $WITH_GROK -eq 1 ]] && echo yes || echo no )
  lsp:       $( [[ $WITH_LSP  -eq 1 ]] && echo yes || echo no )

SUMMARY
  prompt_yn CONFIRM "Proceed?" "y"
  [[ "$CONFIRM" -eq 1 ]] || { echo "Aborted." >&2; exit 1; }
fi

# ──────────────────────────────────────────────────────────────────────
# Step 1 — parallel shallow clones (no .git history, blob-filter for speed)
# ──────────────────────────────────────────────────────────────────────

log() { printf '[install +%02ds] %s\n' "$(($SECONDS - $START_SECONDS))" "$*" >&2; }

log "fetching plugin..."
clone_one() {
  local url="$1" dest="$2"
  if [[ -d "$dest/.git" ]]; then
    git -C "$dest" pull --ff-only --quiet origin main 2>/dev/null || true
  else
    git clone --quiet --depth 1 --filter=blob:none "$url" "$dest" 2>/dev/null \
      || git clone --quiet --depth 1 "$url" "$dest"
  fi
}

clone_one https://github.com/drumfiend21/claude-tdd-pro.git "$CLONE_DIR" &
PID_PLUGIN=$!

if [[ "$WITH_GROK" -eq 1 ]]; then
  clone_one https://github.com/drumfiend21/grok-claude-tdd-pro.git "$GROK_DIR" &
  PID_GROK=$!
fi

wait "$PID_PLUGIN"
log "plugin at $CLONE_DIR"

if [[ "$WITH_GROK" -eq 1 ]]; then
  wait "$PID_GROK"
  log "grok harness at $GROK_DIR"
fi

export CLAUDE_PLUGIN_ROOT="$CLONE_DIR"

# ──────────────────────────────────────────────────────────────────────
# Step 2 — install hooks (non-interactive; --scope project)
# ──────────────────────────────────────────────────────────────────────

mkdir -p "$TARGET/.claude"
bash "$CLONE_DIR/commands/install-hooks.sh" --scope project --settings-path "$TARGET/.claude/settings.json" >/dev/null 2>&1 || \
  log "WARN hooks install failed; check $TARGET/.claude/settings.json"
log "hooks → $TARGET/.claude/settings.json"

# ──────────────────────────────────────────────────────────────────────
# Step 3 — export Cursor rules
# ──────────────────────────────────────────────────────────────────────

bash "$CLONE_DIR/commands/export-rules.sh" --target "$TARGET/.cursorrules" >/dev/null 2>&1 || \
  log "WARN cursor rule export failed"
log "rules → $TARGET/.cursorrules"

# ──────────────────────────────────────────────────────────────────────
# Step 4 — profile config
# ──────────────────────────────────────────────────────────────────────

mkdir -p "$TARGET/.claude-tdd-pro"
if [[ ! -f "$TARGET/.claude-tdd-pro/userConfig.yaml" ]]; then
  printf 'profile: %s\n' "$PROFILE" > "$TARGET/.claude-tdd-pro/userConfig.yaml"
fi
log "profile → $PROFILE"

# ──────────────────────────────────────────────────────────────────────
# Step 5 — LSP symlink
# ──────────────────────────────────────────────────────────────────────

if [[ "$WITH_LSP" -eq 1 ]]; then
  mkdir -p "$HOME/.local/bin"
  ln -sf "$CLONE_DIR/lsp/tdd-pro-lsp/tdd-pro-lsp" "$HOME/.local/bin/tdd-pro-lsp"
  log "lsp → $HOME/.local/bin/tdd-pro-lsp"
fi

# ──────────────────────────────────────────────────────────────────────
# Step 6 — wire grok harness to share our clone (skip its internal re-clone)
# ──────────────────────────────────────────────────────────────────────

if [[ "$WITH_GROK" -eq 1 ]]; then
  mkdir -p "$GROK_DIR/.harness/plugin-cache"
  ln -sfn "$CLONE_DIR" "$GROK_DIR/.harness/plugin-cache/claude-tdd-pro"
  # Materialize the harness's .claude/skills/tdd-pro-* symlinks.
  if [[ -d "$GROK_DIR/.claude/skills" ]]; then
    for skill in "$GROK_DIR/.claude/skills/tdd-pro-"*; do
      [[ -L "$skill" ]] || continue
      target=$(readlink "$skill")
      # Re-point any dangling symlinks to the shared cache.
      [[ -e "$skill" ]] && continue
      name=$(basename "$skill")
      ln -sfn "$CLONE_DIR/skills/${name#tdd-pro-}" "$skill" 2>/dev/null || true
    done
  fi
  log "grok harness sharing plugin cache → $CLONE_DIR"
fi

# ──────────────────────────────────────────────────────────────────────
# Step 7 — kick cold-suite verification into background; user can code now
# ──────────────────────────────────────────────────────────────────────

( bash "$CLONE_DIR/evals/runner.sh" >"$HOME/.claude-tdd-pro-install.log" 2>&1 ) &
disown 2>/dev/null || true

ELAPSED=$(($SECONDS - $START_SECONDS))

cat >&2 <<DONE

[install +${ELAPSED}s] ✓ ready — open $TARGET in Cursor and start coding.

  CLAUDE_PLUGIN_ROOT=$CLONE_DIR  (add to your shell rc)

  Verify later (background suite):
    tail -1 ~/.claude-tdd-pro-install.log

  Useful commands:
    bash \$CLAUDE_PLUGIN_ROOT/commands/doctor.sh
    bash \$CLAUDE_PLUGIN_ROOT/commands/space-report.sh
DONE
