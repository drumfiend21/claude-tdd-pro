# Claude Code compatibility — upgrade & breakage handling

When Anthropic releases a new Claude Code version, `claude-tdd-pro` and
the `grok-claude-tdd-pro` harness do **not** automatically break or
auto-update. This document codifies the system's behavior on upstream
change.

## Core design — pinning + drift detection

- **Plugin pinned by commit SHA.** The harness consumes
  `claude-tdd-pro` at the commit pinned in
  `docs/claude-tdd-pro.lock.yaml`. It does not follow `main` / `HEAD`.
- **Local plugin cache.** The harness clones the pinned commit into
  `.harness/plugin-cache/` (gitignored) via
  `./scripts/sync-plugin.sh --ensure`.
- **Symlinks** like `.claude/skills/tdd-pro-cl-workflow/` point into
  the pinned cache, giving reproducible behavior across sessions and
  machines.
- **`claude-tdd-pro` itself** ships its own
  [`.claude-tdd-pro.lock.json`](../scripts/install.sh) via the
  `install.sh` lockfile model (mirrors `package-lock.json`).

## What happens when Claude Code updates

| Surface that could change | Risk | Mitigation in this system |
|---|---|---|
| Hook payload shapes (`PreToolUse`, `PostToolUse`, `Stop`, `SessionStart`) | Hook scripts may misparse new fields | `hooks/scripts/*.sh` use defensive JSON parsing; failures emit telemetry; `docs/THREAT_MODEL_HOOKS.md` Class 3 covers bypass-by-crash |
| Tool API surface (which tools fire which events) | Guards may fire on the wrong events | `audit-cli-surface-fidelity.sh` catches some mismatches; manual verification via `bash scripts/standalone-verify.sh` |
| Plugin loading / settings.json schema | `install-hooks.sh` may write the wrong block | `commands/install-hooks.sh` reads documented `--scope` semantics; `lib/settings-merge.js` preserves operator keys |
| CLI behavior (slash command dispatch) | Slash commands may be unreachable | `grok-build/slash-commands/*.sh` ship parallel platform port; the runner is callable directly per `scripts/standalone-verify.sh` |
| File-fence enforcement contract | Guards may bypass silently | `commands/escape-hatch.sh` is the documented, audited bypass path; silent bypasses surface in telemetry |

## Detection — three layers

### Layer 1 — Session-start sync ritual

`scripts/sync-plugin.sh --check` (in the grok harness) and
`bash scripts/install.sh init` (in the plugin):

- Compare the pinned SHA against the remote repository.
- **Warn but do not fail** when a newer version is available upstream.
- Regenerate Cursor rules / verify symlinks.

### Layer 2 — Drift audits (F-1 through F-6 in the harness; fitness functions in the plugin)

Run pre-commit and via `/audit`:

- `audit-pending-spec-fidelity.sh` — §25 vocabulary check
- `audit-substrate-completeness.sh` — every arch-named substrate resolves
- `audit-cli-surface-fidelity.sh` — documented flags honored
- `audit-spec-depth.sh` — executable substrate has behavior specs
- `fitness-trend.sh` — temporal trend cron writes to
  `docs/fitness-trend.md`

Manifests (`.harness/audit/TICKET-*.manifest.json` in the harness,
audit-chain entries in `audit/escape-hatch-log.jsonl` here) include
SHA256 chains for tamper detection.

### Layer 3 — Standalone verify

`scripts/standalone-verify.sh` proves the platform-independent path
still works:

```
$ bash scripts/standalone-verify.sh
  ✓ runner runs without CLAUDE_SESSION_ID
  ✓ fitness function: substrate-completeness
  ✓ fitness function: CLI surface fidelity
  ✓ fitness function: spec depth
  ✓ LSP --print-diagnostics works as a CLI
  ✓ installer preflight runs (--help)
  ✓ doctor command runs
  ✓ version command runs
  8/8 standalone surfaces work without Claude Code.
```

If standalone-verify passes, the 85% of the system that is
platform-independent works regardless of what Claude Code did. Only
the 15% (hooks bundle + slash command registration) needs
adjustment.

## Migrations & compatibility layer

- **`migrations/` directory** holds version-to-version migrations
  (currently `0.3.0-to-0.4.0.sh`).
- **Bumping the plugin pin** in the harness is a **deliberate process
  requiring an ADR** per the project's per-CL workflow
  ([`CLAUDE.md`](../CLAUDE.md)). The ADR documents: what tested,
  what compatibility checks passed, what required hook updates, and
  the new lockfile contents.
- Existing ADRs that illustrate the discipline:
  [0001](adr/0001-bash-runner-and-orchestration.md) ·
  [0002](adr/0002-npm-style-installer-with-lockfile.md) ·
  [0003](adr/0003-drift-band-closure-cycle.md) ·
  [0004](adr/0004-formal-semantic-verification.md)

## Recommended operator workflow on Claude Code update

```bash
# Step 1 — Detect drift
bash scripts/install.sh upgrade --yes        # plugin side
# or, in the grok harness:
./scripts/sync-plugin.sh --check

# Step 2 — Verify the standalone path still works
bash scripts/standalone-verify.sh

# Step 3 — Smoke a real ticket
./scripts/smoke-e2e.sh                       # in grok harness
# or, in claude-tdd-pro:
bash evals/runner.sh

# Step 4 — If breakage occurs:
#   a) Check the plugin's CHANGELOG, migrations/, and docs/adr/
cat CHANGELOG.md | head -50
ls migrations/
ls docs/adr/

#   b) Run /doctor for self-diagnostics
bash commands/doctor.sh

#   c) Bump the pin ONLY after verification + ADR
#      (this is a deliberate decision, never auto-applied)

# Step 5 — For urgent production fires, use the escape hatch
bash commands/escape-hatch.sh --justification "<text>" --bypass <hook>
# (logged to audit/escape-hatch-log.jsonl with SHA256 chain)
```

## The "intentional conservatism" property

The system is **observable** (`/doctor`, `commands/telemetry-report.sh`,
`docs/fitness-trend.md`), **deliberate** (ADRs gate plugin upgrades),
and **degradable** (escape-hatch + standalone-verify both ship). A
new Claude Code version does **not silently break** the workflow:

1. The sync ritual warns about pin drift.
2. The drift audits flag any post-emission state change.
3. The standalone-verify path proves the platform-independent
   surfaces still work.
4. The escape hatch handles urgent fires with full audit.
5. The migrations + ADR process gates intentional upgrades.

## Cross-references

- `docs/PLATFORM_DEPENDENCY.md` — explicit Claude Code touchpoint
  inventory + abstraction layer
- `docs/THREAT_MODEL_HOOKS.md` — hook-surface attack-class analysis
- `docs/SLO.md` — operational SLOs including drift-detection latency
- `docs/HOTFIX_WITHOUT_AI.md` — emergency procedure for AI-free fixes
- `MAINTAINERS.md` — succession plan during maintainer absence
- `migrations/` — version-to-version migration scripts
- `scripts/sync-plugin.sh` (in `grok-claude-tdd-pro`) — pin
  synchronization
