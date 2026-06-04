# 0003. Drift-band closure cycle as the project's reconciliation loop

- **Status:** accepted
- **Deciders:** @drumfiend21
- **Decision_id:** ADR-0003
- **Architect_session:** CL-420 → CL-423 reconciliation arc
- **Profile_active:** standard
- **Date:** 2026-06-03

## Context

Software architectures decay. Features ship with implementation
that drifts from the design over time. The drift-mechanism catalog
in CLAUDE.md (#1-#6) catalogs the failure modes we've observed
directly: compaction loss, audit-checks-process-not-scope,
flagging-as-bypass, approval feedback loop, pattern-cloned
coverage, pending-spec invented vocabulary.

The classical defenses (code review, CI, manual audit) detect
drift inconsistently because they're tuned to LOCAL changes (this
diff) rather than ARCHITECTURAL invariants (does the substrate at
path X exist? does CLI flag Y match the documented surface?).

## Considered options

1. **Trust code review** — what most teams do. Inconsistent at
   scale.
2. **Annual architecture review** — too coarse; drift compounds
   for 11 months before detection.
3. **Drift-band closure cycle** — the choice taken.

## Decision

**Adopt a drift-band closure cycle as the project's reconciliation
loop**: name the bands explicitly, build a detector per band, run
the detectors in CI, close bands as ranged-CL work (not single PRs).

## Decision rationale

A "drift band" is a category of invariant that an automated check
can defend. Concrete bands surfaced in the CL-414 → CL-423 session:

- **Band 1 — Substrate vs §23/§24 surface mismatch.** Detected: X-6
  / X-7 skills missing; X-8 path drift. Closed: CL-420.
- **Band 2 — Specs prove shape not behavior.** Detected: 70% of new
  specs were grep-shape, not behavior. Closed: CL-421 (+33 specs).
- **Band 3 — EXEMPT.txt as bypass for invented vocab.** Detected:
  Q-1 YAML keys diverged from §10 arch prose. Closed: CL-420 vocab
  rename.
- **Band 4 — Pre-existing executable substrate without behavior
  specs.** Detected: 7 features had executable scripts but only
  shape coverage. Closed: CL-422 (+12 specs).

The cycle has four phases:

1. **Audit** — run all gates (§25 + future substrate-completeness +
   CLI-surface). Surface every band where invariants are violated.
2. **Name** — give the band a label (1-4 above) and a one-line
   description.
3. **Close** — write CL(s) that move the invariant back to PASS.
   Include audit findings in commit body (specific, not vague).
4. **Promote the gate to CI** — the detector that found the band
   now blocks regression. The band can never re-open silently.

## Decision rationale (against alternatives)

- **Trust code review** rejected: review depends on the reviewer
  having the architecture text loaded mentally; we've already
  experienced drift mechanism #2 (audit checks process, not scope).
- **Annual review** rejected: drift compounds. The CL-08/09/10
  regression in this project's history wasted ~297 specs because
  drift went undetected for ~10 CLs.

## Provenance

- Reference: drift-mechanism catalog in
  [CLAUDE.md](../../CLAUDE.md#drift-mechanisms-catalog-of-what-caused-prior-deviations)
- Validated: CL-414 → CL-423 session; 4 bands surfaced and closed
  without regression to the 4000-spec suite.

## Controls

- §25 fidelity gate
  (`rubric/detectors/audit-pending-spec-fidelity.sh`) — Band 3
  detector, exists.
- Substrate-completeness gate
  (`rubric/detectors/audit-substrate-completeness.sh`) — Band 1
  detector, **shipping in this CL**.
- CLI-surface fidelity gate
  (`rubric/detectors/audit-cli-surface-fidelity.sh`) — Band 1
  CLI subset detector, **shipping in this CL**.
- Behavior-coverage gate — Band 2/4 detector, **TODO**.

## Future work

The remaining drift bands not yet detector-protected:

- **Band 5 — Pattern-cloned coverage** — needs verb-diversity
  detector across specs per feature.
- **Band 6 — Architectural-text drift** — when arch.md itself
  changes, downstream specs/substrate need re-audit; needs a
  detector that diffs arch.md vs the prior accepted commit.

Both are 1-2 day engineering tasks per ADR-0001's "what I'd do in
the next 7 days" plan.

## Cross-references

- CLAUDE.md drift-mechanism catalog #1-#6
- §25 v1.9.2 pending-spec content fidelity contract
- ADR-0001 (bash runner decision; the drift gates run as bash for
  the same reasons)
- ADR-0002 (npm-style installer; preflight + conflict detection are
  drift gates for the install-time slice of the system)
