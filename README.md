# claude-tdd-pro

A Claude Code plugin that enforces test-first feature development,
strict refactor discipline, security-hardened auto-commit pathways,
and Meta/Google-quality PRs. You describe features; Claude builds
them properly with TDD; your only involvement with the code itself
is reviewing the PR.

**Current version: 0.2.0** — see [CHANGELOG](#changelog) below.

## What it does

When installed, this plugin:

- **Auto-triggers TDD discipline** on natural-language feature
  requests — Claude writes failing tests first, runs them, confirms
  red, writes minimum code to pass, refactors. Every cycle is a
  commit.
- **Optionally enforces TDD via PreToolUse hook** (opt-in per
  project) — blocks edits to source files when no failing test
  names them. Pattern from `nizos/tdd-guard`; turns advisory skills
  into hard enforcement.
- **Hardened security model** — secret-scan before every commit
  (refuses `.env`, `id_rsa`, AWS/GitHub/OpenAI/JWT patterns), RCE-
  hardened lint hook (no `npx`, no symlinked-ancestor following,
  workspace-bounded paths), exact-token PR confirmation (resists
  prompt injection), `gh auth status` check before push.
- **Specialist code-review panel** — five parallel subagents
  (correctness, security, performance, observability, deps)
  produce severity-tiered findings; chair synthesizes a verdict.
- **Meta/Google-quality PR generation** — Conventional Commits
  subject, structured body with required Test Plan + AI-disclosure
  + Behavior + Numbers sections, scope refusals on bundled
  refactor+feature.
- **Plan-Mode-first discipline** for non-trivial work — no code
  until the spec / plan is approved.
- **Multi-tool sync** — one canonical `CONVENTIONS.md` →
  auto-generates Cursor / Copilot / Aider / Windsurf / AGENTS.md
  sister files via `/sync-rules`.
- **Plugin self-tests** — `evals/` runs the security hooks against
  known-bad inputs. Run with `bash evals/runner.sh`.
- **MCP server bundling** — git + GitHub MCP servers auto-load,
  giving subagents native context for repository operations.
- **Setup-time dependency verification** — first session warns about
  missing `gh`, `node`, `ruff`, etc. instead of silent fail.

## Installation

```bash
mkdir -p ~/.claude/plugins
git clone https://github.com/YOUR_USER/claude-tdd-pro ~/.claude/plugins/claude-tdd-pro
```

Restart Claude Code. The Setup hook fires on first session and
verifies dependencies. See [INSTALL.md](INSTALL.md) for verification
steps and troubleshooting.

## Slash commands (12)

| Command | What it does |
|---|---|
| `/feature <description>` | Build a feature TDD-first via the `tdd-feature-build` skill |
| `/spec <description>` | Write a Markdown spec FIRST, before any code |
| `/plan-first <description>` | Plan Mode discipline — produce a plan, get approval, then code |
| `/extract-component <target>` | 9-step test-first refactor pattern |
| `/fix-bug <description>` | Bug-as-failing-test pattern |
| `/tighten-tests <file>` | Audit a test file against the strict-assertions bar |
| `/review-panel` | 5-specialist parallel review panel with verdict |
| `/init-guardrails` | Phase 1 setup (ESLint flat + Prettier + tsconfig + Husky + Vitest) |
| `/snapshot` | Phase 0 setup (tag + README + CLAUDE.md + REMEDIATION.md) |
| `/onboard` | Codebase tour + propose CLAUDE.md from observed conventions |
| `/adr <decision>` | Write an Architecture Decision Record (MADR format) |
| `/sync-rules` | Generate Cursor/Copilot/Aider/Windsurf/AGENTS.md from CONVENTIONS.md |
| `/pr` | Open a Meta/Google-quality PR (with full pre-flight + token confirm) |

## Skills (12 — auto-trigger when contextually relevant)

| Skill | Triggers on | Side-effecting? |
|---|---|---|
| `tdd-feature-build` | New-feature requests ("add X", "implement Y") | Yes — commits |
| `test-first-extract` | Extract / split / decompose requests | Yes — commits |
| `strict-component-tests` | Test files (scoped via `paths:`) | No — review only |
| `bug-fix-discipline` | Bug reports / regressions | Yes — commits |
| `pr-quality` | Explicit `/pr` only (locked down) | Yes — pushes + opens PR |
| `spec-first` | Feature specification requests | No — writes a doc |
| `adr-writer` | Architecture decision recording | No — writes a doc |
| `onboard` | Explicit `/onboard` only | No — read-only |
| `failure-domain-log` | Repeated mistakes / explicit log requests | No — appends to CLAUDE.md |
| `phase-0-snapshot` | Explicit `/snapshot` only (locked down) | Yes — tags + commits |
| `phase-1-guardrails` | Explicit `/init-guardrails` only | Yes — installs deps |
| `reject-bad-tooling` | Bad-tooling suggestions (force-fix, fake packages, etc.) | No — refuses |

Side-effecting skills are locked behind `disable-model-invocation:
true` so the model can't auto-fire them. The user invokes them via
the corresponding slash command.

## Subagents (8)

| Agent | Purpose |
|---|---|
| `tdd-driver` | Autonomous full red-green-refactor loop. Worktree-isolated. |
| `pr-self-reviewer` | Pre-PR self-review (read-only) |
| `strict-test-writer` | Delegated strict-test writing for a target file |
| `fresh-eyes-review` | Final-pass reviewer with no prior conversation context |
| `review-correctness` | Specialist (correctness) — used by `/review-panel` |
| `review-security` | Specialist (security) — used by `/review-panel` |
| `review-performance` | Specialist (performance) — used by `/review-panel` |
| `review-observability` | Specialist (observability) — used by `/review-panel` |
| `review-deps` | Specialist (dependency impact) — used by `/review-panel` |

## Hooks

| Event | What runs | Why |
|---|---|---|
| `Setup` | `verify-deps.sh` | First-session check for `gh`, `node`, `ruff`, `gh auth status` |
| `PreToolUse` (Edit/Write/MultiEdit) | `tdd-guard.sh` | OPT-IN: blocks source edits without a failing test |
| `PostToolUse` (Edit/Write/MultiEdit) | `lint-on-save.sh` | RCE-hardened: lints the just-written file |

The TDD guard is OFF by default. Enable per-project with
`touch .claude-tdd-pro/tdd-guard.enabled` or env
`CLAUDE_TDD_PRO_GUARD=on`. Disable per-session by removing the file.

## userConfig

The plugin's `plugin.json` declares typed prompts (`package_manager`,
`test_command`, `lint_command`, `default_reviewer`, etc.) — set once
per machine, reused across all projects. See `.claude-plugin/plugin.json`.

