# 0008. Composite engine + 4-axis canonical vocabulary + architectural-content bundle

- **Status:** accepted
- **Deciders:** @drumfiend21
- **Decision_id:** ADR-0008
- **Architect_session:** GCTP COMPLETE-ARCHITECTURE-FOR-CTP handoff (pinned `grok-claude-tdd-pro@31d77487`), paired with upstream draft `proposals/ctp-adr-drafts/CTP-ADR-NNNN-composite-engine-4-axis-vocabulary.md` (reproducibility pin `9b4a366`)
- **Profile_active:** standard
- **Date:** 2026-06-20

## Context

The PROPOSAL-003 line (ADR-0007, §28.24–§28.27) gave CTP grounded,
enforceable rules across 22 namespaces, the `prose-judge.sh` semantic
moat, and write/generation-time enforcement. But the detectors are
hand-rolled grep/`include?` token matchers. That approach is brittle
(literal-substring false positives/negatives), does not scale to new
file types without a new detector each time, and has **no canonical
vocabulary** for binding a rule to the tool(s) that should enforce it —
namespaces are CTP-invented strings.

The GCTP handoff (`COMPLETE-ARCHITECTURE-FOR-CTP.md`) supplies the next
architecture as two paired, TIER-1-authority ADR drafts. This ADR
adopts the first. The operator directive driving it: *"nothing written
to disk without vetting against every applicable rule by every
applicable tool,"* and *"adopt industry-standard registries rather than
invent one."*

## Considered options

1. **Extend the hand-rolled grep/token detectors.** REJECTED — does not
   scale; brittleness is inherent; the coverage gap grows with every new
   file type, and there is still no canonical rule→tool binding vocabulary.
2. **Invent a CTP-native binding vocabulary** (`language:` / `kind:`
   fields of our own design). REJECTED — duplicates GitHub Linguist, the
   IaC-scanner consensus, PURL, and Kubernetes GVK; diverges from the
   industry; the operator explicitly forbade CTP-native invention here.
3. **Per-tool wrappers with no aggregation bus.** REJECTED — cannot
   aggregate verdicts across tools, so "every applicable tool must pass"
   is unenforceable, and there is no single normalized stream for
   dashboards / code-scanning / IDEs.
4. **Architectural-content enforcement as per-rule opt-in.** REJECTED —
   invites per-rule oversight; the operator requires the bundle to fire
   on every prose-applicable rule, as a floor.
5. **Adopt the upstream composite-engine + 4-axis design (this decision).**

## Decision

**Adopt the upstream `CTP-ADR-NNNN-composite-engine-4-axis-vocabulary`
draft as TIER-1 authority and the canonical CTP roadmap, executed in
three waves.** Four-part design:

1. **4-axis canonical vocabulary** — bind rules to tools via four
   industry authorities, replacing CTP-invented namespace strings:

   | Axis | Authority | Rule field |
   |---|---|---|
   | Languages | GitHub Linguist (~700) | `applies_to.linguist_aliases` |
   | IaC dialects | Checkov/Trivy/Kubescape consensus | `applies_to.iac_dialects` |
   | Package use | PURL (`pkg:npm/react`) | `applies_to.purl_uses` |
   | K8s objects | GVK (`apps/v1/Deployment`) | `applies_to.k8s_gvks` |

   Read-only mirrors live in `vendor/canonical-vocabulary/`, refreshed
   daily through the existing §28.22/§28.23 freshness machinery.

2. **Composite engine over a SARIF 2.1.0 bus** — replace hand-rolled
   detectors with battle-tested FOSS tools (Semgrep, ESLint, Checkov,
   Kubescape, Trivy, Spectral, hadolint, zizmor, markdownlint, Vale,
   lychee, …). Every tool emits SARIF 2.1.0; `sarif-aggregate.sh`
   normalizes verdicts; the engine walks each rule's `enforced_by[]` in
   order, first matching binding wins per file.

3. **`architectural-content` bundle (whole-or-nothing)** — when any rule
   declares `applies_to_prose: true`, the engine auto-attaches the full
   bundle (markdownlint + remark + Vale Google/Microsoft packs + textlint
   + cspell + lychee + reuse-tool + mmdc/plantuml + frontmatter schema +
   Semgrep generic + RFC 2119 check + adr-tools + commitlint +
   **`prose-judge.sh`** as the semantic moat). The operator cannot
   pick/choose within the bundle; it is the enforcement floor.

