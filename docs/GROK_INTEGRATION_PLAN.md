# Grok integration — merge or separate?

Per the simulated Musk-team review:
> "The grok-claude-tdd-pro repo gets merged into this one or deleted.
>  Two repos for one system is a coordination tax we don't pay."

This document is the decision and the rationale.

## The current state

Two repositories:

- `claude-tdd-pro` (this repo) — the inner-loop runner, rubric,
  fitness functions, and operator surfaces.
- `grok-claude-tdd-pro` ([github.com/drumfiend21/grok-claude-tdd-pro](https://github.com/drumfiend21/grok-claude-tdd-pro))
  — the outer-loop orchestrator: research → decompose → dispatch →
  inner-loop → audit. Vendors this repo at a pinned commit.

The harness consumes this repo via `scripts/sync-plugin.sh --ensure`,
which clones `claude-tdd-pro` at the commit pinned in
`docs/claude-tdd-pro.lock.yaml` into `.harness/plugin-cache/`.

## The two options

### Option A — Merge

Move the harness substrate into this repo under `harness/`. Single
release cadence. Single CODEOWNERS. Single CI pipeline. The
`/research`, `/decompose`, `/dispatch` slash commands become first-class
commands here.

### Option B — Keep separate, formalize the boundary

The harness depends on this repo via a versioned dependency. Mirror
the dependency model with `package.json` engines + a stable API
surface that's documented as the public contract. Breaking changes
here require a deprecation cycle.

## The decision

**Option B, with explicit boundary discipline.**

### Why not Option A

Merging breaks two separations of concern that are real:

1. **The inner loop has a well-bounded responsibility:** rubric
   enforcement on code. The customer journey from
   `docs/FIRST_PRINCIPLES.md` lives here entirely.

2. **The outer loop has a separate well-bounded responsibility:**
   Grok-orchestrated planning + ticket dispatch. The harness's
   value is that the planner can swap models (Grok, Claude, future
   models) without changing the inner loop.

Merging would create a monolith where two distinct customer
journeys collide. That's worse coordination tax than two repos.

### What Option B requires

1. **A documented public API surface.** This repo declares what's
   stable (the orchestrator interface, the spec format, the
   detector contract, the lockfile format) and what's internal
   (substrate file paths, internal scripts). See
   `docs/API_SURFACE.md` — **TODO, next CL**.

2. **A deprecation cadence.** Breaking changes to the public API
   ship in MINOR or MAJOR releases per `docs/RELEASE.md`. Old API
   surface remains supported for one MINOR cycle.

3. **A handshake test in the harness.** `grok-claude-tdd-pro`
   should ship a test that pins to the previous release of this
   repo and confirms the public API surface is unchanged.
   Estimated: 1 hour to write; ongoing maintenance ~0.

4. **Cross-repo CI.** When this repo's `main` advances, the harness's
   CI fires a downstream check. Already partially in place via
   `sync-plugin.sh --check`.

### What stays in this repo (the inner loop)

- Rubric runner
- Fitness functions
- All 26 phases / 27 contracts
- Operator-facing installer
- LSP / hooks / CI surfaces

### What stays in `grok-claude-tdd-pro` (the outer loop)

- `/research` outer-loop research command
- `/decompose` ticket-decomposition command
- `/dispatch` handoff-contract generator
- Worktree-based swarm orchestrator
- Per-ticket tamper-evident manifest (`.harness/<ticket>/*.manifest.json`)

## Cost analysis

| Option | Coordination tax | Boundary discipline | Two-repo overhead |
|---|---|---|---|
| A — Merge | None | Lost | None |
| B — Separate (current) | One sync command | Maintained | Two CIs, two CHANGELOGs |
| B — Separate + formal API | One sync command | **Strengthened** | Two CIs, two CHANGELOGs, one cross-repo handshake test |

Net assessment: the Musk-team critique was correct that "two repos
for one system" is a tax — but the system isn't one customer journey,
it's two. The right defense is to formalize the boundary, not
collapse it.

## What changes this CL

- This document is written.
- `docs/API_SURFACE.md` is on the next-CL roadmap.
- The harness's handshake test is on the cross-repo roadmap.

If the customer journey for the outer loop ever proves illusory
(operators don't actually run `/research` → `/decompose` flow in
production), revisit and merge. The lockfile model gives us
reversibility.
