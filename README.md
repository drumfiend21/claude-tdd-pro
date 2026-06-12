# claude-tdd-pro

[![CI](https://github.com/drumfiend21/claude-tdd-pro/actions/workflows/rubric-check.yml/badge.svg?branch=main)](https://github.com/drumfiend21/claude-tdd-pro/actions/workflows/rubric-check.yml)
[![specs](https://img.shields.io/badge/specs-4149_passed-brightgreen)](evals/specs/)
[![architecture](https://img.shields.io/badge/architecture-v1.9.2_%2B_v1.10_%2B_v1.11-blue)](docs/architecture-v1.9.md)
[![license](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![version](https://img.shields.io/badge/version-0.4.0-informational)](CHANGELOG.md)

## 🚀 Quick Start — one command, <60 seconds

```bash
curl -fsSL https://raw.githubusercontent.com/drumfiend21/claude-tdd-pro/main/scripts/install.sh | bash
```

Interactive prompts walk you through profile, harness, and LSP wiring. Background rubric verification runs while you start coding. **See [QUICKSTART.md](QUICKSTART.md) for the full walk-through, subcommands (`init` / `upgrade` / `doctor` / `uninstall`), conflict handling, and lockfile semantics.**

```bash
# Scripted / CI (npm init -y pattern):
curl -fsSL .../install.sh | bash -s -- init --yes

# Full kit with Grok harness:
curl -fsSL .../install.sh | bash -s -- init --yes --profile strict --with-grok --with-lsp
```

---

## What is this?

A Claude Code plugin that elevates any codebase to **Google's
published engineering standards** (eng-practices, JS/TS style, Python
style) and keeps it there. Drop the plugin into any Claude install,
point it at any repo, run `/analyze` for a citable compliance report,
run `/remediate` for a small-CL elevation pass. For greenfield code,
every prompt is gated through the same RUBRIC.yaml so output is
born-compliant.

**Current version: 0.4.0** — see [CHANGELOG.md](CHANGELOG.md).

## Cloud Architect — a grounded, eng-team-in-a-box for cloud architecture

A non-technical founder can describe an app in **plain business language** and
the plugin guides them to a **complete, world-class, fully-cited full-stack +
cloud architecture** — deployable to **AWS, Azure, or GCP** — where *every
decision is justified by a cited tier-1 authority* (AWS Well-Architected, NIST
800-53, OWASP ASVS/Secure Headers, OAuth 2.0, SemVer, Google SRE, OpenTelemetry,
Enterprise Integration Patterns, Patterns of Distributed Systems, and more).

The flow runs through one entry function and the same TDD discipline as the rest
of the plugin:

1. **Intake** (`architect-session.sh`) — Listen → Probe → Clarify; asks the next
   question until it understands the business need (it never guesses).
2. **Translate** — maps the business need to grounded technical concerns across
   database, scaling, security, identity (authn/authz), object storage, REST +
   real-time APIs, messaging, distributed patterns, observability (logging +
   analysis), testing, dependency versioning, edge/headers/CORS, and global
   delivery (CDN, multi-region).
3. **Compose & score** — generates multiple grounded options with trade-offs and
   ranks them against four objectives: cost, performance, customer satisfaction,
   and shareholder value.
4. **Build & enforce** — decisions become MADR ADRs, test-first (red→green) IaC
   build units, and grounded convention enforcement (Terraform/Bicep/CloudFormation).

**See it work:** [docs/DEMO.md](docs/DEMO.md) is a real, reproducible run that
turns a founder's vision into a **51-decision design, every decision cited across
17 world-class authorities**. The canonical output is pinned as a golden
reference in [`standards/golden/`](standards/golden/) and
[`docs/golden/`](docs/golden/fullstack-international-aws-architecture.md), and a
**standing conformance contract** (architecture §27.27) requires *all* output to
be fully cited, gated by the end-to-end integration suites. The continuously-monitored
source catalog is in [`standards/SOURCES.md`](standards/SOURCES.md).

## The two flows

**Existing repo**: install → `cd repo` → `/analyze` → review the
generated `COMPLIANCE-REPORT.md` and `LANDMINES.md` → `/remediate`
(token-confirmed) → land the small-CL chain → `/pr`.

**Greenfield code**: install → start a session → every code-emitting
prompt fires through paths-scoped Google-style skills (`google-style-ts`,
`google-style-py`), TDD-Guard (default-on), the rubric runner, and
the Stop hook (on side-effecting flows). Output is compliant before
it lands.

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

## Slash commands (16)

| Command | What it does |
|---|---|
| `/analyze` | Cold-start audit. Runs RUBRIC.yaml against the working tree; emits `COMPLIANCE-REPORT.md` (P0/P1/P2 findings with citations) and `LANDMINES.md` (high-risk files). Read-only. |
| `/remediate` | Token-confirmed execution of the audit's remediation plan. Small CLs (≤400 lines, Google small-CL rule), Tidy-First split (Beck), Ralph-loop iteration, Stop-hook gated. |
| `/feature <description>` | Build a feature TDD-first via the `tdd-feature-build` skill |
| `/spec <description>` | Write a Markdown spec FIRST, before any code |
| `/plan-first <description>` | Plan Mode discipline — produce a plan, get approval, then code |
| `/extract-component <target>` | 9-step test-first refactor pattern |
| `/fix-bug <description>` | Bug-as-failing-test pattern |
| `/tighten-tests <file>` | Audit a test file against the strict-assertions bar |
| `/review-panel` | 6-specialist parallel review panel + review-verifier filter + chair synthesis |
| `/init-guardrails` | Phase 1 setup with Google-tuned configs (eslint-config-google, ruff.google.toml, mypy.google.ini) |
| `/snapshot` | Phase 0 setup (tag + README + CLAUDE.md + REMEDIATION.md) |
| `/onboard` | Codebase tour + propose CLAUDE.md from observed conventions |
| `/adr <decision>` | Write an Architecture Decision Record (MADR format) |
| `/sync-rules` | Generate Cursor/Copilot/Aider/Windsurf/AGENTS.md from CONVENTIONS.md |
| `/remember [lesson]` | Compound Engineering loop. Pin a recurring mistake to CLAUDE.md, optionally promote to a new RUBRIC.yaml rule. |
| `/doctor` | Smoke-test every primitive; report green/yellow/red toolchain matrix |
| `/pr` | Open a Google-quality PR (Conventional Commits + Test Plan + AI involvement + Assisted-by trailer) |

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

## Subagents (11)

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
| `review-google-style` | Specialist (Google style + eng-practices judgment rules) — every finding cites a RUBRIC.yaml id |
| `review-verifier` | Re-grounds Critical/High findings against actual code; classifies CONFIRMED / OUT-OF-DATE / MISATTRIBUTED / FALSE-POSITIVE / MITIGATED — pattern from Anthropic's March 2026 Code Review (16% → 54% coverage) |

## Hooks

| Event | What runs | Why |
|---|---|---|
| `Setup` | `verify-deps.sh` | First-session check for `gh`, `node`, `ruff`, `gh auth status` |
| `PreToolUse` (Edit/Write/MultiEdit) | `tdd-guard.sh` | DEFAULT-ON: blocks source edits without a failing test |
| `PostToolUse` (Edit/Write/MultiEdit) | `lint-on-save.sh` | RCE-hardened: lints the just-written file |
| `Stop` | `stop-rubric-gate.sh` | Refuses session completion on P0 rubric findings, secret leaks, or lint failures. **Narrowed**: only fires when active-flow is one of `remediate`, `pr`, `feature`, `fix-bug`, `extract-component`. Greenfield free editing rides PreToolUse + PostToolUse only. |

The TDD guard is now ON by default (matches Google eng-practices'
tests-with-change requirement). Opt out per-project with
`touch .claude-tdd-pro/tdd-guard.disabled` or env
`CLAUDE_TDD_PRO_GUARD=off`.

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

## Language coverage (H-5 multi-language honesty)

**First-class** (full rule coverage): JavaScript, TypeScript, Python.
**Partial** (rule scaffold available, full coverage in roadmap): Go, Ruby, Rust.
The plugin is honest about partial coverage: `/doctor --check coverage` and
`/analyze --root <dir>` surface a coverage-caveat block whenever the repo
contains files in a partial-coverage language.

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

Current coverage: 12 specs validating
- secret-scan against AWS keys, GitHub PATs, PEM private keys, `.env`
  files, and clean diffs
- rubric-runner emits valid JSON
- cl-size detector blocks oversized diffs and passes small ones
- tests-coupled detector flags source changes without paired tests
- refused-flags detector blocks `--dangerously-skip-permissions`
- stop-rubric-gate is a no-op without `active-flow`

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

### v0.3.0 — drop-in Google-standards elevator

The plugin now answers the question: "drop into any Claude on any
computer, point at any repo, deliver code that meets Google's
published engineering standards." Every change in this release was
validated twice against current Claude Code docs and against
publicly-published principal/staff engineering practice (Boris
Cherny, Geoffrey Huntley, Kent Beck, Birgitta Boeckeler, Anthropic
Code Review March 2026).

**Foundational:**
- Executable `RUBRIC.yaml` (30 rules) derived from
  `docs/standards/google-{eng-practices,js-ts-style,python-style}.md`.
  Every rule cites upstream Google source + local anchor + detector
  kind + remediation skill.
- `rubric/runner.sh` dispatches per detector kind: delegates to
  `eslint-config-google`, `ruff`, `mypy`, `tsc` where they cover the
  rule; falls back to custom scripts only for prose-only practices.
- `rubric/adapters/` ships Google-tuned configs:
  `eslint.google.cjs`, `ruff.google.toml`, `mypy.google.ini`.
- 6 custom detectors: `cl-size`, `cl-description`, `tests-coupled`,
  `refused-flags`, `secret-scan` (adapter), `pyink-check`.

**New flows:**
- `/analyze` — read-only cold-start audit. Emits
  `COMPLIANCE-REPORT.md` + `LANDMINES.md`.
- `/remediate` — token-confirmed (`CONFIRM-REMEDIATE`) execution.
  Small CLs (≤400 LOC), Tidy-First split (Beck), Ralph-loop
  iteration over the backlog, Stop-hook gated.
- `/remember` — Compound Engineering loop. Pin a recurring mistake
  to CLAUDE.md and optionally promote to a new RUBRIC.yaml rule.
- `/doctor` — green/yellow/red toolchain matrix; smoke-tests every
  primitive in <30 seconds.

**New plugin primitives (2026-native):**
- `paths`-scoped per-language skills `google-style-ts` and
  `google-style-py` replace UserPromptSubmit injection (which the
  validation pass flagged as obsolete and CLAUDE.md-budget-blowing).
- `output-styles/`: `google-strict`, `tdd-driver`, `pr-author` —
  deterministic prose voice.
- `.lsp.json` — declares `typescript-language-server` and `pyright`
  as optional plugin LSP servers for real semantic info.
- Plugin manifest: `harness_version` field surfaced in PR bodies so
  reviewers can correlate quality regressions to plugin versions.
- `userConfig`: new `attribution_style` (`assisted-by`/`co-authored-by`/`none`)
  and `rubric_severity_threshold` (`P0`/`P0+P1`/`P0+P1+P2`).

**Hooks:**
- New `Stop` hook (`stop-rubric-gate.sh`) that gates session
  completion on rubric P0 + secrets + lint. Narrowed: only fires for
  `remediate`/`pr`/`feature`/`fix-bug`/`extract-component` flows
  (per validation: gating every greenfield prompt is overkill —
  Cherny/Huntley don't do this).
- TDD-Guard flipped to default-on (matches Google eng-practices'
  tests-with-change rule). Opt out via
  `.claude-tdd-pro/tdd-guard.disabled` or `CLAUDE_TDD_PRO_GUARD=off`.

**Review panel:**
- Added `review-google-style` specialist (rules lint can't catch:
  naming intent, comment "why not what", no bundled refactor+feature,
  CL description shape, design-belongs-here, YAGNI). Every finding
  cites a RUBRIC.yaml rule id.
- Added `review-verifier` re-grounds every Critical/High against
  actual code, classifies CONFIRMED / OUT-OF-DATE / MISATTRIBUTED /
  FALSE-POSITIVE / MITIGATED. Pattern from Anthropic's March 2026
  Code Review which raised review coverage 16% → 54%.

**AI disclosure:**
- Switched all `Co-Authored-By: Claude` trailers to
  `Assisted-by: Claude (claude-tdd-pro 0.3.0)`. Per Linux kernel AI
  Coding Assistants policy (April 2026), `claude-code#36105`, and
  the May 2026 VS Code Copilot reversal.

**Self-tests:**
- Eval suite expanded from 5 → 12 specs covering rubric-runner JSON,
  cl-size, tests-coupled, refused-flags, stop-gate.

**What was deliberately NOT done:**
- No `curl|bash` installer. Anthropic's `/plugin` Discover is the
  documented install path; bypassing it adds attack surface for no
  benefit.
- No "FAANG-quality" rubric synthesizing Meta/Stripe/Google. The
  user explicitly scoped this to Google's published standards. We
  cite only what's in `docs/standards/google-*.md`.
- No `UserPromptSubmit` rule injection. Validation flagged it as
  obsolete and CLAUDE.md-token-budget-blowing; replaced with
  `paths`-scoped skill activation.
- Custom token gating on `/remediate` (CONFIRM-REMEDIATE) IS kept
  even though docs offer agent-teams plan-approval — token gating
  is the lower-coupling option that doesn't require teammate setup.

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
