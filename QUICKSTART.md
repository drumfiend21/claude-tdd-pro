# Quick Start — Claude TDD Pro

## 2-minute path (recommended)

From inside any project you want to develop in:

```bash
# Claude TDD Pro only:
curl -fsSL https://raw.githubusercontent.com/drumfiend21/claude-tdd-pro/main/scripts/install.sh | bash

# With grok-claude-tdd-pro harness and LSP:
curl -fsSL https://raw.githubusercontent.com/drumfiend21/claude-tdd-pro/main/scripts/install.sh | bash -s -- --with-grok --with-lsp
```

That's it. The installer parallelizes the plugin clone(s), installs hooks, exports Cursor rules, writes a default profile, and kicks the cold rubric suite off in the background so you can start coding immediately. Verification result lands in `~/.claude-tdd-pro-install.log` ~3–5 min later.

Open the project in Cursor and start writing code. The rules and hooks are already active.

If you want manual control over each step, the long-form paths are below.

---

## Long-form paths (manual)

Two paths. Pick one.

| Path | What it gets you | Setup time | First code in |
|---|---|---|---|
| **Direct** | Cursor + Claude TDD Pro rubric, hooks, and LSP | **~10–15 min** | ~15–20 min after clone |
| **With grok-claude-tdd-pro** | Above + Grok-driven research/decompose/dispatch outer loop + tamper-evident audit trail | **~15–20 min** | ~20–30 min after clone |

Times assume a working `git`, `bash`, `node`, `ruby ≥ 3.3` toolchain on the host, plus an installed Cursor.

---

## Path 1 — Direct (Cursor + Claude TDD Pro)

### Step 1 — Clone the plugin (1 min)

```bash
git clone https://github.com/drumfiend21/claude-tdd-pro.git ~/projects/claude-tdd-pro
cd ~/projects/claude-tdd-pro
export CLAUDE_PLUGIN_ROOT="$PWD"
```

Add `export CLAUDE_PLUGIN_ROOT="$HOME/projects/claude-tdd-pro"` to your shell rc (`.zshrc` / `.bashrc`).

### Step 2 — From your app directory, install hooks (2 min)

```bash
cd ~/projects/<your-app>
bash $CLAUDE_PLUGIN_ROOT/commands/install-hooks.sh --scope project --dry-run
bash $CLAUDE_PLUGIN_ROOT/commands/install-hooks.sh --scope project
```

Wires `Stop`, `PreToolUse`, `PostToolUse`, `SessionStart` hooks into `.claude/settings.json`.

### Step 3 — Export rules to Cursor (1 min)

```bash
bash $CLAUDE_PLUGIN_ROOT/commands/export-rules.sh cursor --out .
```

Writes `.cursorrules` + `.cursor/rules/<rule-id>.md`. Re-run after profile or rule changes.

### Step 4 — Set your profile (1 min)

```bash
mkdir -p .claude-tdd-pro
printf 'profile: strict\n' > .claude-tdd-pro/userConfig.yaml
```

Profile choices: `strict` · `standard` · `financial` · `regulated` · `government` · `react` · `node` · `library`. The Q-9 `profile-suggest` skill auto-recommends one on first session.

### Step 5 — (Optional) Wire LSP for inline Cursor diagnostics (1 min)

```bash
mkdir -p ~/.local/bin
ln -sf $CLAUDE_PLUGIN_ROOT/lsp/tdd-pro-lsp/tdd-pro-lsp ~/.local/bin/tdd-pro-lsp
```

In Cursor settings:
```json
{ "tdd-pro.lspPath": "tdd-pro-lsp" }
```

### Step 6 — Verify (3–5 min, cold)

```bash
bash $CLAUDE_PLUGIN_ROOT/evals/runner.sh        # full rubric suite
bash $CLAUDE_PLUGIN_ROOT/commands/doctor.sh     # health check (H-1 cost + §2.17 freshness)
```

If both green, open the project in Cursor and start writing code. Cursor's chat respects the exported `.cursor/rules/*.md`; the LSP surfaces inline diagnostics; the installed hooks fire on tool use.

