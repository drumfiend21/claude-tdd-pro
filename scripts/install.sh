#!/usr/bin/env bash
# Claude TDD Pro installer — npm-style subcommands + lockfile.
#
# Subcommands (npm parallel in parens):
#   init                first-time setup in current project (npm init)
#   upgrade             refresh plugin + regenerate rules     (npm update)
#   doctor              health check                          (npm doctor)
#   uninstall           remove hooks, rules, profile          (npm uninstall)
#   version             print installed version + pin
#   help                show usage
#
# Defaults to `init` when no subcommand is given.
#
# Quick start:
#   curl -fsSL https://raw.githubusercontent.com/drumfiend21/claude-tdd-pro/main/scripts/install.sh | bash
#
# Scripted / CI:
#   curl -fsSL .../install.sh | bash -s -- init --yes --profile strict --with-grok
#
# Target: <60s wall-clock to ready-in-Cursor.

set -uo pipefail

START_SECONDS=$SECONDS
VERSION="1.0.0"

CLONE_DIR="${CLAUDE_TDD_PRO_HOME:-$HOME/.claude-tdd-pro}"
GROK_DIR="${GROK_TDD_PRO_HOME:-$HOME/.grok-claude-tdd-pro}"
LOCKFILE_NAME=".claude-tdd-pro.lock.json"

# ──────────────────────────────────────────────────────────────────────
# Flag parsing
# ──────────────────────────────────────────────────────────────────────

SUBCMD="init"
TARGET=""
PROFILE=""
SCOPE="project"
WITH_GROK=""
WITH_LSP=""
PIN=""
OFFLINE=0
YES=0
FORCE=0

# First positional arg is the subcommand if it matches one we know.
if [[ $# -gt 0 ]]; then
  case "$1" in
    init|upgrade|doctor|uninstall|version|help|--help|-h)
      SUBCMD="${1#--}"; SUBCMD="${SUBCMD#-}"
      [[ "$SUBCMD" == "help" || "$SUBCMD" == "h" ]] && SUBCMD="help"
      shift ;;
  esac
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)        YES=1; shift ;;
    --force)         FORCE=1; shift ;;
    --target)        TARGET="$2"; shift 2 ;;
    --profile)       PROFILE="$2"; shift 2 ;;
    --scope)         SCOPE="$2"; shift 2 ;;
    --with-grok)     WITH_GROK=1; shift ;;
    --no-grok)       WITH_GROK=0; shift ;;
    --with-lsp)      WITH_LSP=1; shift ;;
    --no-lsp)        WITH_LSP=0; shift ;;
    --pin)           PIN="$2"; shift 2 ;;
    --offline)       OFFLINE=1; shift ;;
    -h|--help)       SUBCMD="help"; shift ;;
    *) echo "install: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$TARGET" ]] && TARGET="$(pwd)"

# ──────────────────────────────────────────────────────────────────────
# TTY-safe prompts (npm init style)
# ──────────────────────────────────────────────────────────────────────

PROMPTS_AVAILABLE=0
READ_FD=""
if [[ "$YES" -eq 0 ]] && [[ "$SUBCMD" != "version" && "$SUBCMD" != "help" && "$SUBCMD" != "doctor" ]]; then
  if [[ -t 0 ]]; then
    PROMPTS_AVAILABLE=1
  elif [[ -e /dev/tty ]]; then
    # Wrap exec in a subshell-tested attach; bash prints to stderr on
    # exec failure even with 2>/dev/null. Test first via a noop fd open.
    if ( exec 3<>/dev/tty ) 2>/dev/null; then
      exec 3<>/dev/tty 2>/dev/null && { PROMPTS_AVAILABLE=1; READ_FD=3; }
    fi
  fi
fi