## MCP servers (bundled)

| Server | What it provides |
|---|---|
| git | Native git operations for subagents (no shelling) |
| github | Native GitHub PR / issue / release operations |

Both are optional — commands have `gh` / `git` CLI fallbacks. Edit
`.mcp.json` to disable any.

## Standards baked in (citable)

This plugin's quality bar comes from public, citable sources:

- [Google Engineering Practices](https://google.github.io/eng-practices/) — code review criteria, CL descriptions, small CLs, handling comments
- [Google JavaScript Style Guide](https://google.github.io/styleguide/jsguide.html)
- [Google TypeScript Style Guide](https://google.github.io/styleguide/tsguide.html)
- [Google Python Style Guide](https://google.github.io/styleguide/pyguide.html)
- Meta engineering practices (Sapling stacked diffs, Phabricator Test Plan, React Rules of Hooks, Pyre, Flow) — only what's publicly documented
- Senior-engineer 2026 norms — Kent Beck (TDD prompt + tidy-first
  + "never delete tests"), Geoffrey Huntley (Ralph loop +
  failure-domain logs), Boris Cherny (Plan Mode + verification
  loops + monitors), Birgitta Boeckeler (feedback-loop engineering),
  Andrej Karpathy ("can't outsource understanding"), Stack Overflow
  Mar 2026 AI-PR guidance (prompt-disclosure norm)

The condensed extracts the model uses are in
[docs/standards/](docs/standards/). The synthesis ("what to actually
do") is in [QUALITY-BAR.md](QUALITY-BAR.md).

## What this plugin will NOT do

Explicit refusals (see `skills/reject-bad-tooling/SKILL.md`):

- Run `npm audit fix --force`
- Configure CI to auto-commit fixes back to the branch
- Run `jscodeshift` codemods on a codebase without a test net
- Recommend Preact-for-React swap as a "performance fix"
- Suggest fake or wrong packages (`@snyk/cli`, `npm install semgrep`,
  `babylon-inspector`, `npm-audit`)
- Hardcode fallback secrets in production code
- Pass tests using permissive assertions (`queryAllByText(...).length > 0`)
- Delete tests to make CI pass
- Use `--dangerously-skip-permissions`
- Edit landmine files (per CLAUDE.md) without characterization tests in same diff
- Commit `.env`, `id_rsa`, `.aws/credentials`, AWS/GitHub/OpenAI/JWT patterns

## Plugin self-tests (evals)

Without these, future Claude Code updates can silently break the
discipline. Run with:

```bash
bash evals/runner.sh           # all specs
bash evals/runner.sh -v        # verbose
bash evals/runner.sh secret    # specs with "secret" in name
```

Current coverage: 5 specs validating secret-scan against AWS keys,
GitHub PATs, PEM private keys, `.env` files, and clean diffs.
Pattern from `nizos/tdd-guard` + Anthropic's "Demystifying evals."

Add new specs as you find new failure modes — every fix to a hook
script should land with a spec that reproduces the bug.

## Project layout

```
claude-tdd-pro/
├── .claude-plugin/plugin.json     # Manifest (with userConfig)
├── .mcp.json                       # MCP server bundling (git + github)
├── README.md                       # This file
├── INSTALL.md                      # Install + verification + troubleshooting
├── QUALITY-BAR.md                  # Single source of truth all skills reference
├── docs/standards/                 # Source extracts from Google/Meta
├── skills/                         # 12 skills (auto-triggered)
├── commands/                       # 12 slash commands
├── agents/                         # 8 subagents (incl. 5 review specialists)
├── hooks/
│   ├── hooks.json                  # Setup + PreToolUse + PostToolUse
│   └── scripts/                    # verify-deps, tdd-guard, lint-on-save, secret-scan
├── monitors/monitors.json          # Background processes (test-watcher)
├── templates/                      # CONVENTIONS, PR_BODY, COMMIT_MESSAGE, eslint, prettier, vitest, pyproject, conftest
└── evals/                          # Plugin self-tests
    ├── runner.sh
    └── specs/*.json
```

## Changelog

### v0.2.0 — comprehensive hardening + research-driven additions

**Security (errors fixed):**
- A1/A2/A3: lint-on-save.sh hardened — no more RCE via `npx eslint`
  loading attacker-controlled `eslint.config.js`. Workspace path
  containment, symlinked-ancestor refusal, project-local resolved
  binary only.
- A4: secret-scan.sh — pattern + filename-based pre-commit refusal
  (AWS/GitHub/OpenAI keys, PEM blocks, `.env`, `id_rsa`).
- A5: tdd-driver expanded protected-branch list
  (release/, prod, staging, branch.protected) and hard caps
  (8 commits / 2,000 LOC / 30 min).
- A6: /pr requires exact-token confirmation
  (`CONFIRM-OPEN-PR`), runs `git push --dry-run` first, uses
  `mktemp` not `/tmp/pr-body.md`.
- A7: /pr runs `gh auth status` and surfaces the active GitHub
  account before push.

**Additions (high-leverage):**
- Setup hook (verify-deps).
- PreToolUse `tdd-guard` (opt-in, blocks edits without failing test).
- userConfig (package_manager, test_command, default_reviewer, etc.).
- MCP server bundling (git, github).
- Background monitors (test-watcher).
- Worktree isolation on `tdd-driver` and `pr-self-reviewer`.
- 5-specialist review panel (correctness, security, performance,
  observability, deps) + `/review-panel` chair.
- Plan Mode discipline (`/plan-first`).
- Spec-first workflow (`/spec` + `spec-first` skill).
- ADR / AgDR writer (`/adr`).
- Codebase onboarding (`/onboard`).
- Failure-domain log (`failure-domain-log`).
- Fresh-eyes-review subagent.
- Multi-tool sync (`/sync-rules` → Cursor/Copilot/Aider/Windsurf/AGENTS.md).
- Plugin evals (5 specs, runner).
- Python templates (pyproject.toml + conftest.py).
- CONVENTIONS.md template.
- 3 new explicit refusals: never delete tests, never
  `--dangerously-skip-permissions`, never bypass characterization
  tests on landmine files.

**Strengthened (weaknesses fixed):**
- Hook matcher excludes `node_modules/`, `.git/`, `dist/`, etc.
- Hook timeout dropped 30s → 10s with cache.
- Skill descriptions tightened — side-effecting skills now require
  explicit invocation.
- `paths:` scope on `strict-component-tests` (only loads for
  test files).
- Commit-message vocabulary extended with `tidy:` (Beck) and
  `red:` / `green:` / `refactor:` cycle prefixes.
- PR template adds `AI involvement` section (2026 disclosure norm).
- `pr-self-reviewer` now `disallowedTools: Edit Write` (read-only
  for real, not just by convention).

### v0.1.0 — Initial scaffold

8 skills, 7 slash commands, 3 subagents, 1 PostToolUse hook,
7 templates. Established patterns from prior CS JC AI remediation
session.

## License

MIT.