**Total: ~10–15 min to a working setup.**

---

## Path 2 — With grok-claude-tdd-pro (full Grok outer loop)

### Step 1 — Clone the harness (1 min)

```bash
git clone https://github.com/drumfiend21/grok-claude-tdd-pro.git ~/projects/grok-claude-tdd-pro
cd ~/projects/grok-claude-tdd-pro
```

### Step 2 — Sync the Claude TDD Pro plugin cache (3–5 min)

```bash
./scripts/sync-plugin.sh --ensure
```

Clones claude-tdd-pro at the commit pinned in `docs/claude-tdd-pro.lock.yaml` into `.harness/plugin-cache/`, materializes the `.claude/skills/tdd-pro-*` symlinks, regenerates `.cursor/rules/*.mdc` from harness sources.

### Step 3 — (Optional) Update the pin to claude-tdd-pro main (2–3 min)

To use the latest claude-tdd-pro main (4000 specs, all drift bands closed):

```bash
# Edit the lockfile to point at current main
sed -i.bak 's/^commit: .*/commit: 107d228/' docs/claude-tdd-pro.lock.yaml
./scripts/sync-plugin.sh --ensure
./scripts/sync-plugin.sh --check
```

If `--check` complains about contract-surface sha256 drift, regenerate hashes per the harness's documented procedure (`./scripts/sync-plugin.sh --help`).

### Step 4 — Verify (3–5 min)

```bash
./scripts/smoke-e2e.sh            # end-to-end pipeline test
./scripts/audit-doc-drift.sh      # pre-commit F-1..F-6 audit
```

### Step 5 — Open in Cursor and use the daily workflow

```
/research <topic>           # outer-loop research per harness templates
/decompose                  # split into atomic, file-scoped tickets
/dispatch TICKET-NNN        # write handoff contract (.req.json)
/inner-loop TICKET-NNN      # agent runs Claude TDD Pro Red-Green-Refactor
/audit                      # REQUIRED pre-commit drift validation
```

Each ticket produces three artifacts under `.harness/`: `.req.json` (request), `.res.json` (response), `.manifest.json` (sha256 provenance index).

**Total: ~15–20 min to a working setup** (~20–25 min if updating the pin).

---

## When to pick which

| You want… | Pick |
|---|---|
| Direct TDD in Cursor, no orchestration overhead | **Path 1** |
| Multi-ticket / multi-PR work with Grok-driven research and decomposition | **Path 2** |
| Cross-IDE parity (same rules in Cursor, Claude Code, Grok Build) | **Path 2** |
| Just the rubric runner + standards | **Path 1** suffices |

## Troubleshooting

- **`runner.sh` reports 0 specs**: confirm `CLAUDE_PLUGIN_ROOT` is set; the runner reads it.
- **Cursor shows no rules**: re-run `export-rules.sh cursor --out .` from the project root; check `.cursorrules` exists.
- **LSP not active**: verify `~/.local/bin` is on `PATH` and `which tdd-pro-lsp` resolves.
- **`sync-plugin.sh --check` fails on sha256 drift**: the pinned contract-surface hashes don't match the resolved cache. Regenerate via the harness's documented refresh procedure rather than editing hashes by hand.
- **Hooks fire twice when running both plugins**: install the secondary plugin with `--include agents --include commands` (skip `--include hooks`) so only one plugin owns the hook lifecycle.

## What's under the hood

- **4000 active rubric specs** covering 193 architecture features across 15 phases
- **27 §2.X cross-cutting contracts** (rule schema, detector contract, profile config, freshness gate, dry-run, fidelity audit, …)
- **§23 / §24 / §25 / v1.11 amendments**: IDE rules export (X-6), installable hooks (X-7), LSP surface (X-8), cloud devcontainer (X-9), runtime model router (P-10), application scaffolds (O-12), design-token surface (R-9, O-13), productivity telemetry (Q-10..Q-12), agent harness continuity (H-13)
- See [docs/architecture-v1.9.md](docs/architecture-v1.9.md) for the canonical architecture text and [CLAUDE.md](CLAUDE.md) for the per-CL workflow discipline.
