# 0001. Bash + node-eval for the runner and orchestration substrate

- **Status:** accepted
- **Deciders:** @drumfiend21
- **Decision_id:** ADR-0001
- **Architect_session:** initial v1.9 design pass
- **Profile_active:** standard
- **Date:** 2026-06-03

## Context

The plugin needs to execute on every operator's machine without
requiring an additional toolchain install. The substrate spans:

- Rubric runner (`rubric/runner.sh`) — orchestrates 4,000 spec
  invocations, manages a content-addressed cache, runs parallel
  workers.
- Per-CL orchestrator (`scripts/cl-build.sh`) — drives Step 0.5 →
  Step 3 of the workflow loop per CL.
- Installer (`scripts/install.sh`) — npm-style subcommands.
- Hooks (`hooks/scripts/*.sh`) — fire at Claude Code lifecycle events.
- Detectors (`rubric/detectors/*.sh`) — invoked by the runner per rule.

## Considered options

(verbatim per §2.16 / W-1.5):

1. **Bash + node -e shell-outs** — the choice taken.
2. **Pure Go binary** — single static binary, type-safe, fastest
   runtime, requires Go toolchain to develop.
3. **Pure TypeScript / Node** — typed, single language; requires
   Node ≥18 (already a dependency for JSON / inline scripts).
4. **Pure Rust** — fastest, strongest type system, steepest learning
   curve, longest path to first working artifact.

## Decision

**Bash + node-eval shell-outs.**

## Decision rationale

Bash is ubiquitous on macOS, Linux, WSL, and CI. The plugin needs to
boot on a fresh machine with zero additional tooling beyond what
operators already have (`bash`, `git`, `node`, `ruby`). Bash makes
the **first install zero-friction**.

Bash also has a property that matters at this stage: it's
**inspectable**. Every script can be `cat`'d and read end-to-end by
the operator who's about to grant it hook authority over their
Claude session. A compiled Go binary would be opaque; the trust
posture would be different.

The tradeoff is real and named in the architect's review (ADR-0003):
**bash is fragile, hard to type-check, and brittle across platforms.**
The `docs/memory/feedback-bash32-portability-checklist.md` exists
because bash bites. The `node -e '...'` inline-script pattern bit us
in CL-420 → CL-422 when env vars were passed after the command instead
of before (positional args, not env).

## Provenance

- Source: pragmatic choice for v1.0 surface area; no upstream
  authority cited.
- Reviewed: in the architect's review session (this CL).

## Controls

- Bash-3.2 portability checklist
  ([docs/memory/feedback-bash32-portability-checklist.md](../memory/feedback-bash32-portability-checklist.md))
  documents recurring gotchas; every new `.sh` substrate file is
  written with this open.
- The `node -e` anti-pattern is being phased out — env-var-passing
  bug in CL-420 surfaced the cost.

## Rollback / superseding

This ADR is **expected to be superseded** within ~3 days of
engineering effort (see "What I'd do in the next 7 days" in the
architect's review):

- **Day 3-4**: rewrite `rubric/runner.sh` hot path in Go or Rust;
  ship as single binary that bash scripts call.

When that lands, this ADR moves to status `superseded` and a new
ADR documents the rewrite.

## Cross-references

- §2.16 Decision provenance schema
- `docs/memory/feedback-bash32-portability-checklist.md`
- ADR-0003 (drift band closure cycle — captures the engineering
  tradeoffs this ADR enables)
