# 0009. Auto-classification + custom-rule drafting pipeline

- **Status:** accepted
- **Deciders:** @drumfiend21
- **Decision_id:** ADR-0009
- **Architect_session:** GCTP COMPLETE-ARCHITECTURE-FOR-CTP handoff (pinned `grok-claude-tdd-pro@31d77487`), paired with upstream draft `proposals/ctp-adr-drafts/CTP-ADR-NNNN+1-auto-classification-and-rule-drafting-pipeline.md`
- **Profile_active:** standard
- **Date:** 2026-06-20

## Context

Once the composite engine lands (ADR-0008) the runtime is rule-hungry
but catalog-thin beyond the seeded set. Operators want to ingest
world-class standards (Google, Microsoft, OWASP, federal bodies,
internal wikis) — potentially 500–1,000 rules per organization. Today
each rule needs manual extraction, classification, DSL translation, and
review: multi-month work that does not scale.

The architectural innovation this ADR commits to is **"no language
silently dropped"**: when an LLM drafts a tool rule (e.g. a Semgrep rule)
from a prose standard, **every prose clause** must end up either
deterministically enforced in a tool DSL, semantically enforced via
`prose-judge.sh`, or explicitly flagged un-enforceable with operator
sign-off — never silently lost.

## Considered options

1. **Manual per-rule authoring.** REJECTED — catalog size makes this
   multi-month; does not scale with the operator's source set.
2. **Skip fidelity verification (trust the LLM draft).** REJECTED —
   silent clause drops break the "every rule enforced" guarantee; the
   four-layer coverage mechanism is mandatory.
3. **Operator manually attaches the architectural-content bundle per
   rule.** REJECTED — invites oversight; auto-binding on
   `applies_to_prose: true` is the universal contract.
4. **Auto-accept high-confidence rules without review.** REJECTED as the
   default — human-in-the-loop is the default; a bulk-accept opt-in is
   available for high-trust operators.
5. **Adopt the upstream six-stage pipeline + four-layer fidelity (this
   decision).**

## Decision

**Adopt the upstream `CTP-ADR-NNNN+1` draft as TIER-1 authority and the
canonical CTP rule-supply roadmap.** A six-stage pipeline feeds
`active.json`, with a four-layer fidelity discipline guaranteeing no
clause is silently dropped:

**Six stages:**
1. **Extract** — `standards-refresh.sh` scrapes source URLs;
   `extract-rules-from-url.sh` segments per document shape (markdown
   headings, HTML sections, numbered lists, free prose, PDFs).
2. **Classify** — `classify-rule.sh` tags each rule with the ADR-0008
   4-axis vocabulary + the `applies_to_prose` boolean. Tier-1 =
   deterministic inverted-index lookup; Tier-2 = LLM judgment with
   confidence scoring.
3. **Route** — static `kind-to-tool-routing.yaml` maps canonical kinds
   to FOSS tools.
4. **Architectural-content auto-binding** — `applies_to_prose: true`
   unconditionally appends `{ bundle: architectural-content }`; ADR-only
   rules bind solely to the bundle.
5. **Draft with four-layer fidelity** — `draft-custom-rule.sh` translates
   prose to tool DSL through: **Layer A** prompt demands every clause be
   translated or flagged; **Layer B** round-trip coverage diff (each
   clause → "covered by DSL line N" or "not covered, reason"); **Layer C**
   positive+negative test-fixture generation; **Layer D** coverage gaps
   route to **`prose-judge.sh`** as the semantic fallback binding.
6. **Review** — `review-queue.sh` routes by confidence: high-confidence
   zero-gap auto-stages for batched commit; high-confidence-with-gaps
   needs coverage-report review; medium/low gets side-by-side review.

**Critical contract:** every prose clause is (a) deterministically
enforced in a tool DSL, (b) semantically enforced via `prose-judge.sh`,
or (c) explicitly flagged un-enforceable with operator sign-off. Never
silently dropped.

## Decision outcome

We **chose** the automated pipeline because operator-scale catalogs
(hundreds–thousands of rules across many published sources) are
infeasible to hand-author, and **decided** the four-layer fidelity
discipline is non-negotiable — it is the only mechanism that makes the
"every rule enforced, no language silently dropped" guarantee
auditable, with a coverage report mapping each clause to a deterministic
or semantic binding. Layer D's fallback to `prose-judge.sh` is what
relies on the **P-8 fix** landed in this CL; Waves 1 and 3 of ADR-0008
can ship before this pipeline's Wave 2, so the dependency does not block
the engine.

## Consequences

- **Positive.** Catalog ingest moves from multi-month manual work to
  multi-week automated runs; every rule ships with source URL + a
  clause-coverage report + test fixtures (audit-defensible provenance);
  prose-applicable rules auto-attach the architectural-content bundle so
  the semantic moat fires on every ADR for applicable rules; the catalog
  grows with the operator's source set with no per-rule engineering.
- **Cost / neutral.** LLM token cost is bounded by hash caching and
  one-time-per-rule drafting (≈<$1/rule); deterministic Tier-1
  classification handles ~60–70%, the LLM tier the residual. Operator
  review is the human bottleneck (bulk-accept mitigates).
- **Negative / risk.** LLM dependence for classify+draft (mitigated by
  deterministic Tier-1 + hash cache); DSL quality depends on model
  capability (mitigated by per-tool fixture-equivalence tests + review);
  **depends on the P-8 fix** (Layer D) — satisfied in this CL.
- **Boundary.** CTP does not edit GCTP; paired with GCTP ADR-0069.

## Provenance

- Upstream draft: `grok-claude-tdd-pro@31d77487:proposals/ctp-adr-drafts/CTP-ADR-NNNN+1-auto-classification-and-rule-drafting-pipeline.md`
- Paired GCTP-side ADR: `grok-claude-tdd-pro:docs/adr/0069-gctp-side-auto-classification-pipeline-wiring.md`
- Builds on: ADR-0008 (4-axis vocabulary + composite engine) and ADR-0007 (`prose-judge.sh`, `applies_to_prose`).

## Cross-references

- `docs/adr/0008-composite-engine-and-4-axis-canonical-vocabulary.md` — the paired engine ADR.
- `docs/architecture-v1.9.md` §28.28 — the append-only amendment.
- `rubric/detectors/prose-judge.sh` / `rubric/detectors/llm-judge.sh` — Layer-D semantic fallback + the P-8 fix.
