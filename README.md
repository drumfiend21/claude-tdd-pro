# claude-tdd-pro

A Claude Code plugin that enforces test-first feature development,
strict refactor discipline, and Meta/Google-quality PRs. You describe
features; Claude builds them properly with TDD; your only involvement
with the code itself is reviewing the PR.

## What it does

When installed, this plugin:

- **Auto-triggers TDD discipline** on natural-language feature requests
  ("add a bookmark icon to saved translations") — Claude writes failing
  tests first, runs them, confirms red, writes minimum code to pass,
  refactors, all under a strict standard.
- **Auto-triggers refactor discipline** on extraction requests ("split
  out the chat panel") — Claude writes pre/post tests, confirms baseline,
  extracts, verifies safety net.
- **Auto-triggers strict-test discipline** when writing tests — uses
  `getByRole`, exact counts, jest-dom matchers; refuses
  `queryAllByText(...).length > 0` style permissive assertions.
- **Auto-triggers anti-pattern refusal** when bad tooling is suggested
  (`npm audit fix --force`, auto-commit CI, fake packages).
- **Generates Meta/Google-quality PRs** via `/pr` — Conventional
  Commits, Test Plan section, Behavior + Numbers tables, screenshots
  placeholder, scoped to one self-contained change.
- **Enforces lint-on-save** via PostToolUse hook — every Edit/Write of
  a JS/TS/Python file triggers the project's linter; failures surface
  immediately to the model.

## Installation

### One-time setup on each machine

```bash
mkdir -p ~/.claude/plugins
git clone https://github.com/YOUR_USER/claude-tdd-pro ~/.claude/plugins/claude-tdd-pro
```

That's it. Skills auto-discover; commands appear; hooks register.

### Verifying installation

In any project, try:

```
/feature
```

You should see the slash command listed. Or describe a feature naturally:

```
> add a bookmark icon to each saved translation that toggles favorite status
```

The TDD skill should engage automatically.

## Slash commands

| Command | What it does |
|---|---|
| `/feature <description>` | Builds a feature TDD-first. Asks 1-3 clarifying questions, then runs red-green-refactor per scenario. |
| `/extract-component <target>` | Runs the 9-step test-first refactor. |
| `/fix-bug <description>` | Bug-as-failing-test pattern. |
| `/tighten-tests <file>` | Audits a test file against the strict-assertions bar. |
| `/init-guardrails` | Phase 1 setup on a fresh project (ESLint flat + Prettier + tsconfig checkJs + Husky + lint-staged + vitest). |
| `/snapshot` | Phase 0 setup: tag pre-remediation, write README/CLAUDE.md/REMEDIATION.md. |
| `/pr` | Generates Meta/Google-quality PR description and opens via `gh pr create`. |

## Skills (auto-triggered)

| Skill | Triggers on |
|---|---|
| `tdd-feature-build` | feature requests, "add X to Y", "implement Z" |
| `test-first-extract` | "extract", "split out", "decompose god-file" |
| `strict-component-tests` | writing test files for React/JS/Python |
| `bug-fix-discipline` | "fix bug", "regression", "this is broken" |
| `pr-quality` | conversation turns to PRs, branches, merge |
| `reject-bad-tooling` | suggestions of fake packages, force-fix flags, auto-commit CI |
| `phase-0-snapshot` | first session in a messy/untagged repo |
| `phase-1-guardrails` | no ESLint/Prettier/Husky configs detected |

## Subagents

| Agent | Purpose |
|---|---|
| `strict-test-writer` | Delegates writing strict tests for a target file. |
| `pr-self-reviewer` | Pre-PR self-review against the Meta/Google checklist. |
| `tdd-driver` | Autonomous full red-green-refactor loop for a multi-scenario feature. |

## What the standards are based on

This plugin's quality bar comes from public, citable sources:

- [Google Engineering Practices](https://google.github.io/eng-practices/)
  — code review criteria, CL descriptions, small CLs, handling comments.
- [Google JavaScript Style Guide](https://google.github.io/styleguide/jsguide.html)
- [Google TypeScript Style Guide](https://google.github.io/styleguide/tsguide.html)
- [Google Python Style Guide](https://google.github.io/styleguide/pyguide.html)
- Meta engineering practices (Sapling, Phabricator, React Rules of
  Hooks, Pyre, Flow) — only what's publicly documented; no invented
  "Meta style guide."

The condensed extracts the model uses are in
[docs/standards/](docs/standards/). The synthesis ("what to actually
do") is in [QUALITY-BAR.md](QUALITY-BAR.md).

## What this plugin will NOT do

These are explicit refusals (see `skills/reject-bad-tooling/SKILL.md`):

- Run `npm audit fix --force` (semver-bump risk; use plain `npm audit fix`).
- Configure CI to auto-commit fixes back to the branch.
- Run `jscodeshift` codemods on a codebase without a test net.
- Recommend Preact-for-React swap as a "performance fix."
- Suggest fake or wrong packages (`@snyk/cli`, `npm install semgrep`).
- Hardcode fallback secrets in production code.
- Pass tests that use permissive assertions (`queryAllByText(...).length > 0`).

## Project layout

```
claude-tdd-pro/
├── .claude-plugin/
│   └── plugin.json                # Plugin manifest
├── README.md                      # This file
├── QUALITY-BAR.md                 # Single source of truth all skills reference
├── INSTALL.md                     # Detailed install + verification steps
├── docs/
│   └── standards/                 # Source extracts from Google/Meta
│       ├── google-eng-practices.md
│       ├── google-js-ts-style.md
│       ├── google-python-style.md
│       └── meta-engineering.md
├── skills/                        # Auto-triggered behaviors
│   ├── tdd-feature-build/
│   ├── test-first-extract/
│   ├── strict-component-tests/
│   ├── bug-fix-discipline/
│   ├── pr-quality/
│   ├── reject-bad-tooling/
│   ├── phase-0-snapshot/
│   └── phase-1-guardrails/
├── commands/                      # Explicit slash commands
│   ├── feature.md
│   ├── extract-component.md
│   ├── fix-bug.md
│   ├── tighten-tests.md
│   ├── init-guardrails.md
│   ├── snapshot.md
│   └── pr.md
├── agents/                        # Subagents
│   ├── strict-test-writer.md
│   ├── pr-self-reviewer.md
│   └── tdd-driver.md
├── hooks/
│   └── hooks.json                 # PostToolUse: lint-on-save
└── templates/                     # Reusable configs the skills install
    ├── eslint.config.flat.js      # Node / vanilla JS
    ├── eslint.config.flat.react.js
    ├── prettierrc.json
    ├── tsconfig.checkjs.json
    ├── vitest.config.with-cleanup.js
    ├── test-setup.js              # jest-dom + cleanup discipline
    ├── COMMIT_MESSAGE.md
    └── PR_BODY.md
```

## Development

### Updating the plugin

```bash
cd ~/.claude/plugins/claude-tdd-pro
git pull
```

Restart your Claude Code session for changes to take effect.

### Contributing

This is a personal plugin — fork and adapt for your team's conventions.
The patterns here are derived from the author's specific codebase
remediation work; your team may have different style preferences,
different test frameworks, different PR templates.

The `QUALITY-BAR.md` file is the place to start customizing — every
skill references it.

## License

MIT. Use, fork, and adapt freely.
