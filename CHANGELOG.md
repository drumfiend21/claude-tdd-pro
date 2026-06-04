# Changelog

All notable changes to this project. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning is reset to [SemVer](https://semver.org/) from 0.4.0 onward and
aligned with the architecture document version where amendments ship new feature surface.

## [Unreleased]

### Added
- `LICENSE` (Apache-2.0)
- `CHANGELOG.md`, `CONTRIBUTING.md`, `CODEOWNERS`
- `docs/adr/0001-bash-runner-and-orchestration.md`
- `docs/adr/0002-npm-style-installer-with-lockfile.md`
- `docs/adr/0003-drift-band-closure-cycle.md`
- `docs/SLO.md` — operational service-level objectives
- `rubric/detectors/audit-substrate-completeness.sh` — drift gate: every arch-named substrate path resolves
- `rubric/detectors/audit-cli-surface-fidelity.sh` — drift gate: CLI flags match arch documentation

### Changed
- Version unified across `README.md`, `scripts/install.sh`, `package.json`: **0.4.0**
- README now leads with CI badges (build status, specs, license)

## [0.4.0] — 2026-06-03

### Added — §20 weeks 13-30 backlog closure (22 architecture features)
- **Q-1..Q-9 SPACE measurement** (CL-414): config, collector, /space-report,
  friction tracker, flow guard, privacy posture, cross-loop integration,
  honest scope, profile auto-select (+90 specs)
- **X-1..X-9 CI/IDE adapters** (CL-415): GitHub Actions, GitLab CI,
  pre-commit, IDE rules export, installable hooks, LSP surface,
  cloud devcontainer (+70 specs)
- **E-4, E-9, E-15 ESLint integration** (CL-416): auto-fix, formatters,
  wrap-eslint (+30 specs)
- **L-3 PR triage filter** (CL-417)
- **O-12 application scaffolds** (CL-418): next-saas, node-api,
  python-fastapi, react-spa
- **P-10 runtime model router** (CL-419)
- **§23 / §24 reconciliation** (CL-420): X-6/X-7 skills, X-8 LSP path,
  Q-1 YAML vocab fidelity
- **Behavior-spec augmentation** (CL-421): +33 behavior specs across
  the 22 newly-shipped features
- **Pre-existing exec-substrate behavior closure** (CL-422): +12 specs
  covering G-7, N-3, P-1, R-3, R-5, T-3, X-1
- **§2.X cross-cutting coverage polish** (CL-423): bullet form for
  v1.11 amendment IDs + 6 specs for §2.11/12/13/16/25
- **Suite total: 3729 → 4000 specs, 0 failed throughout**

### Added — Installer (npm-style)
- `scripts/install.sh`: subcommands (init / upgrade / doctor / uninstall
  / version / help), `.claude-tdd-pro.lock.json`, idempotency, preflight
  toolchain check, descriptive prompts, always-latest semantics,
  conflict detection, parallel clones, background suite verification
- `QUICKSTART.md` — operator-facing 2-min onboarding
- README leads with one-liner install

### Added — Orchestration
- `scripts/cl-build.sh` — drives Step 0.5 fidelity gate → stage →
  filter-probe → remove pending on green → full-suite verify → emit
  commit-body skeleton

### Fixed
- `commands/export-rules.sh` env-var passing — env vars now precede
  `node -e` per bash-3.2 portability gotcha #4 (the trailing
  `PLUGIN_ROOT=... TARGET=...` was being interpreted as positional
  args, leaving `process.env.PLUGIN_ROOT` undefined)

## [0.3.0] — pre-session baseline

See `docs/architecture-v1.9.md` §22 for the canonical pre-amendment
feature list and `docs/memory/` for historical CL audit notes.

[Unreleased]: https://github.com/drumfiend21/claude-tdd-pro/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/drumfiend21/claude-tdd-pro/compare/v0.3.0...v0.4.0
