# 0006. Static context injection for external planners (rejecting per-feature consultation)

- **Status:** accepted
- **Deciders:** @drumfiend21
- **Decision_id:** ADR-0006
- **Architect_session:** post-Grok-review of TICKET-034 proposal
- **Profile_active:** standard
- **Date:** 2026-06-06

## Context

The grok-claude-tdd-pro harness's outer-loop planner (Grok) performs
ticket decomposition without visibility into claude-tdd-pro's
durable architectural knowledge: test-shape discipline, R-G-R
sizing constraints, refactoring sequencing, ADR triggers, bash-3.2
portability gotchas, and the AI-failure drift catalog from
`CLAUDE.md`. The observable cost: weak ticket sizing,
mid-ticket scope expansion, missing `depends_on` declarations,
and `file_scope` that doesn't honor mutation seams.

A proposal (TICKET-034, drafted by Grok) suggested closing this
gap with a **dynamic per-feature consultation phase**: Grok would
call Claude TDD Pro with six architectural questions before every
decomposition, persisting the output as
`.harness/handoffs/FEATURE-NNN.architecture.json`.

## Considered options

1. **Per-feature dynamic consultation (the original TICKET-034
   proposal).** New template, new handoff schema, new mandatory
   step in the outer loop, new ADR-0039 in the harness, 2-3 new
   evals. Behind an operator toggle with caching. ~45-60 min of
   implementation work.

2. **Static context injection at session start (this decision).**
   A single `docs/PROJECT_CONTEXT_FOR_PLANNER.md` file in
   claude-tdd-pro that captures the durable knowledge. The
   harness's existing `sync-plugin.sh --ensure` copies it to the
   harness's context-injection path. No new orchestration, no new
   schema, no per-feature round-trip. ~10 min of implementation.

3. **No change.** Accept the observed decomposition quality as the
   floor.

## Decision

**Option 2 — static context injection.**

## Decision rationale

The dynamic consultation proposal was rejected because:

1. **Wrong direction relative to repeated review guidance.** The
   Musk-leadership review explicitly named "framework-itis" and
   "complexity tax" as the project's highest risks. Per-feature
   consultation adds orchestration where the prior reviews said
   simplify.

2. **The six questions Grok proposed are project-wide static
   knowledge, not per-feature dynamic data.** Test-shape
   discipline, refactoring sequencing, mutation seams, ADR
   triggers, bash-3.2 portability are properties of the project
   and change roughly once per quarter. A consultation per feature
   is dynamic dispatch for static data.

3. **Coupling cost not addressed by caching.** Grok's mitigation
   "cache when research bundle + brief hash unchanged" reduces
   latency but not the architectural coupling. Two repos would
   lock-step on the consult schema; every contract change becomes
   a cross-repo CL.

4. **Loss of outer-loop creativity.** The two-tier architecture's
   value is two different models with different strengths. A hard
   contract from Claude TDD Pro on every ticket loses Grok's
   high-level decomposition creativity. This was Grok's own
   critique #2 in the original proposal; Grok then shipped anyway.

5. **Unfalsifiable success criterion.** The proposed success
   measure ("fewer mid-ticket expansions, better depends_on /
   file_scope") cannot be controlled-compared without a baseline
   that the project does not have. Self-reinforcing claim.

Static injection wins on every dimension: zero per-feature latency
or token cost; no new schema or protocol; bounded-context
separation preserved; falsifiable (if decomposition quality does
not improve after two weeks of using the injected context, the
file is one of: too thin, wrong content, or the planner doesn't
read it — each of those is a specific, debuggable signal).

## Implementation

Ships in this CL:

- `docs/PROJECT_CONTEXT_FOR_PLANNER.md` — the static knowledge
  file. Captures: core principles, R-G-R sizing, refactoring
  sequencing, architecture-fidelity invariants, ADR triggers, the
  six drift mechanisms from `CLAUDE.md` (corrected from Grok's
  draft which conflated them with the harness's F-1..F-6 doc-drift
  audits), the seven bash-3.2 portability gotchas (corrected from
  Grok's draft which incorrectly recommended avoiding `[[ ]]` and
  `(( ))`).

Ships in the harness (`grok-claude-tdd-pro`) as a follow-up CL the
operator applies:

- ~5-line patch to `scripts/sync-plugin.sh --ensure` to copy the
  injected file into the harness's planner-context path.
- `docs/adr/ADR-0039.md` documenting the harness-side acceptance
  of the same decision.

## Corrections from Grok's original draft

The draft Grok produced for the static-context file contained
three substantive errors that would have been written into the
planner's permanent context:

1. **"F-1: Stale stub references / F-2: Future references" etc.**
   These are the harness's `audit-doc-drift.sh` audit IDs, not
   the CLAUDE.md drift mechanism catalog. Grok conflated two
   different lists. The corrected file uses the CLAUDE.md #1-#6
   AI failure modes which are what the planner needs to defend
   against at decomposition time.

2. **"Avoid `[[ ]]` and `(( ))` for bash 3.2 portability."**
   Bash 3.2 supports both. The actual gotchas are documented in
   `docs/memory/feedback-bash32-portability-checklist.md` and
   include: no associative arrays, `wc -l` padding, `printf %`,
   env-var-passing-first, `set -u` + empty arrays, BSD grep `--`,
   redirect order. The corrected file lists the real seven.

3. **"Bash 3.2 Portability (C-23)."** "C-23" does not appear as a
   feature ID in `docs/architecture-v1.9.md` or `CLAUDE.md`. Grok
   appears to have invented the label. The corrected file
   references the actual source path
   (`docs/memory/feedback-bash32-portability-checklist.md`)
   instead of a fabricated feature ID.

This correction set is recorded here so any future AI session
reading the planner-context file inherits the *verified* content,
not Grok's draft.

## Provenance

- Source: Grok's original TICKET-034 review of the consult-phase
  proposal (pasted in operator chat)
- Counter-argument: my analysis in the same session, anchored on
  prior Musk-leadership / Fowler+Musk / Sam Newman reviews
- Grok's agreement with the counter-argument followed
- Verified facts: drift mechanisms in `CLAUDE.md`; bash-3.2 gotchas
  in `docs/memory/feedback-bash32-portability-checklist.md`;
  absence of "C-23" in architecture text

## Controls

- `docs/PROJECT_CONTEXT_FOR_PLANNER.md` is reviewed at every CL
  that changes test-shape discipline, R-G-R rules, ADR triggers,
  or the drift mechanism catalog. The file's `## Cross-references`
  section names the upstream sources of truth — changes to those
  sources must be reflected here.
- The harness's `sync-plugin.sh` copies this file as part of its
  existing pin-sync step; no separate handshake test is required.

## Cross-references

- `docs/PROJECT_CONTEXT_FOR_PLANNER.md` — the artifact this ADR
  documents
- `CLAUDE.md` — drift mechanism catalog (source of truth)
- `docs/memory/feedback-bash32-portability-checklist.md` —
  portability gotchas (source of truth)
- `docs/CONTRACT_PRIORITIES.md` — §2.X tier ranking referenced by
  the planner-context file
- `docs/adr/0002-npm-style-installer-with-lockfile.md` — the
  related "static context over dynamic dispatch" pattern at the
  installer layer
