# 0002. npm-style installer with lockfile, preflight, and conflict detection

- **Status:** accepted
- **Deciders:** @drumfiend21
- **Decision_id:** ADR-0002
- **Architect_session:** CL-420 reconciliation through CL-423 polish
- **Profile_active:** standard
- **Date:** 2026-06-03

## Context

Operators install the plugin into existing projects that may already
have hooks, Cursor rules, or LSP symlinks from other tools. The
plugin needs to:

- Land cleanly without overwriting unrelated configuration.
- Be reproducible across machines (CI, multiple operator workstations).
- Be idempotent so re-running `init` is safe.
- Stay current with upstream `main` so security and rubric updates
  flow through.
- Fail fast on missing toolchain so operators don't get half-installed
  states.

## Considered options

1. **One-shot install script (no state)** — what we had pre-CL-420.
   Simple. Re-runs blindly overwrite. No upgrade story.
2. **Git submodule** — clone the plugin into the project as a
   submodule. Operator-managed updates. Couples plugin lifecycle to
   project commits.
3. **Homebrew / brew tap** — macOS-first; doesn't cover Linux
   workstations or CI without per-distro packaging.
4. **npm-style subcommand + lockfile** — the choice taken.

## Decision

**npm-style: `install.sh init / upgrade / doctor / uninstall /
version / help` with a `.claude-tdd-pro.lock.json` lockfile in the
project root.**

## Decision rationale

npm's pattern is the most operator-familiar in software development.
Mapping every behavior to a known npm verb gives users mental
scaffolding for free:

| npm | claude-tdd-pro |
|---|---|
| `npm init` | `install.sh init` |
| `npm install` (idempotent) | `install.sh init` (no-op via lockfile) |
| `npm update` | `install.sh upgrade` |
| `npm doctor` | `install.sh doctor` |
| `npm uninstall` | `install.sh uninstall` |
| `package-lock.json` | `.claude-tdd-pro.lock.json` |

The lockfile pins the plugin commit, profile, scope, and component
selections. Re-running on a different machine produces the same
state — reproducibility for free.

Three additional behaviors mirror best practice:
- **Preflight check** — verify bash≥3.2, node≥18, ruby≥3.0, git
  before any work; fails fast with install hints. Inspired by
  `rustup`'s tooling-check banner.
- **Latest-version awareness** — `init` on an existing install
  surfaces drift vs remote HEAD; `upgrade` short-circuits when
  current. Same pattern as `npm outdated` / `npm update`.
- **Conflict detection** — scan for cross-plugin hook collisions,
  existing `.cursorrules`, conflicting LSP symlinks before any
  write. Mirrors `npm`'s `EEXIST` protection.

## Decision rationale (against alternatives)

- **Submodule** rejected: couples plugin updates to project commits;
  hostile to multi-project monorepos and CI.
- **Brew tap** rejected: macOS-only; the plugin must run in cloud
  Linux containers (X-9 devcontainer) and CI.
- **One-shot no-state** rejected: no upgrade story, no idempotency,
  no reproducibility.

## Provenance

- Reference: [npm CLI install documentation](https://docs.npmjs.com/cli/v10/commands/npm-install)
- Reference: [rustup self-update flow](https://rust-lang.github.io/rustup/installation/index.html)
- Reference: [pnpm shrinkwrap / lockfile semantics](https://pnpm.io/cli/install)
- Validated: CL-420 → CL-423 session; installer measured at <2s warm,
  <60s cold on test container.

## Controls

- Idempotency tested: re-running `init` on a current install exits
  0.15s with a "use 'upgrade' to refresh" message.
- Conflict detection tested: existing hooks / .cursorrules / LSP
  symlinks are detected before any write.
- Latest-version check via `git ls-remote` — cheap (~100-300ms).
- Lockfile written atomically (whole file replace, not edit-in-place).

## Cross-references

- §2.14 dry-run subjects (installer supports `--dry-run` discipline
  implicitly via lockfile no-op + `upgrade --force` for replays)
- X-7 installable hooks bundle (the installer wraps and extends
  `commands/install-hooks.sh`)
- `QUICKSTART.md` — operator-facing flow
