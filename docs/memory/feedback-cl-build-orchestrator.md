---
name: CL build orchestrator (scripts/cl-build.sh)
description: Use scripts/cl-build.sh to drive the per-CL choreography (§25 fidelity gate → stage → probe → promote → full suite → commit-body skeleton) while preserving every CLAUDE.md integrity gate. Reference at the start of every implementation CL once specs are drafted. Compatible with both single-feature CLs and batch CLs.
type: feedback
---

**Reference this script at the start of every implementation CL on Claude TDD Pro, alongside `feedback-implementation-workflow-checklist.md` and `tdd-pro-cl-workflow` skill.**

**Why:** the per-CL choreography from `CLAUDE.md` Step 0.5 → Step 3 is mechanical (fidelity gate run, filter-run probe, promote, full suite, commit-body draft). Repeating it by hand cost ~3 min/CL of typing + grep-result-aggregation. The orchestrator captures the exact sequence as one command and emits a structured commit-body skeleton.

**Preserves every integrity gate** (this is non-negotiable):

- §25 fidelity gate is run on each pending dir; vocab drift blocks promotion with exit code 3.
- Probe filter-runs each feature; ANY fail rolls back staged specs (exit 4) and preserves the pending dir for re-work.
- Full suite is the final gate; ANY fail exits 5 (staged specs remain so the agent can investigate).
- Commit-body skeleton includes the §25 fidelity result, per-feature probe pass/fail, full-suite count + STATS line, and a structured audit table — the agent fills in `<agent: ...>` placeholders BEFORE running `git commit`.

**Does NOT bypass** (agent still does):

- Step 0 architecture extraction. The agent reads `docs/architecture-v1.9.md` for the target feature and quotes the literal §X.Y line BEFORE drafting specs. The orchestrator does not write specs.
- Step 1 spec authoring. The agent writes the 10 specs per feature into `evals/pending/<phase>/<feature>-<label>/`. The orchestrator only runs the §25 gate against what's there.
- Audit-findings prose in the commit body. The skeleton emits the counted/measured facts; the agent fills the `<agent: ...>` placeholders with feature-specific notes (test-affordance flag disclosure, next-CL scope per §20, spec-patch disclosure if any).
- The actual `git commit` and `git push`. The orchestrator emits a body file at `/tmp/cl-<N>-body.md`; the agent reads, augments, and commits.

## Usage

```bash
# Single-feature CL
bash scripts/cl-build.sh 414 Q Q-1

# Batch CL (multiple features sharing substrate scope, per
# feedback-batch-cl-convention.md)
bash scripts/cl-build.sh 414 Q Q-1 Q-2 Q-3 Q-4 Q-5 Q-6 Q-7 Q-8 Q-9
```

## Per-CL flow

1. **(Agent, Step 0)** Read `docs/architecture-v1.9.md` for the feature(s). Quote the literal §X.Y line.
2. **(Agent, Step 1)** Draft 10 specs per feature into `evals/pending/<phase>/<feature>-<label>/*.json`. Each spec asserts a distinct behavior of the feature, citing arch-quoted vocabulary.
3. **(Orchestrator)** Run `bash scripts/cl-build.sh <cl-number> <phase> <feature-ids...>`. The orchestrator runs §25 fidelity, stages, probes, promotes, full-suite-verifies, and emits the commit-body skeleton.
4. **(Agent, Step 4)** Read `/tmp/cl-<N>-body.md`, fill in `<agent: ...>` placeholders (test-affordance flags, pending counts, next-CL scope per §20), then `git commit -F /tmp/cl-<N>-body.md` (with `-c commit.gpgsign=false` per project convention) and `git push -u origin <branch>`.

## Time saved

The orchestrator replaces ~3 min/CL of manual choreography (typing 5-6 shell commands, parsing their output, copy-paste-aggregating numbers into the body). For 22 remaining feature CLs, that's ~66 min saved. With batch CLs (one orchestrator run for 5-9 features), the saving compounds.

## What batching preserves

The batch convention from `feedback-batch-cl-convention.md` is preserved exactly: when features share substrate scope (Q-1..Q-9 share SPACE substrate; X-1..X-9 share CI/IDE adapter substrate; R-1..R-7 share the React phase substrate), they may ship as ONE commit with a per-feature audit table in the body. The orchestrator's commit-body skeleton emits one row per feature; the agent adds per-feature drift-mechanism notes if any.

## When NOT to use

- The first CL on a new phase where the agent is still settling the §X.Y vocabulary. Per-CL pacing helps catch arch-extraction errors early.
- CLs that require deep substrate review (new APIs, new contracts). The orchestrator only proves the suite is green; it doesn't review architectural soundness.
- Closed-loop validation CLs (S-19, L-24, C-21, E-17, G-14, etc.) which need integration-level review beyond the spec gate.

## Cross-references

- `feedback-implementation-workflow-checklist.md` — the 12-item per-CL checklist this orchestrator codifies steps 0.5 → 3 of
- `feedback-batch-cl-convention.md` — batch-CL discipline (when batching is OK)
- `feedback-pending-spec-content-fidelity.md` — the §25 fidelity gate that the orchestrator invokes
- `feedback-implementation-optimization-plan.md` — the broader implementation-phase optimization plan; the orchestrator is the missing "process automation" layer
