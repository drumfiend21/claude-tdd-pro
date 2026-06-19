# 0007. YAML/JSON/MD rule corpora and the prose-as-code judge (`prose-judge.sh`)

- **Status:** accepted
- **Deciders:** @drumfiend21
- **Decision_id:** ADR-0007
- **Architect_session:** PROPOSAL-003 CTP session brief (fetched from grok-claude-tdd-pro/main/proposals/PROPOSAL-003-ctp-session-brief.md and treated as the authoritative work directive)
- **Profile_active:** standard
- **Date:** 2026-06-19

## Context

The consuming harness (GCTP) ran a real engagement and surfaced a
dead zone in Claude TDD Pro's enforcement surface. CTP enforces
**code shape** thoroughly — TypeScript, React, IaC (`g-aws-*` /
`g-gcp-*` / `g-azure-*` …), and polyglot universal patterns
(`g-universal-*`) — but the **architectural prose that decides the
design** is never enforced against those same rules. The ADR that
*proposes* `0.0.0.0/0` ingress, the design doc that *chooses* `any`,
the README that *promises* a plaintext secret: the implementing code
gets caught by the existing detectors, but the decision that caused
it sails through. The empirical finding in PROPOSAL-003: the same
`g-aws-no-unrestricted-ingress` rule that fires on a `.tf` file should
also fire on an ADR that proposes unrestricted ingress — **before**
the Terraform is written. This is the **prose-as-code principle**:
one rule, one gate, two surfaces.

A second, larger gap: whole config/markup families (YAML, JSON, and
Markdown) have no first-class rule corpora at all, so K8s manifests,
GitHub Actions workflows, IAM policies, JWT handling, SBOMs, and ADRs
are enforced weakly or not at all. PROPOSAL-003 specifies 22 new rule
namespaces seeded from a 155-source master manifest (§6), plus SARIF
2.1.0 as the universal detector output bus.

The brief is explicit (§11) that of everything proposed, the single
**architecturally novel** piece is the `applies_to_prose` flag plus
the `prose-judge.sh` semantic-projection detector. The 22 namespaces,
the Layer-1 tool wrappers, SARIF, and the refresh entries are
**rule-content density** — important, but CTP already knows how to
author rule content. The novel substrate is the semantic projector.

## Considered options

1. **Author a single mega-detector that handles all 22 new
   namespaces.** REJECTED — violates §2.2's per-rule detector
   contract; makes failure attribution opaque; precludes per-rule
   SARIF; breaks the existing `enforce.sh` dispatch loop.

2. **Bundle prose-judge as an internal feature flag rather than a
   flag on the rule shape.** REJECTED — that hides the opt-in from
   the rule registry, and the consuming harness's static gates
   cannot then enforce the prose floor. The flag belongs in the rule
   body so the channel is transparent.

3. **Default `applies_to_prose: true` for every rule.** REJECTED for
   v1 — too aggressive a default; many syntactic rules have no
   meaningful prose analog and would generate ABSTAIN noise.
   Defaulted `false`; promote per rule.

4. **Skip SARIF; define a CTP-native finding format.** REJECTED —
   fragments the ecosystem for no benefit. SARIF 2.1.0 is the
   OASIS standard; every linter in the corpora already emits it.

5. **Make `prose-judge.sh` eager (run on every MD, every session).**
   REJECTED — unbounded token cost. Cache by `(rule_body_hash,
   prose_section_hash)` and run only opt-in via
   `CLAUDE_TDD_PRO_PROSE_JUDGE_EAGER=1`.

6. **Reach across the contract boundary into the consuming harness.**
   REJECTED — the harness consumes CTP as a pinned plugin; CTP must
   not know about its consumers. Only the contract surface
   (`active.json` + `rubric/detectors/`) moves.

## Decision

**Adopt PROPOSAL-003 in full as the directive, landing it additively
as architecture amendment §28.24, and execute it in three waves —
each wave its own pin bump — with the novel substrate landed first.**

- **CTP-D-2 / CTP-D-3 (the novel substrate) — landed in this CL.**
  `applies_to_prose: bool` (default `false`) + `applies_to_prose_kinds:
  string[]` (default `["architecture","adr"]`) added additively to
  `schemas/rubric-rule.schema.json`. `rubric/detectors/prose-judge.sh`
  added as a first-class detector: any rule body + any prose section →
  YES (violates) / NO (compatible) / ABSTAIN, three tiers
  (deterministic keyword → `LLM_JUDGE=1` semantic → not_enforced
  fallback), cache by `sha256(rule_body+literals)+sha256(section)`,
  SARIF 2.1.0 output, 4-state exit (0/1/3/2) mirroring the §28.17
  `enforce.sh` contract so a not_enforced prose check never collapses
  to green.