prompt() {
  local var_name="$1" question="$2" default="$3"
  local answer=""
  if [[ "$PROMPTS_AVAILABLE" -eq 1 ]]; then
    if [[ -n "$READ_FD" ]]; then
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
  local var_name="$1" question="$2" default="$3"
  local answer=""
  local hint="[y/N]"
  [[ "$default" == "y" ]] && hint="[Y/n]"
  if [[ "$PROMPTS_AVAILABLE" -eq 1 ]]; then
    if [[ -n "$READ_FD" ]]; then
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

# Describe an option set before prompting so the operator picks
# informed defaults — mirrors how cargo/rustup/brew explain their
# choices during setup.
describe() {
  if [[ "$PROMPTS_AVAILABLE" -eq 1 ]]; then
    local target_fd=${READ_FD:-2}
    while [[ $# -gt 0 ]]; do
      printf '  %s\n' "$1" >&$target_fd
      shift
    done
    printf '\n' >&$target_fd
  fi
}

# ──────────────────────────────────────────────────────────────────────
# Preflight: tool-version check (fail fast on missing deps)
# ──────────────────────────────────────────────────────────────────────

REQUIRED_BASH_MAJOR=3
REQUIRED_BASH_MINOR=2
REQUIRED_NODE_MAJOR=18
REQUIRED_RUBY_MAJOR=3
REQUIRED_RUBY_MINOR=0

preflight_check() {
  local fatal=0
  # bash
  local bash_major bash_minor
  bash_major="${BASH_VERSINFO[0]}"
  bash_minor="${BASH_VERSINFO[1]}"
  if [[ "$bash_major" -lt "$REQUIRED_BASH_MAJOR" ]] || \
     ([[ "$bash_major" -eq "$REQUIRED_BASH_MAJOR" ]] && [[ "$bash_minor" -lt "$REQUIRED_BASH_MINOR" ]]); then
    printf '  ✗ bash %d.%d.x found; need >= %d.%d\n' "$bash_major" "$bash_minor" "$REQUIRED_BASH_MAJOR" "$REQUIRED_BASH_MINOR" >&2
    fatal=1
  fi
  # node
  if command -v node >/dev/null 2>&1; then
    local node_major
    node_major=$(node --version 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/')
    if [[ "${node_major:-0}" -lt "$REQUIRED_NODE_MAJOR" ]]; then
      printf '  ✗ node %s found; need >= %d.x  (install: https://nodejs.org)\n' "$(node --version)" "$REQUIRED_NODE_MAJOR" >&2
      fatal=1
    fi
  else
    printf '  ✗ node not on PATH  (install: https://nodejs.org or `brew install node`)\n' >&2
    fatal=1
  fi
  # ruby
  if command -v ruby >/dev/null 2>&1; then
    local ruby_major ruby_minor
    ruby_major=$(ruby -e 'print RUBY_VERSION.split(".")[0]' 2>/dev/null)
    ruby_minor=$(ruby -e 'print RUBY_VERSION.split(".")[1]' 2>/dev/null)
    if [[ "${ruby_major:-0}" -lt "$REQUIRED_RUBY_MAJOR" ]] || \
       ([[ "${ruby_major:-0}" -eq "$REQUIRED_RUBY_MAJOR" ]] && [[ "${ruby_minor:-0}" -lt "$REQUIRED_RUBY_MINOR" ]]); then
      printf '  ✗ ruby %s found; need >= %d.%d  (install: https://www.ruby-lang.org or `brew install ruby`)\n' \
        "$(ruby --version | awk '{print $2}')" "$REQUIRED_RUBY_MAJOR" "$REQUIRED_RUBY_MINOR" >&2
      fatal=1
    fi
  else
    printf '  ✗ ruby not on PATH  (install: https://www.ruby-lang.org or `brew install ruby`)\n' >&2
    fatal=1
  fi
  # git
  command -v git >/dev/null 2>&1 || { printf '  ✗ git not on PATH\n' >&2; fatal=1; }

  if [[ "$fatal" -eq 1 ]]; then
    printf '\nPreflight failed. Resolve the missing tools above and re-run.\n' >&2
    exit 3
  fi
}

# ──────────────────────────────────────────────────────────────────────
# Conflict detection (mirrors npm's "EEXIST"-style protection)
# ──────────────────────────────────────────────────────────────────────

detect_conflicts() {
  local target="$1"
  local conflicts=()

  # Hook collision: existing settings.json with non-TDD-Pro hooks
  if [[ -f "$target/.claude/settings.json" ]]; then
    if node -e '
      const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
      const h=j.hooks||{};
      const ours=Object.values(h).filter(v=>String(v).includes("claude-tdd-pro"));
      const any=Object.keys(h);
      process.exit(any.length>0 && ours.length<any.length ? 0 : 1);
    ' "$target/.claude/settings.json" 2>/dev/null; then
      conflicts+=("hook collision in .claude/settings.json (other plugin already installed hooks)")
    fi
  fi

  # Cursor rules collision
  if [[ -f "$target/.cursorrules" ]] && ! grep -q "claude-tdd-pro\|X-6" "$target/.cursorrules" 2>/dev/null; then
    conflicts+=("$target/.cursorrules exists from another source (will be backed up to .cursorrules.bak)")
  fi

  # LSP symlink collision
  if [[ -L "$HOME/.local/bin/tdd-pro-lsp" ]]; then
    local current_target; current_target=$(readlink "$HOME/.local/bin/tdd-pro-lsp")
    if [[ "$current_target" != "$CLONE_DIR/"* ]]; then
      conflicts+=("~/.local/bin/tdd-pro-lsp -> $current_target (will be overwritten)")
    fi
  fi

  printf '%s\n' "${conflicts[@]}"
}

# ──────────────────────────────────────────────────────────────────────
# Latest-version check (warn if local is behind remote)
# ──────────────────────────────────────────────────────────────────────

remote_head_short() {
  local url="$1"
  git ls-remote --quiet "$url" HEAD 2>/dev/null | head -1 | awk '{print substr($1,1,7)}'
}

log() { printf '[%s +%02ds] %s\n' "$SUBCMD" "$(($SECONDS - $START_SECONDS))" "$*" >&2; }

# ──────────────────────────────────────────────────────────────────────
# Lockfile helpers (npm lockfile pattern)
# ──────────────────────────────────────────────────────────────────────

lockfile_path() { printf '%s/%s' "$TARGET" "$LOCKFILE_NAME"; }
lockfile_exists() { [[ -f "$(lockfile_path)" ]]; }

lockfile_read_field() {
  local field="$1"
  lockfile_exists || { echo ""; return; }
  node -e "const j=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));process.stdout.write(String(${field}||''))" "$(lockfile_path)" 2>/dev/null || echo ""
}

lockfile_write() {
  local commit="$1" profile="$2" with_grok="$3" with_lsp="$4"
  local now; now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  cat > "$(lockfile_path)" <<EOF
{
  "version": "1.0",
  "installer_version": "$VERSION",
  "plugin": {
    "name": "claude-tdd-pro",
    "url": "https://github.com/drumfiend21/claude-tdd-pro",
    "commit": "$commit",
    "installed_at": "$now"
  },
  "harness": $( [[ "$with_grok" == "1" ]] && echo '{"name":"grok-claude-tdd-pro","url":"https://github.com/drumfiend21/grok-claude-tdd-pro"}' || echo "null" ),
  "profile": "$profile",
  "scope": "$SCOPE",
  "components": {
    "hooks": true,
    "cursor_rules": true,
    "lsp_symlink": $( [[ "$with_lsp" == "1" ]] && echo true || echo false )
  }
}
EOF
}

# ──────────────────────────────────────────────────────────────────────
# Subcommand: version
# ──────────────────────────────────────────────────────────────────────

cmd_version() {
  echo "claude-tdd-pro installer $VERSION"
  if lockfile_exists; then
    local pin; pin=$(lockfile_read_field "j.plugin.commit")
    local profile; profile=$(lockfile_read_field "j.profile")
    echo "  installed: $pin (profile: $profile)"
  fi
  exit 0
}

# ──────────────────────────────────────────────────────────────────────
# Subcommand: help
# ──────────────────────────────────────────────────────────────────────

cmd_help() {
  cat <<USAGE
Usage: install.sh [SUBCOMMAND] [OPTIONS]

Subcommands:
  init                    First-time setup in current project (default)
  upgrade                 Update plugin to latest; regenerate rules
  doctor                  Health check (idempotent)
  uninstall               Remove hooks, rules, profile, lockfile
  version                 Print installed version + pin
  help                    Show this message

Options:
  -y, --yes               Skip all prompts; use defaults / flags
  --force                 Re-run even when lockfile says we're current
  --target <dir>          Target project directory (default: cwd)
  --profile <name>        Profile (standard|strict|financial|regulated|government|react|node|library)
  --scope project|user    Hook install scope (default: project)
  --with-grok             Also install grok-claude-tdd-pro harness
  --no-grok               Skip grok harness (default in --yes mode)
  --with-lsp              Symlink LSP binary into ~/.local/bin
  --no-lsp                Skip LSP symlink
  --pin <commit>          Pin to specific commit (default: main HEAD)
  --offline               Skip network operations; use cached clone

Environment:
  CLAUDE_TDD_PRO_HOME     Plugin clone location (default: ~/.claude-tdd-pro)
  GROK_TDD_PRO_HOME       Harness clone location (default: ~/.grok-claude-tdd-pro)

Examples:
  curl ... | bash                                    # interactive init
  curl ... | bash -s -- init -y                      # quick non-interactive
  curl ... | bash -s -- init -y --profile strict --with-grok --with-lsp
  bash install.sh upgrade --yes                      # update everything
  bash install.sh doctor                             # health check
  bash install.sh uninstall --yes                    # clean removal

Target: <60s wall-clock for init.
USAGE
  exit 0
}

# ──────────────────────────────────────────────────────────────────────
# Banner
# ──────────────────────────────────────────────────────────────────────

banner() {
  cat <<BANNER >&2
┌──────────────────────────────────────────────────────────────────┐
│  Claude TDD Pro installer v$VERSION                                 │
│  Subcommand: $(printf '%-52s' "$SUBCMD")│
└──────────────────────────────────────────────────────────────────┘
BANNER
}

# ──────────────────────────────────────────────────────────────────────
# Clone helper (idempotent, parallel-safe)
# ──────────────────────────────────────────────────────────────────────

clone_or_update() {
  local url="$1" dest="$2"
  if [[ -d "$dest/.git" ]]; then
    [[ "$OFFLINE" -eq 1 ]] && return 0
    git -C "$dest" fetch --quiet --depth 1 origin main 2>/dev/null \
      && git -C "$dest" reset --quiet --hard origin/main 2>/dev/null \
      || true
  else
    [[ "$OFFLINE" -eq 1 ]] && { echo "install: --offline but $dest not present" >&2; return 1; }
    git clone --quiet --depth 1 --filter=blob:none "$url" "$dest" 2>/dev/null \
      || git clone --quiet --depth 1 "$url" "$dest"
  fi
}

resolve_pin() {
  local dir="$1" pin="$2"
  [[ -z "$pin" ]] && pin=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)
  [[ -n "$pin" && "$pin" != "$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)" ]] && {
    git -C "$dir" fetch --quiet --depth 1 origin "$pin" 2>/dev/null && \
    git -C "$dir" checkout --quiet "$pin" 2>/dev/null
  }
  printf '%s' "$pin"
}

# ──────────────────────────────────────────────────────────────────────
# Subcommand: init
# ──────────────────────────────────────────────────────────────────────

cmd_init() {
  banner

  # Preflight: verify toolchain BEFORE asking the operator anything
  preflight_check

  # Idempotency + freshness check: detect prior install and remote drift
  if lockfile_exists && [[ "$FORCE" -eq 0 ]]; then
    local pin remote
    pin=$(lockfile_read_field "j.plugin.commit")
    remote=$(remote_head_short https://github.com/drumfiend21/claude-tdd-pro.git)
    log "found existing $LOCKFILE_NAME (pinned: $pin)"
    if [[ -n "$remote" && "$pin" != "$remote"* ]]; then
      log "remote main is at $remote — your install is behind"
      log "run 'install.sh upgrade' to fetch latest, or pass --force to reinstall"
    else
      log "your install is current"
      log "use 'doctor' to verify, or pass --force to reinstall"
    fi
    exit 0
  fi

  # Detect cross-plugin conflicts BEFORE clone (cheaper feedback)
  local conflicts; conflicts=$(detect_conflicts "$TARGET")
  if [[ -n "$conflicts" ]]; then
    echo "" >&2
    echo "Detected conflicts:" >&2
    while IFS= read -r line; do echo "  ⚠ $line" >&2; done <<<"$conflicts"
    echo "" >&2
    if [[ "$PROMPTS_AVAILABLE" -eq 1 ]] && [[ "$FORCE" -eq 0 ]]; then
      prompt_yn CONFLICT_OK "Proceed (backups/merges will happen safely)?" "y"
      [[ "$CONFLICT_OK" -eq 1 ]] || { echo "Aborted. Use --force to override." >&2; exit 1; }
    fi
  fi

  # Prompts with descriptive context (cargo/rustup-style)
  prompt TARGET_R "Target project directory" "$TARGET"
  TARGET="$TARGET_R"

  if [[ -z "$PROFILE" ]]; then
    describe \
      "Profile — selects the active ruleset and gate strictness." \
      "" \
      "  standard    Balanced; recommended for most projects" \
      "  strict      All rules block on violation; production-critical code" \
      "  financial   PCI/SOC2-aware; required audit-trail fields" \
      "  regulated   HIPAA/GDPR additions on top of financial" \
      "  government  FedRAMP-aware; signed-commits gate enforced" \
      "  react       React + RSC + a11y stack" \
      "  node        Node.js boundaries + observability" \
      "  library     Public-API stability + semver discipline"
    prompt PROFILE "Profile" "standard"
  fi

  if [[ -z "$WITH_GROK" ]]; then
    describe \
      "Grok harness — orchestrates the outer loop (research → decompose →" \
      "dispatch → inner-loop → audit) on top of Claude TDD Pro's per-ticket" \
      "Red-Green-Refactor inner loop. Useful for multi-ticket / multi-PR work" \
      "where Grok handles planning and Claude TDD Pro executes." \
      "" \
      "  yes  install grok-claude-tdd-pro alongside (recommended for teams)" \
      "  no   skip; you can drive TDD directly from Cursor"
    prompt_yn WITH_GROK "Install grok harness?" "n"
  fi

  if [[ -z "$WITH_LSP" ]]; then
    describe \
      "LSP surface — inline rubric diagnostics in Cursor/VS Code/any" \
      "LSP-compliant editor. Symlinks the tdd-pro-lsp binary into" \
      "~/.local/bin so editors discover it on PATH." \
      "" \
      "  yes  enable inline diagnostics + code-actions (recommended)" \
      "  no   skip; rubric still runs via hooks + CI"
    prompt_yn WITH_LSP "Enable LSP surface?" "y"
  fi
  WITH_GROK="${WITH_GROK:-0}"
  WITH_LSP="${WITH_LSP:-1}"

  if [[ "$PROMPTS_AVAILABLE" -eq 1 ]]; then
    cat >&2 <<PLAN

Plan:
  target:   $TARGET
  profile:  $PROFILE
  scope:    $SCOPE
  grok:     $( [[ $WITH_GROK -eq 1 ]] && echo yes || echo no )
  lsp:      $( [[ $WITH_LSP  -eq 1 ]] && echo yes || echo no )
  pin:      $( [[ -n "$PIN" ]] && echo "$PIN" || echo "main HEAD" )

PLAN
    prompt_yn CONFIRM "Proceed?" "y"
    [[ "$CONFIRM" -eq 1 ]] || { echo "Aborted." >&2; exit 1; }
  fi

  # Step 1 — parallel clones (background)
  log "fetching plugin(s)..."
  clone_or_update https://github.com/drumfiend21/claude-tdd-pro.git "$CLONE_DIR" & PID_PLUGIN=$!
  if [[ "$WITH_GROK" -eq 1 ]]; then
    clone_or_update https://github.com/drumfiend21/grok-claude-tdd-pro.git "$GROK_DIR" & PID_GROK=$!
  fi

  wait "$PID_PLUGIN" || { log "ERR plugin clone failed"; exit 1; }
  local resolved_pin; resolved_pin=$(resolve_pin "$CLONE_DIR" "$PIN")
  log "plugin @ $resolved_pin"

  if [[ "$WITH_GROK" -eq 1 ]]; then
    wait "$PID_GROK" || { log "ERR grok clone failed"; exit 1; }
    log "harness ready"
  fi

  export CLAUDE_PLUGIN_ROOT="$CLONE_DIR"

  # Step 2 — hooks
  mkdir -p "$TARGET/.claude"
  bash "$CLONE_DIR/commands/install-hooks.sh" --scope "$SCOPE" --settings-path "$TARGET/.claude/settings.json" >/dev/null 2>&1 \
    || log "WARN hooks install failed"
  log "hooks installed (--scope $SCOPE)"

  # Step 3 — cursor rules (back up existing if not from us)
  if [[ -f "$TARGET/.cursorrules" ]] && ! grep -q "claude-tdd-pro\|X-6" "$TARGET/.cursorrules" 2>/dev/null; then
    cp "$TARGET/.cursorrules" "$TARGET/.cursorrules.bak"
    log "backed up existing .cursorrules → .cursorrules.bak"
  fi
  bash "$CLONE_DIR/commands/export-rules.sh" --target "$TARGET/.cursorrules" >/dev/null 2>&1 \
    || log "WARN cursor rule export failed"
  log "cursor rules → .cursorrules"

  # Step 4 — profile config (preserved if user already wrote one)
  mkdir -p "$TARGET/.claude-tdd-pro"
  [[ -f "$TARGET/.claude-tdd-pro/userConfig.yaml" ]] || \
    printf 'profile: %s\n' "$PROFILE" > "$TARGET/.claude-tdd-pro/userConfig.yaml"
  log "profile: $PROFILE"

  # Step 5 — LSP symlink
  if [[ "$WITH_LSP" -eq 1 ]]; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$CLONE_DIR/lsp/tdd-pro-lsp/tdd-pro-lsp" "$HOME/.local/bin/tdd-pro-lsp"
    log "lsp → ~/.local/bin/tdd-pro-lsp"
  fi

  # Step 6 — grok cache share (skip its internal re-clone)
  if [[ "$WITH_GROK" -eq 1 ]]; then
    mkdir -p "$GROK_DIR/.harness/plugin-cache"
    ln -sfn "$CLONE_DIR" "$GROK_DIR/.harness/plugin-cache/claude-tdd-pro"
    log "harness cache → $CLONE_DIR"
  fi

  # Step 7 — write lockfile
  lockfile_write "$resolved_pin" "$PROFILE" "$WITH_GROK" "$WITH_LSP"
  log "lockfile → $LOCKFILE_NAME"

  # Step 8 — background suite verification + post-install doctor (async)
  ( bash "$CLONE_DIR/evals/runner.sh" >"$HOME/.claude-tdd-pro-install.log" 2>&1 ) &
  disown 2>/dev/null || true

  local elapsed=$(($SECONDS - $START_SECONDS))
  cat >&2 <<DONE

[init +${elapsed}s] ✓ ready — open $TARGET in Cursor and start coding.

  CLAUDE_PLUGIN_ROOT=$CLONE_DIR  (add to your shell rc)

  Verify:    bash install.sh doctor
  Upgrade:   bash install.sh upgrade
  Uninstall: bash install.sh uninstall

  Background suite log: ~/.claude-tdd-pro-install.log
DONE
}

# ──────────────────────────────────────────────────────────────────────
# Subcommand: upgrade
# ──────────────────────────────────────────────────────────────────────

cmd_upgrade() {
  banner
  preflight_check
  lockfile_exists || { echo "No $LOCKFILE_NAME in $TARGET; run 'init' first." >&2; exit 1; }

  local current; current=$(lockfile_read_field "j.plugin.commit")
  local remote;  remote=$(remote_head_short https://github.com/drumfiend21/claude-tdd-pro.git)
  log "current: $current"
  log "remote:  ${remote:-(could not reach)}"

  if [[ -n "$remote" && "$current" == "$remote"* ]] && [[ "$FORCE" -eq 0 ]]; then
    log "✓ already up-to-date (pass --force to re-fetch + regenerate rules)"
    exit 0
  fi

  log "pulling plugin updates..."
  clone_or_update https://github.com/drumfiend21/claude-tdd-pro.git "$CLONE_DIR" \
    || { log "ERR plugin update failed"; exit 1; }

  local with_grok; with_grok=$(lockfile_read_field "j.harness ? 1 : 0")
  if [[ "$with_grok" == "1" ]]; then
    clone_or_update https://github.com/drumfiend21/grok-claude-tdd-pro.git "$GROK_DIR" || true
  fi

  local resolved_pin; resolved_pin=$(resolve_pin "$CLONE_DIR" "$PIN")
  log "plugin @ $resolved_pin"

  # Regenerate Cursor rules (stamps go stale on upgrade)
  bash "$CLONE_DIR/commands/export-rules.sh" --target "$TARGET/.cursorrules" >/dev/null 2>&1 \
    && log "cursor rules refreshed" || log "WARN cursor rule export failed"

  # Refresh lockfile
  local profile; profile=$(lockfile_read_field "j.profile")
  local with_lsp; with_lsp=$(lockfile_read_field "j.components.lsp_symlink ? 1 : 0")
  lockfile_write "$resolved_pin" "$profile" "$with_grok" "$with_lsp"
  log "lockfile updated"

  local elapsed=$(($SECONDS - $START_SECONDS))
  log "✓ upgrade complete (${elapsed}s)"
}

# ──────────────────────────────────────────────────────────────────────
# Subcommand: doctor
# ──────────────────────────────────────────────────────────────────────

cmd_doctor() {
  banner
  local ok=0 warn=0
  check() {
    local label="$1" test="$2" hint="$3"
    if eval "$test" >/dev/null 2>&1; then
      printf '  ✓ %s\n' "$label" >&2; ok=$((ok+1))
    else
      printf '  ✗ %s — %s\n' "$label" "$hint" >&2; warn=$((warn+1))
    fi
  }
  check "plugin cloned at $CLONE_DIR"          "[ -d '$CLONE_DIR/.git' ]"                        "run: install.sh init"
  check "CLAUDE_PLUGIN_ROOT env var set"       "[ -n \"\${CLAUDE_PLUGIN_ROOT:-}\" ]"            "add 'export CLAUDE_PLUGIN_ROOT=$CLONE_DIR' to shell rc"
  check "lockfile present in $TARGET"          "[ -f '$(lockfile_path)' ]"                       "run: install.sh init"
  check "hooks installed"                       "[ -f '$TARGET/.claude/settings.json' ]"          "run: install.sh init"
  check ".cursorrules present"                  "[ -f '$TARGET/.cursorrules' ]"                   "run: bash \$CLAUDE_PLUGIN_ROOT/commands/export-rules.sh --target $TARGET/.cursorrules"
  check "profile config present"                "[ -f '$TARGET/.claude-tdd-pro/userConfig.yaml' ]" "run: install.sh init"
  check "rubric runner executable"              "[ -x '$CLONE_DIR/evals/runner.sh' ]"             "re-clone plugin"
  if [[ -x "$CLONE_DIR/commands/doctor.sh" ]]; then
    check "plugin /doctor health command"      "bash '$CLONE_DIR/commands/doctor.sh' --help"    "plugin doctor not runnable"
  fi
  printf '\n%d ok, %d warning(s)\n' "$ok" "$warn" >&2
  [[ "$warn" -eq 0 ]]
}

# ──────────────────────────────────────────────────────────────────────
# Subcommand: uninstall
# ──────────────────────────────────────────────────────────────────────

cmd_uninstall() {
  banner
  if [[ "$PROMPTS_AVAILABLE" -eq 1 && "$YES" -eq 0 ]]; then
    cat >&2 <<WARN

This will remove from $TARGET:
  .claude/settings.json         (hooks block; non-TDD-Pro keys preserved)
  .cursorrules
  .claude-tdd-pro/userConfig.yaml
  $LOCKFILE_NAME

It will NOT remove the plugin clone at $CLONE_DIR.

WARN
    prompt_yn CONFIRM "Proceed?" "n"
    [[ "$CONFIRM" -eq 1 ]] || { echo "Aborted." >&2; exit 1; }
  fi

  # Remove the hooks block, preserve other settings keys.
  if [[ -f "$TARGET/.claude/settings.json" ]]; then
    node -e '
      const fs = require("fs");
      const p = process.argv[1];
      try {
        const j = JSON.parse(fs.readFileSync(p, "utf8"));
        delete j.hooks;
        if (Object.keys(j).length === 0) fs.unlinkSync(p);
        else fs.writeFileSync(p, JSON.stringify(j, null, 2) + "\n");
      } catch {}
    ' "$TARGET/.claude/settings.json"
    log "hooks block removed from $TARGET/.claude/settings.json"
  fi

  rm -f "$TARGET/.cursorrules" && log "removed .cursorrules"
  rm -f "$TARGET/.claude-tdd-pro/userConfig.yaml" && log "removed userConfig.yaml"
  rm -f "$(lockfile_path)" && log "removed $LOCKFILE_NAME"
  # Clean up LSP symlink if it points at our cache.
  if [[ -L "$HOME/.local/bin/tdd-pro-lsp" ]] && [[ "$(readlink "$HOME/.local/bin/tdd-pro-lsp")" == "$CLONE_DIR/"* ]]; then
    rm -f "$HOME/.local/bin/tdd-pro-lsp" && log "removed LSP symlink"
  fi

  log "✓ uninstalled. Plugin clone at $CLONE_DIR preserved (delete manually if desired)."
}

# ──────────────────────────────────────────────────────────────────────
# Dispatch
# ──────────────────────────────────────────────────────────────────────

case "$SUBCMD" in
  init)      cmd_init ;;
  upgrade)   cmd_upgrade ;;
  doctor)    cmd_doctor ;;
  uninstall) cmd_uninstall ;;
  version)   cmd_version ;;
  help)      cmd_help ;;
  *)         echo "install: unknown subcommand: $SUBCMD" >&2; cmd_help ;;
esac
