# Architecture — first-principles derivation

Per the simulated Musk-team review: this document derives the system
from the customer journey in <200 lines. The 1,177-line
`docs/architecture-v1.9.md` becomes the governance reference and the
historical record. **This document is the canonical operator-facing
architecture.**

## The customer journey (3 sentences)

A developer wants their code to follow Google's published engineering
standards. They install this plugin. From that moment forward, every
file they save is checked, every commit is gated, every PR is reviewed
— against the same rubric, in the same way, with citable provenance
to the upstream standard.

## What that requires (5 things)

1. **A rubric.** The full set of rules, each with provenance to an
   upstream authority (Google, OWASP, W3C, etc.).
2. **A runner.** A way to evaluate any file or project against the
   rubric and report violations.
3. **Three surfaces.** The runner must work in the editor (LSP), in
   pre-commit hooks, and in CI. Identical findings; identical exit
   codes.
4. **A policy layer.** Operators select a profile (`strict`,
   `financial`, `government`, etc.) that adjusts severities and
   activates compliance frameworks.
5. **A discipline.** A workflow that prevents the rubric itself from
   drifting from the upstream standards over time.

That's it. Five things.

## How the system implements those five things (5 components)

| Customer need | System component |
|---|---|
| 1. The rubric | `generated-code-quality-standards/` — 14 source-namespace folders pulled from upstream authorities with provenance per rule |
| 2. The runner | `rubric/runner.sh` — invokes detectors per rule, caches by content-hash, parallel by default |
| 3. Three surfaces | LSP (`lsp/tdd-pro-lsp/`), hooks (`hooks/`), CI (`.github/workflows/` + `.gitlab-ci.yml` + `.pre-commit-config.yaml`) |
| 4. The policy layer | `profiles/` + `.claude-tdd-pro/userConfig.yaml` |
| 5. The discipline | `CLAUDE.md` workflow loop + 4 fitness functions in `rubric/detectors/audit-*.sh` |

The 27 cross-cutting contracts in §2.X of the governance document are
the implementation details of how these 5 components interlock.

## Phases, ranked by customer value

The governance document defines 26 phases. Ranked by direct customer
value:

1. **G — Generated standards.** Without this, there is no rubric.
2. **F — Enforcement.** Without this, there is no runner.
3. **X — Surfaces.** Without this, the runner is invisible.
4. **H — Profiles.** Without this, the rubric is one-size-fits-all.
5. **E — ESLint integration.** Without this, the JS ecosystem is unreached.

The remaining 21 phases (C, P, R, N, T, Q, L, O, W, S) are either
**deepening** (S = standards fetching, C = compliance, R/N/T = stack
specialization), **observability** (Q = SPACE measurement, L = PR
learning), or **operations** (P, O, W = prompts, ops, workflow). They
are valuable; they are not load-bearing for the customer journey.

A v2 of this system could ship the top 5 phases and defer the rest.
**That's the Musk-team simplification target.**

## The AI-nativeness story

The runner today is `bash + grep + node-eval` (per ADR-0001). The
roadmap (see `rubric/detectors/llm-judge.sh`) replaces or augments
detectors with LLM-as-judge calls. Each detector becomes a model
invocation grounded in the rule's source citation. The runner
becomes a coordinator of LLM judgments, not a grep dispatcher.

When this lands:
- Detector logic stops needing per-rule maintenance.
- New rules ship as prompts, not as scripts.
- Per-rule false-positive rate drops because the LLM has full code
  context, not just regex matches.

## The platform-dependency story

This is a Claude Code plugin. It depends on Claude Code's hook API,
slash command surface, agent definition format. If those change, the
plugin breaks. See `docs/PLATFORM_DEPENDENCY.md` for the abstraction
layer that lets the system run **without Claude Code** as a
standalone CLI / LSP / CI gate.

## What's load-bearing today

- The 4,000-spec regression baseline. Cannot delete without losing
  the safety net.
- The 4 fitness functions. Cannot delete without losing drift
  defense.
- The orchestrator (`scripts/cl-build.sh`). Cannot delete without
  losing CL-cycle discipline.
- The installer (`scripts/install.sh`). Cannot delete without losing
  onboarding.
- The rubric runner (`rubric/runner.sh`). Should be **rewritten** in
  a typed binary, not deleted.

## What's been compressed in this document

- 26 phases → 5 ranked.
- 27 cross-cutting contracts → 27 with explicit Tier 1/2/3 ranking
  in `docs/CONTRACT_PRIORITIES.md`.
- 1,177 governance lines → 200 customer-journey lines.
- The amendment blocks (§23 / §24 / §25 / §26) remain in the
  governance document; their feature IDs are listed via their `§X`
  bullet form per the polish work in CL-423.

## Where the long form lives

`docs/architecture-v1.9.md` is the governance document. It is the
source of truth for feature IDs and contract labels. It is **not**
the entry point for operators or new contributors. **This file is.**

The governance document changes via the per-CL workflow in
`CLAUDE.md`. This file changes when the customer journey changes.
