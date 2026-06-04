# We are hiring — secondary maintainers for claude-tdd-pro

Per the joint Musk + Fowler review: this is the concrete job
posting. Three slots open. Quarter-end target.

## The role

Secondary maintainer. Apache-2.0 open-source plugin. ~4-8 hours per
month committed time. Code review authority over the
architecture document and core scripts. Documented succession path
to becoming a primary maintainer.

This is not a paid position. It is a credit-bearing position with
real authority on a working codebase that's pioneering AI-augmented
architecture discipline.

## What you'll do

- Review CLs that touch `docs/architecture-v1.9.md`, `CLAUDE.md`,
  `scripts/cl-build.sh`, `scripts/install.sh`, `rubric/runner.sh`,
  or any `rubric/detectors/audit-*.sh` fitness function.
- Drive at least one CL per quarter through the per-CL workflow.
- Participate in the quarterly bus-factor replacement-test rehearsal
  (`docs/REPLACEMENT_TEST.md`).
- Open issues and PRs against the architecture itself when you spot
  drift, gaps, or opportunities for simplification.

## What we offer

- Genuine architectural authority on a project that values it.
- Citation in `CHANGELOG.md` and (with permission) public
  acknowledgement.
- Access to the working primary-maintainer workflow including the
  AI co-maintainer pattern, the cl-build orchestrator, and the
  fitness function suite.
- A demonstrable contribution to a working example of disciplined
  AI-augmented development that you can cite in your own portfolio.

## Three slot specifications

We are specifically seeking three different kinds of maintainer.
Apply to one or more.

### Slot 1 — Architecture reviewer

You read architecture documents critically. You've shipped
production systems with explicit invariants and you know how the
invariants drift.

Required:
- Read `docs/architecture-v1.9.md` end-to-end and write a 500-word
  critique of one phase (your choice).
- Have shipped at least one open-source library with a documented
  contract.

Bonus:
- Familiarity with evolutionary architecture / fitness functions
  (Parsons & Ford).

### Slot 2 — Runtime engineer

You read code differently than the primary maintainer. You've
written production code in Go, Rust, or TypeScript at a level where
you'd be comfortable rewriting `rubric/runner.sh` into a typed
binary (the Go skeleton ships in branch `musk-fowler-fixes`).

Required:
- Build the `runner-go/` skeleton locally; run `go test ./...`;
  open a PR adding one missing feature from the bash runner
  (suggested: `--md` JSONL output, `--severity-floor`, or
  `--quiet` mode).

Bonus:
- LSP server experience.
- Detector / linter authoring experience.

### Slot 3 — AI-native runtime engineer

You think about AI agents as runtime components, not just authoring
tools. You've shipped at least one system where an LLM makes a
decision in the request path with documented confidence handling.

Required:
- Build the `rubric/detectors/llm-judge.sh` workflow locally; pick
  one existing grep-based detector under `rubric/detectors/`; open
  a PR migrating it to use `llm-judge.sh` while keeping
  bash-grep as fallback when no model is available.

Bonus:
- Experience with prompt-versioning, eval-driven model promotion,
  cost telemetry.

## How to apply

Three paths, pick one:

1. **PR-first.** Open a PR matching one of the slot specifications
   above. Tag it `[recruiting]`. We will review within 7 days.
2. **Issue-first.** Open a GitHub issue titled
   `[recruiting] Slot N: <your-name>` with a 2-paragraph
   statement of interest and a link to one of your prior projects.
3. **Direct.** Email the address in commit history (from the
   `mowgli@mowglilion.com` or `drumfiend21@gmail.com` commits).

## Selection criteria

Per Patrick Kua's review note: we hire for **critical reading
ability** and **technical judgment**, not credentials.

- The PR-first path is strongly preferred. A working contribution
  tells us more than a resume.
- We will accept candidates from any background. The AI-augmented
  workflow does not assume you've used Claude or any specific
  model.
- The single hard requirement: ability to read 200 lines of code or
  architecture text and identify a non-trivial issue.

## What's non-negotiable

- All maintainers honor the per-CL workflow loop in `CLAUDE.md`.
- All maintainers honor the four fitness functions; bypasses require
  ADRs.
- All maintainers participate in the quarterly replacement-test
  rehearsal.

That's it. The discipline is the only gate. Welcome.

## Where this fits

- `MAINTAINERS.md` — succession plan + soft-recruit policy
- This document — concrete job posting + slot specs
- `docs/DAY1_MAINTAINER.md` — what you do once selected
- `docs/REPLACEMENT_TEST.md` — quarterly bus-factor proof