- **Wave-1 down payment — landed in this CL.** The `md` namespace
  (`g-md-fenced-code-language-declared` [MD040], `g-md-single-h1`
  [MD025]) via a new deterministic, dependency-free Layer-1 detector
  `rubric/detectors/md-structure.sh`, fully wired through `enforce.sh`
  (RULE_DRIVEN dispatch + `g-md-*` → `*.md` ns_glob), registered in
  `validate-all.sh KNOWN_NAMESPACES`. Grounded in CommonMark 0.31.2 +
  markdownlint MD0xx (provenance), so it passes the §2.33 citation
  auditor.

- **Waves 1 (remainder) / 2 / 3 — rule-content density, per-wave pin
  bumps.** Wave 1: `yaml` + `k8s` + `md` (Layer 1) + `arch`
  (template-shape) ~50 rules. Wave 2: `json` + `jwt` + `iam` + `sbom`
  + `sarif` ~60 rules (P0 cluster: JWT BCP RFC 8725 + IAM wildcards;
  SchemaStore; SARIF self-conformance). Wave 3: all CI/CD/IaC
  namespaces + activation of the `prose-judge.sh` LLM engine ~100+
  rules. Each wave: ADR delta + tests + standards-refresh entry +
  SKILL.md note. The §6 source master tables are lifted verbatim into
  `docs/standards-source-manifest.md`.

## Decision outcome

We **chose** to adopt the brief in full because the prose-as-code gap
it identifies is a genuine correctness hole — the gate fires on the
symptom (the code) but not the cause (the decision), so a design that
violates an `active.json` rule is only caught after the implementing
code is written. The `applies_to_prose` + `prose-judge.sh` mechanism
closes that by construction: same rule, same gate, projected onto the
prose surface, **before** code exists.

We **decided** to land the novel substrate and a Wave-1 down payment
in this CL, then stage the remaining ~200 rules wave-by-wave, because
the brief itself sequences the work as three independent pin bumps
(§9) and because the substrate is the part that requires architectural
review — the rest is rule-content authoring CTP already does
routinely. Landing the substrate first means Wave 3's LLM activation
needs no further substrate work; it is purely a matter of promoting
rules with `applies_to_prose: true`.

The rationale for each rejected alternative is recorded under
**Considered options** above: per-rule detectors over a mega-detector
(failure attribution + per-rule SARIF), the flag on the rule shape
over an internal flag (registry transparency for the consumer's static
gates), `false`-by-default over `true` (ABSTAIN-noise control), SARIF
over a native format (ecosystem interop), cached+opt-in over eager
(bounded token cost), and strict contract-boundary discipline
(`active.json` + `rubric/detectors/` are the only surfaces that move).

## Consequences

- **Positive.** Architectural decisions become first-class enforcement
  targets; the same rule corpus governs code and the prose that
  designs it. SARIF 2.1.0 unifies detector output across the whole
  expanded corpus. The 22 namespaces close the YAML/JSON/MD dead zone.
  The substrate is additive (schema fields default off; detector is
  new), so nothing existing changes behavior until a rule opts in.
- **Negative / cost.** Wave 3's LLM tier carries token cost — mitigated
  by the `(rule_body, section)` cache and opt-in-only eager mode. The
  full corpus is ~200 rules across three pin bumps, i.e. multi-CL
  follow-on work. Some sources are cite-link only (AWS/MS/CIS/Snyk/ISO),
  so those rules are CTP-authored against a linkable reference rather
  than mirrored.
- **Boundary.** CTP does not edit GCTP and GCTP does not edit CTP; the
  contract surface is `active.json` + `rubric/detectors/`. Each wave is
  adopted consumer-side via the harness's own pin-bump ADR.

## Provenance

- Source directive: `PROPOSAL-003-ctp-session-brief.md` (grok-claude-tdd-pro
  repo, `proposals/`), fetched and treated as authoritative per operator
  instruction.
- Source master manifest: `docs/standards-source-manifest.md` (§6 of the
  brief, 155 sources across YAML/JSON/MD corpora).
- Detailed design: `docs/design/v1.19-prose-as-code-and-corpora.md`.
- Architecture amendment: `docs/architecture-v1.9.md` §28.24 (append-only).
- Prior art for the LLM-judge tier: `rubric/detectors/llm-judge.sh` and its
  callers `no-any.sh` / `naked-throw.sh` (the `LLM_JUDGE=1` shell-out pattern
  this generalizes).

## Cross-references

- `docs/design/v1.19-prose-as-code-and-corpora.md` — full design (detector
  contracts, wave plan, license posture, §25 vocab).
- `docs/standards-source-manifest.md` — the §6 source master tables.
- `docs/architecture-v1.9.md` §28.24 — the append-only reference block.
- `docs/architecture-v1.9.md` §28.17/§28.20 — the `enforce.sh` external-tree
  contract this detector family plugs into; §28.21 — the universal-coverage
  apply-by-default pattern the prose projection extends.
- `schemas/rubric-rule.schema.json` — the `applies_to_prose` /
  `applies_to_prose_kinds` rule-shape extension.