4. **Two-phase enforcement** — write-time (post-tool-use, pragmatic,
   warnings allowed) and audit-time (whole-tree, zero-violations gate
   unless explicitly deviated). A future PreToolUse "never on disk in
   violating form" hook is deferred (upstream CTP-D-7a).

### Operator-directed divergence from the draft: missing required tools HARD-FAIL

The upstream draft specifies *"graceful tool absence → rule marked
`not_enforced`, engine continues."* The operator (this session)
**overrode that to hard-require**: a tool declared **required** on a
rule's `enforced_by[]` is a **hard failure that blocks** when the binary
is absent — CTP must not claim a gate it cannot run. The existing
§28.17 `not_enforced` state is retained only for tools marked
**optional/advisory**. Because this changes the verdict semantics the
consumer reads, it MUST be reflected in the paired GCTP ADR (0068)
before the engine ships; recorded here as the binding CTP policy for the
Wave-2 runner build.

## Decision outcome

We **chose** to adopt the composite engine because the operator's
"every applicable tool on every applicable file, nothing to disk
unvetted" directive is not achievable with single-token grep — it
requires real tools (Semgrep/Checkov/…) and a normalized aggregation
bus, and it requires a canonical rule→tool vocabulary that the industry
already standardized (Linguist/IaC-consensus/PURL/GVK) rather than one
we invent. We **decided** to land this as an accepted roadmap ADR plus
the unblocking P-8 fix now, and stage the build across three waves
(vocabulary+schema+bus → per-tool runners+dispatch → bundle+two-phase
wiring), because the surface is large (~115 external tools) and each
wave is independently useful. The `not_enforced`→hard-fail divergence
was decided by the operator and is recorded as binding, pending the
paired GCTP ADR.

## Consequences

- **Positive.** FOSS tools catch what grep misses with far fewer
  edge-case false positives; `.yaml` workflows, SBOMs, container images,
  helm charts become enforceable; SARIF is one bus for dashboards /
  code-scanning / IDEs; the 4-axis vocabulary eliminates rule-binding
  ambiguity and CTP-native drift.
- **Cost / negative.** Hard external-tool dependency (mitigated by a
  containerized toolchain path); the existing 118 rules need mechanical
  migration to `applies_to.*` (gated by a parity-diff regression test);
  prose-tool DSLs (Vale/markdownlint/remark) drift over time (managed by
  version pinning). The hard-require policy means an under-provisioned
  environment fails closed — intentional, but it raises the bar on the
  consumer's toolchain.
- **Prerequisite (now satisfied).** The P-8 `prose-judge.sh`↔`llm-judge.sh`
  `--text`/`--target` contract mismatch is fixed in this CL, so the
  semantic moat returns real verdicts under `LLM_JUDGE=1` instead of a
  spurious `not_enforced`.
- **Boundary.** CTP does not edit GCTP. `prose-judge.sh`'s interface is
  unchanged. The P-8 fix touches only `llm-judge.sh` (additive `--text`).

## Provenance

- Upstream brief: `grok-claude-tdd-pro@31d77487:proposals/ctp-adr-drafts/COMPLETE-ARCHITECTURE-FOR-CTP.md`
- Upstream draft: `…/CTP-ADR-NNNN-composite-engine-4-axis-vocabulary.md` (pin `9b4a366`)
- Paired GCTP-side ADR: `grok-claude-tdd-pro:docs/adr/0068-gctp-side-composite-engine-wiring.md`
- P-8 blocker: `grok-claude-tdd-pro:docs/upstream-ctp-proposals.md`
- Builds on: ADR-0007 (`prose-judge.sh`, `applies_to_prose`, 22 namespaces, SARIF).

## Cross-references

- `docs/adr/0009-auto-classification-and-rule-drafting-pipeline.md` — the paired ADR (rule supply).
- `docs/architecture-v1.9.md` §28.28 — the append-only amendment registering this roadmap + the P-8 fix.
- `rubric/detectors/llm-judge.sh` — the P-8 `--text` fix landed in this CL.
- `rubric/enforce.sh` / `rubric/enforce-file.sh` — the §28.17/§28.27 contracts the composite engine will generalize.
