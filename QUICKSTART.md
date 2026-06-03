# Quick Start — Claude TDD Pro

**One command. Interactive. <60 seconds to ready-in-Cursor.**

```bash
curl -fsSL https://raw.githubusercontent.com/drumfiend21/claude-tdd-pro/main/scripts/install.sh | bash
```

The installer walks you through profile selection, harness opt-in, and LSP wiring with descriptive prompts. It writes a lockfile, detects conflicts, runs the cold rubric suite in the background, and hands control back to you in seconds.

---

## What happens on first run

### 1. Preflight — toolchain check (~50 ms)

Verifies `bash ≥ 3.2`, `node ≥ 18`, `ruby ≥ 3.0`, `git` present. Fails fast with install hints if anything is missing:

```
  ✗ ruby not on PATH  (install: https://www.ruby-lang.org or `brew install ruby`)

Preflight failed. Resolve the missing tools above and re-run.
```

### 2. Conflict detection (~10 ms)

Scans for cross-plugin collisions before touching anything:

```
Detected conflicts:
  ⚠ hook collision in .claude/settings.json (other plugin already installed hooks)
  ⚠ .cursorrules exists from another source (will be backed up to .cursorrules.bak)

Proceed (backups/merges will happen safely)? [Y/n]:
```

Existing `.claude/settings.json` keys are preserved; existing `.cursorrules` is backed up to `.cursorrules.bak`.

### 3. Descriptive prompts

Each option is described before being asked, so you pick informed defaults.

**Profile picker:**
```
Profile — selects the active ruleset and gate strictness.

  standard    Balanced; recommended for most projects
  strict      All rules block on violation; production-critical code
  financial   PCI/SOC2-aware; required audit-trail fields
  regulated   HIPAA/GDPR additions on top of financial
  government  FedRAMP-aware; signed-commits gate enforced
  react       React + RSC + a11y stack
  node        Node.js boundaries + observability
  library     Public-API stability + semver discipline

Profile [standard]:
```

**Grok harness:**
```
Grok harness — orchestrates the outer loop (research → decompose →
dispatch → inner-loop → audit) on top of Claude TDD Pro's per-ticket
Red-Green-Refactor inner loop. Useful for multi-ticket / multi-PR work
where Grok handles planning and Claude TDD Pro executes.

  yes  install grok-claude-tdd-pro alongside (recommended for teams)
  no   skip; you can drive TDD directly from Cursor

Install grok harness? [y/N]:
```

**LSP surface:**
```
LSP surface — inline rubric diagnostics in Cursor/VS Code/any
LSP-compliant editor. Symlinks the tdd-pro-lsp binary into
~/.local/bin so editors discover it on PATH.

  yes  enable inline diagnostics + code-actions (recommended)
  no   skip; rubric still runs via hooks + CI

Enable LSP surface? [Y/n]:
```

### 4. Install (1–2 s + network)

Parallel clones of plugin (and optionally Grok harness), hooks merged into `.claude/settings.json`, Cursor rules generated, profile config written, lockfile committed.

### 5. Background verification

Cold rubric suite runs in the background (`~/.claude-tdd-pro-install.log`); you start coding immediately.

---

## Subcommands (npm-style)

```bash
bash install.sh init        # first-time setup (default; idempotent)
bash install.sh upgrade     # fetch latest; refresh Cursor rules
bash install.sh doctor      # health check with ok/warn report
bash install.sh uninstall   # clean removal (preserves operator keys)
bash install.sh version     # version + pinned commit
bash install.sh help        # full usage
```

### Common one-liners

```bash
# Quick non-interactive (npm init -y pattern):
curl -fsSL .../install.sh | bash -s -- init --yes

# Full kit, scripted (Claude TDD Pro + Grok harness + LSP + strict profile):
curl -fsSL .../install.sh | bash -s -- init --yes --profile strict --with-grok --with-lsp

# Pin to a specific commit (reproducible):
curl -fsSL .../install.sh | bash -s -- init --yes --pin 107d228

# Air-gapped / offline (after first install on this machine):
bash install.sh init --offline --yes

# Update everything (fetches remote main, regenerates rules):
bash install.sh upgrade --yes

# Verify install state:
bash install.sh doctor
```

---

## Always-latest semantics

The installer keeps you current by default:

- `init` on an existing install compares your lockfile pin to the remote `main` HEAD. When behind, it surfaces:
  ```
  [init +01s] found existing .claude-tdd-pro.lock.json (pinned: abc1234)
  [init +01s] remote main is at def5678 — your install is behind
  [init +01s] run 'install.sh upgrade' to fetch latest, or pass --force to reinstall
  ```
- `upgrade` always fetches the remote `main` HEAD. When current, short-circuits with an "already up-to-date" message (mirrors `npm update`).
- Pass `--pin <commit>` to `init` for reproducible installs (CI, audit-frozen deploys).

---

## Lockfile (mirrors `package-lock.json`)

`.claude-tdd-pro.lock.json` in your project root:

```json
{
  "version": "1.0",
  "installer_version": "1.0.0",
  "plugin": {
    "name": "claude-tdd-pro",
    "url": "https://github.com/drumfiend21/claude-tdd-pro",
    "commit": "89b66c8",
    "installed_at": "2026-06-03T23:30:00Z"
  },
  "harness": null,
  "profile": "standard",
  "scope": "project",
  "components": { "hooks": true, "cursor_rules": true, "lsp_symlink": true }
}
```

