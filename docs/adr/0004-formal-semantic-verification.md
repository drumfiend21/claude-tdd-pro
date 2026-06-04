# 0004. Formal semantic verification of architectural invariants

- **Status:** proposed
- **Deciders:** @drumfiend21
- **Decision_id:** ADR-0004
- **Architect_session:** xAI interview homework (Greg Yang)
- **Profile_active:** standard
- **Date:** 2026-06-04

## Context

Per the xAI committee review (Greg Yang):

> "The §25 fidelity gate audits vocabulary in pending specs against
>  the architecture text — a syntactic check. The substrate-
>  completeness gate verifies that referenced paths exist — also
>  syntactic. None of the gates verify semantic behavior."

The four fitness functions currently defend against syntactic
divergence between the architecture text and the substrate. They do
not defend against semantic divergence: a spec can use every
approved token, reference every real file path, honor every flag
name, and still test the wrong behavior.

This ADR proposes the path to closing that gap.

## The invariants we want to verify

We pick one invariant for the proof-of-concept and define a formal
verification approach. The choice: **§2.14 dry-run contract** —
"every command listed in the destructive-command subject list MUST
honor `--dry-run` such that no operator-visible state is mutated."

This invariant is currently asserted by:
- `audit-cli-surface-fidelity.sh` checking that `--dry-run` flag
  appears in each subject's substrate (syntactic).
- Per-feature behavior specs checking that `<cmd> --dry-run`
  succeeds with no obvious side effect (procedural).

Neither verifies the **semantic** claim: *the command's
post-state with `--dry-run` is observationally equivalent to its
pre-state for every operator-visible file.*

## Considered approaches

### Approach 1 — Refinement types via gradual TypeScript

Annotate each command's CLI surface with TypeScript types that
encode pre/post conditions:

```typescript
type DryRunSafe<Cmd> = Cmd extends { argv: { '--dry-run': true } }
  ? { effect: 'none', sideEffects: never }
  : Cmd;
```

The type checker proves that the dry-run branch produces no side
effects at compile time. Requires the runtime to be typed.

**Strength:** statically enforced; integrates with the Go runner
roadmap.

**Weakness:** requires migrating all destructive command substrate
to typed code first. Multi-quarter effort.

### Approach 2 — Property-based testing (QuickCheck/Hypothesis style)

For each command, generate N random pre-states; run the command
with `--dry-run`; assert post-state equals pre-state byte-for-byte
across every file in the operator-visible scope.

```go
// runner-go/internal/semantic/dryrun_test.go
func TestDryRunSemantics(t *testing.T) {
    quick.Check(func(state OperatorState) bool {
        snapshot := state.SnapshotFiles()
        runCmd(cmd, "--dry-run", state)
        return state.SnapshotFiles().Equals(snapshot)
    })
}
```

**Strength:** ships incrementally; one command at a time.

**Weakness:** falsification-by-search; doesn't prove correctness,
only absence of falsification within the search budget.

### Approach 3 — Coq / Lean encoding of the §2.14 contract

Write the contract as a formal proposition in a proof assistant:

```coq
Theorem dryrun_preserves_state :
  forall (cmd : Command) (state : OperatorState),
    SubjectOf section_2_14 cmd ->
    Output (cmd --dry-run state) = state.
```

Prove for each subject command by case analysis on its impl.

**Strength:** machine-checked proof of the semantic invariant.

**Weakness:** requires encoding the entire operational semantics
of bash. Roughly a PhD's worth of effort.

## Decision

**Approach 2 — property-based testing, implemented in the Go
runner as a new package `runner-go/internal/semantic/`.**

Roadmap:

1. **CL-X (next 2 weeks):** ship `runner-go/internal/semantic/`
   with the dry-run property-test for one command (e.g.,
   `commands/scaffold.sh`). Default search budget: 100 cases.
2. **CL-X+1 (next month):** generalize to all §2.14 subjects.
3. **CL-X+2 (next quarter):** add per-property test budgets to the
   fitness function suite as `audit-semantic-invariants.sh`.
4. **CL-X+3 (next quarter+):** consider Approach 1 (refinement
   types) if/when the runner moves to typed code beyond the
   semantic package.

## Why not Approach 1 immediately

ADR-0001 commits to the Go runner rewrite at quarter end. Property-
based testing is the right intermediate step: it ships value before
the rewrite completes, and it's the same discipline whether the
runner is bash or Go.

## Why not Approach 3 immediately

Coq/Lean encoding of bash operational semantics is research, not
engineering. The project benefits from semantic verification
incrementally — falsifying property-based searches catch real bugs
before the formal proof would.

## Provenance

- Source: simulated xAI hiring committee feedback (Greg Yang)
- Reference: Claessen & Hughes, "QuickCheck: A Lightweight Tool
  for Random Testing of Haskell Programs" (ICFP 2000)
- Reference: Wadler, "Propositions as Types" (CACM 2015)

## Controls

- The semantic verification package will be gated by
  `audit-semantic-invariants.sh` once shipped.
- Falsifying cases (where property breaks) auto-emit as
  regression specs under `evals/specs/semantic-falsification-<N>.json`.
- Search budget is operator-configurable; CI runs with 1000 cases
  per invariant; local dev with 100.

## Cross-references

- §2.14 destructive command dry-run contract
- ADR-0001 (Go runner rewrite — enabled by this work)
- `docs/FITNESS_FUNCTIONS.md` (this becomes the 6th function)
- `runner-go/internal/runner/runner.go` (where the semantic
  package will live)

## What this moves at the grading level

This ADR is the response to Greg Yang's "B+ on formal rigor"
critique. Once the first property-based test ships (CL-X above),
the gates move from purely syntactic to syntactic + falsifiable-
semantic. That's the discipline xAI wants to see and it's
achievable in increments.

The full straight-A on formal rigor requires the §2.14 invariant
to be verified across all subjects (CL-X+1). That's a sprint, not
a quarter.