Commit the lockfile to source control for reproducible team installs.

---

## Doctor (mirrors `npm doctor`)

```
$ bash install.sh doctor

  ✓ plugin cloned at /Users/you/.claude-tdd-pro
  ✓ CLAUDE_PLUGIN_ROOT env var set
  ✓ lockfile present in /Users/you/projects/app
  ✓ hooks installed
  ✓ .cursorrules present
  ✓ profile config present
  ✓ rubric runner executable
  ✓ plugin /doctor health command

8 ok, 0 warning(s)
```

Each failed check has a specific repair hint.

---

## Conflict handling

### Hook collision

If `.claude/settings.json` already has hooks from another plugin, the installer merges safely — preserves the other plugin's keys, adds the TDD Pro hooks under documented names. No data loss.

### Cursor rules collision

If `.cursorrules` exists from another source, it's backed up to `.cursorrules.bak` before TDD Pro's rules are written. Operator can `cat .cursorrules.bak >> .cursorrules` to merge if desired.

### LSP symlink collision

If `~/.local/bin/tdd-pro-lsp` already symlinks elsewhere, the installer surfaces the current target. Confirm to overwrite (or pass `--no-lsp` to skip).

---

## Two paths still exist

Once installed, you can drive development through either:

| Path | What you get | When to use |
|---|---|---|
| **Cursor + Claude TDD Pro direct** | Rubric runner, hooks, Cursor rules, LSP. Drive TDD manually in Cursor's chat. | Single-developer work; tight feedback loop; no orchestration overhead. |
| **Cursor + grok-claude-tdd-pro harness** | The above + Grok-driven outer loop: `/research → /decompose → /dispatch → /inner-loop → /audit`. Per-ticket tamper-evident audit trail. | Multi-ticket / multi-PR work; team workflows; cross-IDE parity (Cursor + Claude Code + Grok Build). |

Pick at install time via the Grok harness prompt. Switch later by re-running `install.sh init --force --with-grok` or `--no-grok`.

---

## Manual / step-by-step paths

If you want to audit what the installer does, or run each step by hand:

### Path 1 — Direct (manual)

```bash
git clone https://github.com/drumfiend21/claude-tdd-pro.git ~/projects/claude-tdd-pro
export CLAUDE_PLUGIN_ROOT="$HOME/projects/claude-tdd-pro"
cd ~/projects/<your-app>
bash $CLAUDE_PLUGIN_ROOT/commands/install-hooks.sh --scope project
bash $CLAUDE_PLUGIN_ROOT/commands/export-rules.sh --target ./.cursorrules
mkdir -p .claude-tdd-pro && printf 'profile: standard\n' > .claude-tdd-pro/userConfig.yaml
ln -sf $CLAUDE_PLUGIN_ROOT/lsp/tdd-pro-lsp/tdd-pro-lsp ~/.local/bin/tdd-pro-lsp
bash $CLAUDE_PLUGIN_ROOT/evals/runner.sh   # verify
```

### Path 2 — With grok-claude-tdd-pro harness (manual)

```bash
git clone https://github.com/drumfiend21/grok-claude-tdd-pro.git ~/projects/grok-claude-tdd-pro
cd ~/projects/grok-claude-tdd-pro
./scripts/sync-plugin.sh --ensure
./scripts/smoke-e2e.sh && ./scripts/audit-doc-drift.sh
```

Then open in Cursor and use `/research → /decompose → /dispatch → /inner-loop → /audit`.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `preflight failed: ruby` | `brew install ruby` (macOS) or follow https://www.ruby-lang.org |
| `preflight failed: node` | `brew install node` (macOS) or follow https://nodejs.org |
| `CLAUDE_PLUGIN_ROOT not set` (doctor warning) | Add `export CLAUDE_PLUGIN_ROOT="$HOME/.claude-tdd-pro"` to `.zshrc` / `.bashrc` |
| Cursor shows no rules | Re-run `bash install.sh upgrade --force` to regenerate `.cursorrules` |
| LSP not active in Cursor | Confirm `~/.local/bin` is on PATH; restart Cursor |
| Hook collision warning ignored unsafely | Re-run `bash install.sh init --force` after restoring `.claude/settings.json` from backup |
| Need to roll back to a specific commit | `bash install.sh init --force --pin <short-sha>` |
| CI / scripted install | Always use `--yes`; pin via `--pin <commit>` for reproducibility |

---

## What's under the hood

- **4000+ active rubric specs** covering 193 architecture features across 15 phases
- **27 §2.X cross-cutting contracts** (rule schema, detector contract, profile config, freshness gate, dry-run, fidelity audit, …)
- **§23 / §24 / §25 / v1.11 amendments**: IDE rules export (X-6), installable hooks (X-7), LSP surface (X-8), cloud devcontainer (X-9), runtime model router (P-10), application scaffolds (O-12), design-token surface (R-9, O-13), productivity telemetry (Q-10..Q-12), agent harness continuity (H-13)

See [docs/architecture-v1.9.md](docs/architecture-v1.9.md) for the canonical architecture text and [CLAUDE.md](CLAUDE.md) for the per-CL workflow discipline.
