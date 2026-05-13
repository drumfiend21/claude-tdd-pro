# Claude TDD Pro v1.9 — Complete Cumulative Architectural Design

The complete reference. Every component from v0.3 substrate through v1.9 additions, organized by layer with cross-cutting contracts, complete inventory, execution order, and definition of done. Nothing dropped.
Capability ranking: 9.85/10. Build confidence: 9/10 via canonical staged path.

## §1. System architecture — thirteen-layer model

Eleven stacked layers plus two cross-cutting layers (Operational Readiness, Execution Surfaces).

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                       CLAUDE TDD PRO v1.9                                    │
│                                                                              │
│  ┌─── HARDENING (H) ────────────────────────────────────────────────────┐   │
│  │ profile system · token-cost · sectioned advisory locks · SECURITY    │   │
│  │ multi-language honesty · /doctor --watch · license attribution       │   │
│  │ progressive-disclosure docs · community catalog · plugin self-test   │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│  ┌─── WORKFLOW ORCHESTRATION (W) ──────────────────────────────────────┐    │
│  │ /architect (S+L+C-grounded) · git-workflow guidance                  │    │
│  │ workflow state machine · decision provenance trail · ADR chaining    │    │
│  └──────────────────────────────────────────────────────────────────────┘   │
│  ┌─── SPACE OBSERVATION (Q) ───────────────────────────────────────────┐    │
│  │ Performance · Flow + opt-in dimensions · friction tracker            │    │
│  │ flow guard · privacy-by-default · risk-tiered profile auto-select    │    │
│  └──────────────────────────────────────────────────────────────────────┘   │
│  ┌─── COVERAGE (R, N, T) ──────────────────────────────────────────────┐    │
│  │ React/Node/Types specialists · 28 rules in source folders           │    │
│  │ 12 detectors · canary rollout (warn-only → block after 14d)          │    │
│  └──────────────────────────────────────────────────────────────────────┘   │
│  ┌─── PROMPT LIFECYCLE (P) ────────────────────────────────────────────┐    │
│  │ versioned prompt registry · per-agent eval datasets · /prompt-eval   │    │
│  │ /prompt-ab · /prompt-promote · model-rationale · fine-tunes          │    │
│  └──────────────────────────────────────────────────────────────────────┘   │
│  ┌─── parallel authoritative-source ingestion — ALL OPERATOR-CURATED ──┐   │
│  │  STANDARDS (S)         │ COMPLIANCE (C)       │ PR CORPUS (L)       │   │
│  │  STANDARDS-URLS.yaml   │ COMPLIANCE-URLS.yaml │ PR-SOURCES.yaml     │   │
│  │  /standards-add /-remove│ /compliance-add /-rm │ /pr-source-add /-rm│   │
│  │  daily-fresh · gate    │ daily-fresh · gate   │ daily-fresh · gate  │   │
│  │  17 default sources    │ 25+ default frameworks│ 10 default sources │   │
│  │  Each maps → G-folder  │ Each maps → G-folder │ Each maps → G-folder│   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│  ┌─── FOUNDATION (F) ──────────────────────────────────────────────────┐    │
│  │ /postmortem · /measure-rubric · /agent-verify · /incident · drift    │    │
│  │ FAILURE-LOG · critical-paths.txt · codebase-impact preview helper    │    │
│  └──────────────────────────────────────────────────────────────────────┘   │
│  ┌─── RULE ENGINE (E — ESLint-parity) ─────────────────────────────────┐    │
│  │ severity overrides · rule options + JSON schema · glob overrides     │    │
│  │ auto-fix · inline suppression · recommended sets · plugin protocol   │    │
│  │ standardized metadata · formatters (md/json/sarif/checkstyle/junit/  │    │
│  │ gh-actions) · deprecation lifecycle · RuleTester · per-rule cache    │    │
│  │ messageIds (i18n) · ESLint config import · ESLint-as-detector wrap   │    │
│  └──────────────────────────────────────────────────────────────────────┘   │
│  ┌─── GENERATED QUALITY-STANDARDS DIRECTORY (G) ──────────────────────┐    │
│  │ generated-code-quality-standards/<source-namespace>/<file>.yaml      │    │
│  │ source-organized · ESLint-style rule config per file                 │    │
│  │ _operator/ namespace · _community/ plugins · _meta/ index            │    │
│  │ auto-aggregator · auto-scaffold from registries · 14 namespaces      │    │
│  └──────────────────────────────────────────────────────────────────────┘   │
│  ┌─── EXISTING SUBSTRATE (v0.3) ───────────────────────────────────────┐    │
│  │ runner.sh (now reads G-1) · 6 detectors · 17 commands · 11 subagents │    │
│  │ 14 skills · 12 evals · 9 templates · 3 styles · MCP (git, github)    │    │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ╔═══════════════ CROSS-CUTTING (touch all layers) ═══════════════════╗    │
│  ║ OPERATIONAL READINESS (O)                                          ║    │
│  ║ telemetry-first · seed corpus · global --dry-run · lifecycle       ║    │
│  ║ multi-machine sync · audit-log signed checkpoints · meta-eval      ║    │
│  ║ canary rollout · threat model · shared-learning · rubric semver    ║    │
│  ║                                                                     ║    │
│  ║ EXECUTION SURFACES (X)                                             ║    │
│  ║ GitHub Actions · GitLab CI · pre-commit · local-LLM · TUI          ║    │
│  ╚═════════════════════════════════════════════════════════════════════╝    │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Architectural through-line:** every authoritative input — engineering standards, regulatory frameworks, observed peer review — is operator-curated via three top-level YAML registries at `.claude-tdd-pro/`, daily-fresh-fetched from live published sources, freshness-gated on rule activation, and traceable per-commit. Rules live in a single source-organized directory at plugin root grouped by upstream publisher (Google, US Government, EU, Finance Industry, OWASP, W3C, Web Vitals, React, Node, TypeScript, SLSA, Linux Foundation, Industry Self-Regulatory) with each file using full ESLint-style configuration. Every empirical unknown is converted into a measurable engineering discipline (telemetry-first, hand-graded eval, two-pass reconciler, golden-output diff, canary rollout, conditional GETs note for v1.8 backlog). Every closed loop has bootstrap state instead of cold-start. Every destructive operation is rehearsable via dry-run and recoverable via signed checkpoints. Every enforcement runs in three execution surfaces (Claude Code, pre-commit, CI) with the same exit-code contract. Every architectural decision is elicited interactively with grounded options, recorded as ADR provenance, and traced through full delivery from feature description to merged PR.

## §2. Cross-cutting contracts

### §2.1 Rubric rule schema

```yaml
- id: g-ts-001
  name: no-any
  description: "..."
  detector: rubric/detectors/no-any.sh
  remediation: "..."
  source_file: generated-code-quality-standards/google/tsguide.yaml   # G phase
  source_namespace: google
  type: problem | suggestion | layout
  fixable: code | whitespace | null
  has_suggestions: false
  deprecated: false
  replaced_by: []
  docs_url: <upstream-url>
  requires_type_checking: false
  recommended: true
  options_schema: { ... JSON Schema ... }
  messages: { messageId: template }
  severity: P0 | P1 | P2
  version: 1.0.0
  semver: 1.0.0
  cost_estimate: { tokens_per_check, runs_on }
  false_positive_log: rubric/fp-log/<id>.jsonl
  provenance: [ { source, class, section_id, url, fetched_at, content_hash, live_url_origin } ]
  controls: [ { framework, control_id, article, risk_tier } ]
  rule_state: warn-only | block | disabled
  rule_state_history: [...]
  legal_review_status: { framework: pending | reviewed_by:<r>:<d> | not-applicable }
```

### §2.2 Detector contract

Flags: `--json`, `--paths <glob>`, `--dry-run`, `--rule-state-override`, `--options <json>`, `--fix`, `--fix-dry-run`, `--format <fmt>`, `--cache-key`. Exit codes 0/1/2/3. `set -euo pipefail`. Project-local binaries first. ≤5s on 1k-file changeset. Output JSON includes `detector_version_hash`, `messageId`, `data`.

### §2.3 Subagent contract

Frontmatter: `name`, `model`, `prompt_id`, `prompt_version`, `model_rationale`, `eval_dataset`, `prompt_migration_status` (original | migrated-zero-delta | migrated-with-delta:`<reason>`). Findings format: `{severity, rule_id?, file, line, finding, suggested_fix}`.

### §2.4 Eval spec schema

```json
{
  "name", "category", "subject", "input", "expected", "rationale",
  "subject_target_hash", "stale_when_target_changes", "bootstrap_seed"
}
```

Categories: `react|node|types|foundation|standards|compliance|prompt|space|hardening|security|tdd|operational|execution|pr-corpus|workflow|rule-engine|source-folder`.

### §2.5 Profile system

```yaml
extends:
  - rubric:recommended            # cross-cutting recommended subset
  - <source-namespace>:<file>     # granular per-file (e.g., google:tsguide)
  - <source-namespace>:<file>:all # all set from that file
  - <source-namespace>:*          # recommended set from every file in folder
  - <source-namespace>:*:all      # all set from every file in folder
  - <profile-name>                # another profile

include:
  skills: [...], agents: [...], detectors: [...], rubric_rules: [...],
  standards_sources: [...], compliance_frameworks: [...], pr_corpus_sources: [...],
  operator_namespaces: [...],
  require:
    aibom: true
    sod_gate_on_critical_paths: true
    audit_log_signing: true
    pii_egress_block: true

exclude_sources:
  - <source-namespace>:<file>     # remove specific file
  - <source-namespace>:*          # remove entire folder

rules:                            # ESLint-pattern severity + options
  g-ts-001: error
  g-ts-002: ["error", { allow_with_comment: false }]
  g-react-008: ["warn", { budget_kb: 250 }]

overrides:                        # ESLint-pattern glob overrides
  - files: ["**/*.test.ts"]
    rules: { g-ts-001: off }
  - files: ["src/payments/**"]
    rules: { g-ts-001: error, g-node-001: ["error", { strict_schema: true }] }

override:                         # explicit auditable field-level
  - target: "rubric_rule:g-ts-001"
    field: severity
    from: P1
    to: P0
    rationale: "Banking division requires zero-tolerance per OCC heightened standards §III.A.2"

resolution_order:
  - explicit_override
  - extends_rightmost
  - severity_max
  - source_authority_max
```

9 profiles + per-industry templates: `lite`, `standard`, `strict`, `react`, `node`, `library`, `regulated`, `financial`, `government`, plus `eu-financial`, `healthcare`, `eu-saas`.

### §2.6 Standards source contract (two-tier)

Operator-facing (top-level `.claude-tdd-pro/STANDARDS-URLS.yaml`):

```yaml
- id: google-tsguide
  name: "Google TypeScript Style Guide"
  url: https://google.github.io/styleguide/tsguide.html
  tier: 1
  applies_to: [typescript, react]
  fetch_frequency: daily
```

Plugin-internal (extended `standards/sources.yaml`): adds `class: published-standard`, `authority_tier`, `fragility_tier: high|medium|low`, `fragility_strategy: silent-replace|prompt-on-change|manual-only`, `fetcher`, `identifier_pattern`, `license_note`, `origin`, `added_by`, `added_at`.

### §2.7 Lock file (sectioned advisory locks)

```json
{
  "plugin_version": "1.9.0",
  "rubric_semver": "1.0.0",
  "_meta": { "schema_version": "1.9", "sections": ["rubric", "detectors", "standards", "compliance", "prompts", "models", "pr_corpus", "profile", "verify", "workflow_state", "standards_freshness", "pr_corpus_freshness", "compliance_freshness", "rule_cache", "quality_standards_directory"] },
  "_locks": { "<section>": { "holder": "<process>", "expires": "<timestamp>" } },
  "rubric": {}, "detectors": {},
  "standards_versions": {}, "compliance_versions": {}, "pr_corpus_patterns": {},
  "prompt_registry_hash": "...", "model_pins": {},
  "profile_snapshot_hash": "...", "workflow_state_hash": "...",
  "quality_standards_directory_hash": "..."
}
```

Per-section flock-style; `expires` guards crashed holders. Merge: standards/pr_corpus by union; rubric/prompts/workflow_state last-writer with conflict surfaced.

### §2.8 AI Provenance Manifest

Per-commit `.claude-tdd-pro/provenance/<commit-sha>.json`:

```json
{
  "commit": "...", "timestamp": "...", "author_human": "...",
  "ai_involvement": { "tier": "...", "models_used": [], "agents_invoked": [], "skills_invoked": [], "prompts": [] },
  "rubric_state": { "rubric_hash": "...", "rules_evaluated": [], "rules_passed": [], "rules_blocked": [] },
  "standards_state": { "<source>": { "content_hash": "...", "fetched_at": "...", "freshness_at_generation": "..." } },
  "pr_corpus_state": { "<source>": { "patterns_consulted": [], "last_fetch": "...", "freshness_at_generation": "...", "evidence_count_used": 0 } },
  "compliance_state": { "<framework>": { "controls_consulted": [], "fetched_at": "...", "edition": "...", "freshness_at_generation": "...", "legal_review_status_for_consulted": [] } },
  "human_review": { "reviewer": "...", "review_kind": "...", "verifier_consulted": false },
  "cost_telemetry": { "tokens_in": 0, "tokens_out": 0, "model": "...", "duration_ms": 0, "monetary_estimate_usd": 0 },
  "decision_provenance": { "adrs": [], "architect_session_id": "...", "decisions_referenced": [] },
  "signature": "sha256:..."
}
```

`freshness_at_generation`: `fresh-within-fetch-frequency` | `stale-warn-degraded` | `offline-cached` | `operator-bypass`.

### §2.9 Control mapping

```yaml
- framework: soc2-tsc
  control_id: CC8.1
  satisfied_by: [ rubric_rule | hook | artifact ]
  legal_review_status: reviewed_by:<r>:<d> | pending | not-applicable
```

`/audit-pack` warns on `pending`.

### §2.10 Prompt registry

```yaml
- id: rsc-reviewer
  versions:
    - version: 2.1.0
      file: prompts/rsc-reviewer/v2.1.0.md
      hash: "..."
      created: "..."
      eval_pass_rate: "..."
      regression_from_prior: "..."
      status: active | archived | candidate
      migration: { from_inline_agent: true, golden_output_diff: "...", delta_status: zero-delta | justified-delta:<reason>, validated_inputs: [] }
```

### §2.11 SPACE metric schema

```yaml
- id: space-perf-rubric-pass-rate
  dimension: satisfaction | performance | activity | collaboration | efficiency-and-flow
  source: "..."
  unit: "..."
  reporting_window: "..."
  privacy: local-only
  opt_in: true
```

### §2.12 PR source contract (two-tier)

Operator-facing (`.claude-tdd-pro/PR-SOURCES.yaml`): `id`, `name`, `github`, `tier (1|2)`, `source_class`, `applies_to`, `fetch_frequency`, optional notes.
Plugin-internal: adds `authority_tier`, `fragility_tier`, `local_llm_eligible`, `filters`, `budget`, `attribution`, `origin`, `added_by`, `added_at`.
`source_class` enum: `federal-financial-regulator | fedramp-high | federal-digital-services | federal-infrastructure | financial-industry | financial-industry-consortium | gold-standard-process`.

### §2.13 Active-flow stack

`.claude-tdd-pro/active-flow.stack` (NDJSON). Push/pop wrappers. PID liveness checked.

### §2.14 Dry-run contract

Subject commands (every `destructive: true`): `/remediate`, `/promote-standard`, `/pr-corpus-learn`, `/risk-classify`, `/audit-pack`, `/prompt-promote`, `/space-export`, `/uninstall-cleanup`, `/migrate`, `/architect`, `/standards-add`, `/standards-remove`, `/pr-source-add`, `/pr-source-remove`, `/compliance-add`, `/compliance-remove`, `/fix-rules`, `/plugin-install`, `/plugin-update`, `/plugin-remove`, `/import-eslint-config`, `/operator-namespace-init`, `/operator-extension-init`.

### §2.15 Workflow state contract

`.claude-tdd-pro/workflow-state.json`: `session_id`, `current_phase`, `feature_description`, `architect_session: { decisions: [{id, decision_point, options_presented, selected, rationale, adr_path}] }`, `spec_path`, `plan_approved_at`, `commits`, `branch_recommendations`, `standards_consulted`, `pr_corpus_consulted`, `compliance_consulted`, `_resumable`.

### §2.16 Decision provenance schema (MADR ADRs auto-generated by W-1)

`docs/adr/<date>-<slug>.md` with status, deciders, architect_session, decision_id, profile_active, context, considered options (verbatim from W-1.5), decision outcome with rationale, full provenance trail.

### §2.17 Live freshness contract

Every standards/pr-corpus/compliance-citing operation validates freshness before proceeding. Bypass: `--skip-fresh` flag; logged to C-4 audit log.

### §2.18 Generation-time consumption schema

C-3 manifest carries `standards_state`, `pr_corpus_state`, `compliance_state` blocks per §2.8.

### §2.19 Compliance source contract (two-tier)

Operator-facing (`.claude-tdd-pro/COMPLIANCE-URLS.yaml`): `id`, `name`, `url`, `authoritative_publisher`, `jurisdiction`, `applicable_to`, `identifier_scheme`, `why_authoritative` (multi-line, ≥3 lines REQUIRED), `fetch_frequency`, `legal_review_required`, `paywalled`, `document_url`, `attribution_note`.
Plugin-internal: adds `fetcher`, `identifier_pattern`, `edition`, `edition_date`, `authority_tier`, `fragility_tier`, `origin`, `added_by`, `added_at`, `license_handling`.

### §2.20 Rule plugin contract (per E-7)

Plugin repo structure: `plugin.yaml`, `generated-code-quality-standards/<plugin-namespace>/`, `detectors/`, `tests/`, `messages/`, `docs/`, `LICENSE`. `plugin.yaml` declares: `id`, `name`, `version`, `publisher`, optional `publisher_signing_key`, `homepage`, `applies_to`, `recommended_rules`, `all_rules`, `authority_tier (default 2)`, `license`, `provenance_class: community-plugin`. Installed at `.claude-tdd-pro/plugins/<plugin-id>/`.

### §2.21 Source folder contract (G phase)

Every folder under `generated-code-quality-standards/` (excluding `_operator/`, `_community/`, `_meta/`) MUST: map to one entry in S/C/L registry, contain ≥1 `<file>.yaml`, each file has `source:` header (id, authoritative_publisher, authoritative_url, registry_link, fetched_at, content_hash), each rule validates against §2.1 with full E-8 metadata. File naming: lowercase kebab-case.

### §2.22 Source folder operator contract

`generated-code-quality-standards/_operator/<my-org>/` operator-namespace; never overwritten by plugin upgrade. Operator extensions in `_operator/<source-namespace>/<file>-extensions.yaml` override plugin defaults via cascade.

## §3. Phase F — Foundation

- **F-0** Lock contracts (rubric schema, detector contract, eval spec schema, profile precedence).
- **F-1** `/postmortem <bug-description>`: skill reproduces as failing test → asks what should have caught it → generates eval spec → optionally drafts rule + detector → queries SIRL/Compliance/L for matches → appends to `FAILURE-LOG.md`.
- **F-2** `/measure-rubric` with built-in token telemetry (F-2.6); per-rule precision/recall/cost via FP triage; cross-references provenance currency, control coverage, prompt eval, PR-corpus evidence.
- **F-3** `/agent-verify <path>` + `agents/critical-path-verifier.md` (opus); `.claude-tdd-pro/critical-paths.txt`.
- **F-4** Drift-detection skill: post-commit scan for `// rubric: ignore`, `--no-verify`, repeated bypass; tracks E-5 inline suppressions.
- **F-5** `/incident <description>`: for sideways sessions; drives `RUBRIC.yaml`/`CLAUDE.md` additions.
- **F-6** Codebase-impact preview helper: `rubric/impact-preview.sh` used by S-7, L-8, W-1.

## §4. Phase S — Standards Ingestion & Reconciliation

- **S-1** Standards catalog (17 default sources): `google-tsguide/jsguide/pyguide/eng-practices/testing-blog`, `react-docs`, `react-rsc-rfc`, `nextjs-docs`, `typescript-handbook`, `node-docs`, `node-best-practices`, `owasp-asvs`, `owasp-top10`, `wcag-2-2`, `web-vitals`, `slsa`, `semver`.
- **S-2** Standards fetcher with per-tier fragility behavior (high → silent replace, medium → prompt on >5% structure delta, low → manual fetch only); per-source fetchers in `standards/fetchers/`: `html-anchor.sh`, `markdown-headers.sh`, `pdf-section.sh`, `rfc-style.sh`.
- **S-3** Coverage matrix → `standards/coverage-matrix.json` + `COVERAGE.md`.
- **S-4** `/standards-audit` + gap analyzer.
- **S-5** `/standards-diff` (Adopt/Defer/Reject decisions in `standards/decisions.jsonl`).
- **S-6** Provenance enforcement detector: `rubric/detectors/rubric-provenance.sh` (every rule has ≥1 entry; tier matches severity; ≤90 days fresh).
- **S-7** `/promote-standard <source> <section_id>` with codebase-impact preview (F-6).
- **S-8** Standards-comparator subagent (sonnet, prompt_id `standards-comparator`); grounded answers; declines hallucination.
- **S-9** `STANDARDS-CONFORMANCE.md` report alongside `COMPLIANCE-REPORT.md`.
- **S-10** `/standards-monitor --watch` long-lived background fetch + diff + gap-analysis loop.
- **S-11** Closed loop.
- **S-12** `STANDARDS-URLS.yaml` operator-editable registry at `.claude-tdd-pro/`.
- **S-13** Daily-fresh fetch guarantee (per-operation gate + first-use-of-day).
- **S-14** `/standards-add <url>`.
- **S-15** `/standards-remove <id>`.
- **S-16** Live freshness gate on rule activation (auto-demote/restore).
- **S-17** First-use-of-day auto-refresh `standards/auto-refresh-daily.sh`.
- **S-18** Generation-time consumption trace.
- **S-19** Closed-loop validation.

Each `STANDARDS-URLS.yaml` entry maps to a folder under `generated-code-quality-standards/<source-namespace>/` (G-9 sync).

## §5. Phase C — Compliance, Audit & Provenance

- **C-1** Compliance frameworks catalog (10+ default frameworks):

| id | jurisdiction | identifier scheme |
|---|---|---|
| nist-ai-rmf | US Federal | GOVERN/MAP/MEASURE/MANAGE |
| nist-800-218 (SSDF) | US Federal | PO/PS/PW/RV |
| nist-800-218a (SSDF for AI) | US Federal | PO/PS/PW/RV with AI augmentations |
| nist-csf-2 | US Federal | GV/ID/PR/DE/RS/RC |
| nist-800-53-r5 | US Federal | Family-Number (AC-, AU-, SI-) |
| nist-800-171-r3 | US Federal | Family-Number |
| fedramp-mod / fedramp-high | US Federal | NIST 800-53 subset/extended |
| ffiec-its / ffiec-cat | US Federal Banking | Booklet-section |
| occ-heightened-standards | US Federal Banking | 12 CFR 30 App D |
| sec-cyber-disclosure | US Federal Public Co | 17 CFR §229.106 |
| sox-itcc | US Federal Public Co | PCAOB AS 2201 |
| hipaa-security-rule | US Federal Healthcare | 45 CFR §164.3xx |
| eu-ai-act | EU | Article + Annex |
| eu-ai-act-edpb-guidance | EU | EDPB Guidelines |
| gdpr | EU | Article |
| dora | EU Financial | Article |
| pci-dss-v4 | Industry-self-reg | Req major.minor |
| slsa | Industry-self-reg | Levels 1-4 |
| owasp-asvs | Industry-self-reg | V`<chapter>`.`<section>` |
| iso-27001-a14 | ISO (paywalled) | Annex A.`<n>`.`<n>`.`<n>` |
| iso-27017 | ISO (paywalled) | Aligned with ISO 27002 |
| soc2-tsc | AICPA (paywalled) | CC`<n>`.`<n>`, A, PI, C, P |

- **C-2** Control mapping → `compliance/controls.yaml` with `legal_review_status`; `/legal-review-mark` skill.
- **C-3** AI Provenance Manifest emitter; signed with project-local key; `cost_telemetry`; `decision_provenance` block; git notes integration.
- **C-4** Immutable Merkle-chained audit log + signed checkpoints every 100 entries (`compliance/audit-checkpoints/`); `compliance/audit-recover.sh`.
- **C-5** SoD gate with verifier output schema at `.claude-tdd-pro/verify/<pr-sha>.json` (`verdict: concur|diverge|abstain`); `hooks/scripts/sod-gate.sh`.
- **C-6** PII/secrets egress guard `hooks/scripts/pii-egress-guard.sh`: SSN, IBAN/BIC, credit-card (Luhn), passport, EU national IDs, US driver's license, API keys.
- **C-7** AIBOM `compliance/aibom.sh` emits `compliance/AIBOM-<tag>.json` in CycloneDX 1.6 + AI/ML extension.
- **C-8** `/risk-classify` walks EU AI Act use-case category → `compliance/risk-classification.yaml` → surfaces obligations.
- **C-9** SOC 2 evidence collection → `compliance/evidence/` per-control dirs; date-ranged bundle.
- **C-10** `/audit-pack` bundles AIBOM + control coverage + evidence + risk classification + audit log + provenance manifests + Decision Trail + Standards Freshness + PR Corpus Freshness + Compliance Freshness sections + "all-three-fresh" badge per commit.
- **C-11** Compliance-specialist subagent `agents/review-compliance.md` (sonnet, prompt_id `compliance-reviewer`).
- **C-12** Closed loop.
- **C-13** `COMPLIANCE-URLS.yaml` operator-editable registry with verbose `why_authoritative` comments per entry.
- **C-14** Sync mechanism.
- **C-15** Daily-fresh compliance fetch guarantee with paywalled-source HEAD-only handling and `/compliance-attest` for paywalled.
- **C-16** `/compliance-add <url>` with `$EDITOR` prompt for `why_authoritative`.
- **C-17** `/compliance-remove <id>`.
- **C-18** Live freshness gate on control mapping activation.
- **C-19** First-use-of-day auto-refresh `compliance/auto-refresh-daily.sh`.
- **C-20** Generation-time compliance consumption trace.
- **C-21** Closed-loop validation.

Each `COMPLIANCE-URLS.yaml` entry maps to a folder under `generated-code-quality-standards/<jurisdiction-namespace>/` (G-9.1 sync: US Federal → `us-government/`, EU → `european-union/`).

## §6. Phase P — Prompt Engineering & AI Component Lifecycle

- **P-1** Versioned prompt registry `prompts/registry.yaml` + per-prompt `prompts/<id>/v<semver>.md`; golden-output migration diff (zero-delta or justified-delta with operator accept).
- **P-2** Eval datasets per agent/skill `evals/datasets/agents/<agent-name>.jsonl`, `evals/datasets/skills/<skill-name>.jsonl`; bootstrapped from O-1 seed (~30 hand-graded inputs each).
- **P-3** `/prompt-eval <agent>` runs eval dataset; output `prompts/eval-history/<id>/<version>.json`.
- **P-4** Model selection rationale enforced by `rubric/detectors/model-rationale.sh`.
- **P-5** `/prompt-ab <id> <ver-A> <ver-B>` with statistical-honesty guard (n<30 → "qualitative comparison only").
- **P-6** `/prompt-promote <id> <version>` regression-gated; `/prompt-rollback <id>` one-command.
- **P-7** Fine-tuning artifact registry `prompts/fine-tunes.yaml`; AIBOM ingests.
- **P-8** Skill performance metrics `skills/perf.sh` → `skills/PERF.md`.
- **P-9** Closed loop.

## §7. Phase R — React specialist coverage

- **R-1** Subagents: `agents/review-react-rsc.md` (sonnet, prompt_id `rsc-reviewer`), `agents/review-react-a11y.md` (sonnet, prompt_id `a11y-reviewer`).
- **R-2** 10 rules with full E-8 metadata, provenance, controls, canary rollout (warn-only → block after 14d clean):

| ID | Source file | Provenance | Controls |
|---|---|---|---|
| g-react-001 RSC boundary integrity | `react/rsc-rfc.yaml` | react-rsc-rfc §3, nextjs-docs/server-components | owasp-asvs §V14.3 |
| g-react-002 Exhaustive-deps | `react/react-docs.yaml` | react-docs/synchronizing-with-effects | — |
| g-react-003 A11y P1 violations | `w3c/wcag-2-2.yaml` | wcag-2-2 §1.3.1, §2.4.7, §4.1.2 | eu-ai-act art.16 |
| g-react-004 No useEffect for derived state | `react/react-docs.yaml` | react-docs/you-might-not-need-an-effect | — |
| g-react-005 Suspense around async | `react/react-docs.yaml` | react-docs/Suspense | — |
| g-react-006 Error boundaries on routes | `react/react-docs.yaml` | react-docs/Component#errors | soc2-tsc CC7.3 |
| g-react-007 Component test required | `google/testing-blog.yaml` | google-testing-blog, google-tsguide §testing | soc2-tsc CC8.1 |
| g-react-008 Bundle-size budget per route | `web-vitals/core-web-vitals.yaml` | web-vitals (LCP/INP) | — |
| g-react-009 No client fetch where server eq exists | `react/nextjs-docs.yaml` | nextjs-docs/data-fetching | — |
| g-react-010 Image/font optimization | `web-vitals/core-web-vitals.yaml` | web-vitals, nextjs-docs/optimizing | — |

Options: `g-react-007 { test_runner, allow_snapshot_only }`; `g-react-008 { budget_kb, per_route, excluded_routes }`. `g-react-002` and `g-react-003` use E-15 ESLint-wrap.

- **R-3** Detectors: `a11y-axe.sh`, `bundle-budget.sh`, `rsc-boundary.sh`, `exhaustive-deps.sh`.
- **R-4** Templates: `vitest.react.config.ts`, `playwright.config.ts`, `size-limit.config.js`.
- **R-5** Skill: `skills/react-component-build/SKILL.md`.
- **R-6** Eval specs + fixtures `evals/fixtures/react/`.
- **R-7** Profile registration in `react.yaml`, `strict.yaml`; inherited by `regulated.yaml`.

## §8. Phase N — Node specialist coverage

- **N-1** Subagents: `review-node-boundaries.md`, `review-node-observability.md`.
- **N-2** 10 rules with full E-8 metadata + canary:

| ID | Source file | Provenance | Controls |
|---|---|---|---|
| g-node-001 Schema validation at boundary | `owasp/asvs.yaml` | owasp-asvs §V5.1 | soc2-tsc PI1.1, pci-dss-v4 §6.2 |
| g-node-002 Typed error taxonomy | `node/node-best-practices.yaml` | node-docs/errors, nodebestpractices §2.4 | — |
| g-node-003 Fetch timeout + retry | `node/node-docs.yaml` | node-docs/fetch, google-eng-practices | soc2-tsc A1.2 |
| g-node-004 Structured logging | `node/node-best-practices.yaml` | nodebestpractices §5.1, owasp-asvs §V7 | soc2-tsc CC7.2, pci-dss-v4 §10 |
| g-node-005 using for disposables | `node/node-docs.yaml` | node-docs, typescript-handbook 5.2 | — |
| g-node-006 Stream backpressure | `node/node-docs.yaml` | node-docs/stream | — |
| g-node-007 DB transaction boundaries | `google/eng-practices.yaml` | google-eng-practices | soc2-tsc PI1.2 |
| g-node-008 Secrets via env | `owasp/asvs.yaml` | owasp-asvs §V2.10 | soc2-tsc CC6.1, pci-dss-v4 §3.5 |
| g-node-009 No process.exit outside main | `node/node-docs.yaml` | node-docs/process | — |
| g-node-010 Supply-chain check | `slsa/slsa-v1.yaml` | slsa §build, owasp-asvs §V14.2 | nist-800-218 PS.3.1, soc2-tsc CC8.1 |

Options: `g-node-001 { schema_libs }`; `g-node-003 { default_timeout_ms, allow_no_timeout_for }`; `g-node-004 { allowed_loggers, cli_paths }`. `g-node-002` has suggestion-level fix.

- **N-3** Detectors: `boundary-schema.sh`, `console-in-src.sh`, `fetch-timeout.sh`, `naked-throw.sh`, `supply-chain.sh`.
- **N-4** Eval specs + fixtures `evals/fixtures/node/`.
- **N-5** Profile registration.

## §9. Phase T — Type-level rigor

- **T-1** Subagent: `review-types.md` (sonnet, prompt_id `types-reviewer`).
- **T-2** 8 rules with full E-8 metadata + canary:

| ID | Source file | Provenance |
|---|---|---|
| g-ts-001 any requires `// allow-any:` | `google/tsguide.yaml` | google-tsguide §5.2 |
| g-ts-002 as requires `// allow-cast:` | `google/tsguide.yaml` | google-tsguide §5.5 |
| g-ts-003 Discriminated unions exit through assertNever | `typescript/handbook.yaml` | typescript-handbook 2/narrowing#exhaustiveness |
| g-ts-004 Public API types have type tests | `google/testing-blog.yaml` | google-tsguide §testing |
| g-ts-005 Library boundaries use branded types | `typescript/handbook.yaml` | typescript-handbook handbook-v2/intersection-types |
| g-ts-006 Strict tsconfig flags | `typescript/handbook.yaml` | typescript-handbook/tsconfig |
| g-ts-007 No Function, no object | `google/tsguide.yaml` | google-tsguide §5.3 |
| g-ts-008 Re-exports use export type | `typescript/handbook.yaml` | typescript-handbook 3-8 type-only |

Options: `g-ts-001 { allow_with_comment_pattern, max_per_file }`; `g-ts-002 { allow_with_comment_pattern, allowed_for }`. `g-ts-007` has suggestion-level fix; uses E-15 ESLint-wrap (`@typescript-eslint/no-empty-object-type`).

- **T-3** Detectors: `no-any.sh`, `exhaustive-unions.sh`, `type-test-coverage.sh`.
- **T-4** Template: `tsconfig.strict.json` (`noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `isolatedModules`, `noPropertyAccessFromIndexSignature`, `verbatimModuleSyntax`).
- **T-5** Eval specs.
- **T-6** Profile registration.

## §10. Phase Q — SPACE Productivity Measurement

- **Q-1** SPACE config `space/config.yaml` (opt-in per dimension; defaults: satisfaction opt-in, performance ON, activity opt-in, collaboration opt-in, efficiency_and_flow ON; retention 90-days; share never).
- **Q-2** Collector `space/collector.sh` aggregates from F-2 (rubric pass rate, defect escape), git (activity opt-in), F-4/E-5 (suppression), PostToolUse logs (feedback loop time), W-3 transitions, in-terminal micro-survey (satisfaction opt-in); E-12 cache hit rate as Efficiency signal.
- **Q-3** `/space-report` text dashboard with metric IDs linking to `space/metrics.yaml`; counter-Goodhart guards.
- **Q-4** Friction tracker `hooks/scripts/friction-tracker.sh`: hook block events, hook latency, skill auto-trigger FPs, E-5 inline suppressions per rule.
- **Q-5** Flow guard `skills/flow-guard/SKILL.md` PreToolUse soft warning on context thrash.
- **Q-6** Privacy posture: gitignored, redacted `/space-export`.
- **Q-7** Cross-loop integration: Performance from F-2; friction → F-2 action cards; Efficiency consumes P-8 + E-12.
- **Q-8** Honest scope (solo-scale = self-observation, not productivity science).
- **Q-9** Risk-tiered profile auto-select `skills/profile-suggest/SKILL.md` first-session scan: stack signals, compliance signals, financial-vocab, government signals.

## §11. Phase H — Hardening, sustainability, honesty

- **H-1** Token-cost transparency: `/doctor` reports per-skill, per-subagent context cost via Anthropic SDK `count_tokens`; per-profile median tokens-per-turn; per-rule cache hit rate (E-12); daily auto-refresh cost (S-17, L-22.3, C-19) line items.
- **H-2** Profile system implementation `profiles/active.sh`.
- **H-3** Sectioned advisory locks per §2.7 (15 sections including `quality_standards_directory`, `rule_cache`, three freshness sections); `hooks/scripts/lock-acquire.sh`/`lock-release.sh`.
- **H-4** `SECURITY.md` threat model: trust boundary, hook safety per script, MCP token handling, standards/PR/compliance fetcher trust models, signing key handling, audit-log integrity, SPACE privacy, PII guard limits, paywalled-attestation integrity, operator-added URL/repo/framework trust models.
- **H-5** Multi-language honesty: README marks JS/TS/Python first-class; `/doctor` warns on partial-coverage repos; `/analyze` includes coverage caveat.
- **H-6** Built-in command reconciliation: `/spec` keep, `/plan-first` keep, `/review` renamed `/review-panel`.
- **H-7** `/doctor --watch` long-lived health monitor; co-runs with S-10, L-10, C-19, S-17.
- **H-8** License attribution sweep `compliance/licenses.yaml` + `hooks/scripts/license-attribution.sh`; runs in `/analyze` and `/audit-pack`; validates community-installed plugins (E-7) honor license metadata; validates paywalled compliance attestations.
- **H-9** Documentation progressive disclosure: `docs/getting-started.md`, `docs/first-week.md`, `docs/reference.md`, `docs/source-folders.md`, `docs/threat-model.md`, ESLint-migration cheatsheet; `skills/help/SKILL.md` for `/help <topic>`.
- **H-10** Plugin community contribution catalog: `community/sources/`, `community/frameworks/`, `community/rules/` (each with contributor identity, review status, eval evidence, license); `community/REVIEW.md` (2-reviewer required for tier-1).
- **H-11** Plugin self-test against itself in CI: `.github/workflows/self-test.yml` runs `/analyze` on plugin's own repo; failures gate releases. Includes G-12, G-13 validators.

## §12. Phase L — Public Engineering Corpus Learning

- **L-1** PR source catalog (10 default sources):

| id | source_class | tier | applies_to |
|---|---|---|---|
| cfpb-consumerfinance | federal-financial-regulator | 1 | react, node |
| 18f-identity-idp | fedramp-high | 1 | node, security |
| va-vets-website | federal-digital-services | 1 | react, node |
| gsa-site-scanning | federal-infrastructure | 1 | node |
| stripe-node | financial-industry | 1 | typescript, node, library |
| capitalone-cloud-custodian | financial-industry | 1 | python |
| jpmorganchase-mosaic | financial-industry | 1 | typescript, node, react |
| finos-perspective | financial-industry-consortium | 1 | typescript, node, performance |
| kubernetes-kubernetes | gold-standard-process | 1 | infrastructure |
| bloomberg-memray | financial-industry | 2 | typescript, python |

- **L-2** PR fetcher with local-LLM eligibility (X-4); `gh` api-based; rate-limit-aware (5000/hr); resumable cursor; ToS-compliant.
- **L-3** Triage filter (≥2 substantive comments; reviewer requested changes OR iterative push; merged; not bot/docs).
- **L-3.5** Manual L-quality eval gate `pr-corpus/quality-eval.sh`: 20 hand-graded PRs; precision ≥0.7 + mean usefulness ≥3/5 required before L-10 monitor activates.
- **L-4** Pattern extractor subagent `agents/pr-pattern-extractor.md` (sonnet) with verbatim-quote enforcement and per-pattern `usefulness_estimate: 1-5`.
- **L-5** Two-pass embedding+LLM reconciler: cosine shortlist → subagent classifies (`same | refinement | adjacent | novel | conflict`); thresholds calibrated against held-out O-1 set.
- **L-6** Evidence aggregation (≥3 PRs, ≥2 orgs, ≥1 tier-1) with reviewer-affiliation cache (24h TTL); consortium reviewer-affiliation determines org count.
- **L-7** `/pr-corpus-update` honors per-source token budget; default 100k tokens/day cap.
- **L-8** `/pr-corpus-learn` with codebase-impact preview (F-6); chains to S-7 promote flow with `class: pr-corpus` provenance.
- **L-9** Provenance type extension (`class: pr-corpus`, `supporting_prs` with verbatim quotes, `evidence_count`, `organizations_count`); P0 still requires tier-1 published-standard.
- **L-10** Daily monitor `pr-corpus/monitor.sh` (gated by L-3.5).
- **L-11** Anti-poisoning safeguards consolidated.
- **L-12** PR diffs → P-2 eval-dataset feedback `skills/pr-to-eval-dataset/SKILL.md`.
- **L-13** Conflict surfacing → `pr-corpus/decisions.jsonl`.
- **L-14** Audit & compliance integration (writes to C-4 audit log; included in `/audit-pack` "Continuous learning evidence" section); satisfies SOC 2 CC4.1 + EU AI Act Art. 12.
- **L-15** Cross-loop integration.
- **L-16** GitHub issue tracker extension (security-tagged issues from cfpb, 18F-identity-idp, kubernetes).
- **L-17** `PR-SOURCES.yaml` operator-editable registry at `.claude-tdd-pro/`.
- **L-18** Sync mechanism `pr-corpus/sync-from-sources.sh`.
- **L-19** Daily-fresh PR fetch guarantee.
- **L-20** `/pr-source-add <github-org>/<repo>` with metadata extraction, activity check, tier prompt.
- **L-21** `/pr-source-remove <id>` with sole-evidence citation check; archives evidence to `pr-corpus/evidence/_archived/`.
- **L-22** Live freshness gate on PR-corpus rule activation; daily auto-refresh `pr-corpus/auto-refresh-daily.sh`; strict-mode disables stale rules.
- **L-23** Generation-time PR-corpus consumption trace.
- **L-24** Closed-loop validation.

Each `PR-SOURCES.yaml` entry maps to a folder under `generated-code-quality-standards/<source-class-namespace>/` (G-9.1 sync: `federal-financial-regulator` → `us-government/`, `financial-industry` → `finance-industry/`, `gold-standard-process` → `linux-foundation/`).

## §13. Phase O — Operational Readiness

- **O-0** Telemetry-first baseline discipline (week 1; no new components without budget impact estimate).
- **O-1** Seed corpus `seed/`: 12 hand-written postmortems, 30 pre-graded FP examples per existing rule, 20 hand-curated PR-corpus patterns, ~30 inputs per review subagent dataset. Tagged `bootstrap_seed: true`.
- **O-2** Global `--dry-run` mode per §2.14.
- **O-3** Plugin lifecycle: `/uninstall-cleanup` (category-by-category; never auto-deletes evidence/audit-log), `migrations/<from>-to-<to>.sh` per-version (preserve user state), `/self-test` (extends `/doctor`).
- **O-4** Multi-machine git-backed sync `skills/sync/SKILL.md`: `tdd-pro-sync` branch with FAILURE-LOG, decisions.jsonl, fp-log/, audit checkpoints, workflow-state, STANDARDS-URLS.yaml, PR-SOURCES.yaml, COMPLIANCE-URLS.yaml, `_operator/` tree, `_community/` plugins, all attestations.
- **O-5** Audit log signed checkpoints (cross-ref C-4.6/C-4.7).
- **O-6** External meta-eval: `meta-eval/known-good/` (pinned Kubernetes minor as submodule), `meta-eval/known-bad/` (synthetic anti-pattern codebase). Quarterly + on major release; results in `meta-eval/HISTORY.md`. Calibration baseline: known-good ≤5 P0, ≥90% P1 absence; known-bad ≥1 finding per anti-pattern.
- **O-7** Per-rule canary (cross-ref RNT; `rule_state warn-only → block` after 14d clean).
- **O-8** Threat model evolution doc `docs/threat-model.md`: adversarial-repo, compromised standards/PR/compliance source, insider threat, paywalled-attestation integrity.
- **O-9** Anonymous shared-learning opt-in `community/shared-learning/SKILL.md`: aggregate fp/tp counts only; hashed ID; no IP collection.
- **O-10** Rubric semver: `RUBRIC.yaml` top-level version; major bumps on breaking detector contracts; lock pins; `rubric/changelog.md`.
- **O-11** Bootstrap eval scenarios at install time.

## §14. Phase X — Execution Surfaces

- **X-1** GitHub Actions adapter `.github/workflows/rubric-check.yml`: reads `lock.json.profile_snapshot_hash`; runs runner against PR diff; uploads SARIF (E-9) to GitHub Code Scanning; comments findings with rule IDs and remediation links; `--format github-actions` workflow commands; pre-flight standards/PR/compliance freshness check for regulated/financial/government profiles.
- **X-2** GitLab CI adapter `ci/.gitlab-ci.template.yml`: `--format checkstyle`; MR comments via gitlab-cli.
- **X-3** pre-commit framework adapter `ci/pre-commit-hooks.yaml`: same detectors as Claude Code PreToolUse + CI; `--format markdown`.
- **X-4** Local LLM fallback `skills/local-llm/SKILL.md`: Ollama/llama.cpp/LM Studio; cheap-operation routing (L-3 triage, L-6 affiliation parsing, L-16 issue-label filtering); ~30-50% baseline daily token cost reduction.
- **X-5** Visualization layer `tui/`: `/space-report --tui`, `/coverage --tui`, `/audit-pack --tui` interactive views (charm.sh-style); markdown remains default.

## §15. Phase W — Workflow Orchestration

- **W-1** `/architect <feature-or-architecture-description>`:
  - **W-1.1-1.2** Command + skill `skills/architect/SKILL.md`
  - **W-1.3** Decomposition pass identifies discrete decision points
  - **W-1.4** S+L+C-grounded options enumeration via standards-comparator (S-8) + pr-pattern-extractor (L-4) + active compliance frameworks
  - **W-1.5** Per-option presentation (what/problem/trade-offs/when-pick/observed-in-PRs/standards/compliance)
  - **W-1.6** Interactive prompt-per-decision
  - **W-1.7** ADR auto-generation per §2.16
  - **W-1.8** Hand-off to `/spec` → `/plan-first` → `/feature`
  - **W-1.9** Profile-aware option narrowing
  - **W-1.10** Architect subagent `agents/architect.md` (sonnet, prompt_id `architect-elicitor`); cites every option to S section ID, L PR URL, or C control; declines if grounding unavailable; references rule's `source_file` (G phase) and `docs_url` (E-8)
- **W-2** Git workflow guidance `skills/git-workflow/SKILL.md`:
  - Branch-off recommendations (commit threshold, file threshold, critical-path touch)
  - Push-timing recommendations (clean CI, no P0, no pending legal review; warns on WIP/uncommitted/failing-tests/unmet-SoD)
  - Merge-strategy recommendations (squash for ≤3 commits single concern; merge commit for multi-concern; rebase warning on shared)
  - Branch hygiene (stale-branch detection)
  - Diverged-from-main warnings
  - Per-profile thresholds (regulated halves all)
  - `/git-recommend` manual command
- **W-3** Workflow state machine `.claude-tdd-pro/workflow-state.json` per §2.15; transitions logged to C-4; resumable; H-3 sectioned lock; recovery via audit-log fallback.
- **W-4** Decision provenance trail: `docs/adr/` registry; `INDEX.md` auto-maintained; ADR superseding chain; commits include `Decision: <adr-id>` trailer; surfaces in `/audit-pack` "Decision Trail" section as EU AI Act Art. 12 record-keeping evidence.
- **W-5** Profile registration.
- **W-6** Closed loop: describe → architect → ADR → spec → plan-first → feature (TDD-Guard) → per-CL commits with Decision trailer → git-workflow → `/pr` → `/audit-pack` with Decision Trail.

## §16. Phase E — ESLint-Parity Rule Engine

- **E-1** Per-config severity override: `rules: { <id>: off | warn | error | 0 | 1 | 2 | ["error", { options }] }`; resolution order with `/doctor --explain <rule-id>`.
- **E-2** Rule options with JSON schema validation: `options_schema` per rule; defaults merged; invalid options block profile activation; detectors receive `--options <json>`.
- **E-3** Glob-based overrides: `overrides: [{ files, rules }]`; fnmatch globs; later wins; per-file resolution at runtime; `profiles/_overrides/test-files.yaml`, `critical-paths.yaml`, `scripts.yaml`, `stories.yaml`, `generated.yaml`.
- **E-4** Auto-fix: `--fix`/`--fix-dry-run` detector flags; `fixable: code | whitespace | null`; `has_suggestions: true` for manual-confirm; `/fix-rules [--rule-id] [--paths] [--include-suggestions]` command; recorded to C-4 audit log.
- **E-5** Inline suppression with justification: `// rubric-disable[-next-line|-this-line] <id> -- <justification>` and `/* rubric-disable */ ... /* rubric-enable */`; justification required by default; F-4 tracks quality (length, repetition); per-rule suppression count in `rubric/suppressions/<rule-id>.jsonl`.
- **E-6** Recommended sets: per-rule `recommended: true`; `extends: rubric:recommended`, `rubric:all`, `<plugin-id>:recommended`.
- **E-7** Third-party rule plugin protocol per §2.20; `/plugin-install <github-org>/<repo>` clones via `gh`, validates `plugin.yaml`, runs E-11 tests, registers under namespaced IDs (`<plugin-id>/<rule-id>`); plugin signing supported; `userConfig.require_signed_plugins: true` enforces.
- **E-8** Standardized rule metadata per §2.1: `type`, `fixable`, `has_suggestions`, `deprecated`, `replaced_by`, `docs_url`, `requires_type_checking`, `recommended`, `options_schema`, `messages`; validated by `rubric/detectors/rule-metadata-complete.sh` in `/doctor` and CI.
- **E-9** Reporters/formatters: markdown (default), json, sarif (GitHub Code Scanning), checkstyle (GitLab), junit, github-actions (workflow commands), tui (X-5). Plugins ship custom formatters at `formatters/<name>.sh`.
- **E-10** Rule deprecation lifecycle: `deprecated: true`, `replaced_by: [...]`; `/doctor` reports; `/measure-rubric` action cards "REPLACE: `<deprecated>` → `<replacement>`"; `/migrate-rule <deprecated> --to <replacement>` updates profiles + ADRs + inline suppressions; deprecated ≥1 minor version before removal.
- **E-11** RuleTester-equivalent test framework: `tests/<rule-id>/{valid,invalid}/<case>.{ts,json}`; `bash rubric/test-rule.sh <rule-id>` and `--all`; H-11 CI gate.
- **E-12** Per-rule per-file cache `.claude-tdd-pro/rule-cache/<rule-id>.json`: cache key `sha256(file-content + rule-version + resolved-options + plugin-version)`; auto-purge entries unused >30 days; max 100MB LRU eviction; F-2 reports hit rate; H-1 token transparency shows ~0 tokens for cache hits.
- **E-13** messageIds for i18n: `messages: { <messageId>: template }`; detector emits `{messageId, data}`; `messages/<locale>/<rule-id>.json`; `userConfig.locale: en` default; untranslated falls back to English.
- **E-14** ESLint config import bridge `/import-eslint-config <path>`: parses ESLint flat or `.eslintrc`; for each rule attempts mapping (direct match → semantic match → no match suggests E-15 wrap); writes `profiles/imported-from-eslint.yaml` draft; `import/eslint-rule-mapping.yaml` community-maintained.
- **E-15** ESLint rules as detectors: `rubric/detectors/wrap-eslint.sh` generic wrapper; rule schema `detector_config: { eslint_rule, eslint_plugin_npm, eslint_plugin_version, eslint_options }`; auto-installs npm package on first use; cached in `node_modules`; existing g-react-002, g-react-003, g-ts-007 use this pattern.
- **E-16** Plugin discovery and management: `/plugin-install`, `/plugin-list [--show-rules] [--show-cost]`, `/plugin-update [<id>]` (re-runs E-11 tests; rejects on test failure), `/plugin-remove <id>` (flags affected rules with `provenance_status: plugin-removed`).
- **E-17** Closed loop.

## §17. Phase G — Generated Quality-Standards Directory

- **G-1** Directory at plugin root: `generated-code-quality-standards/` with 14 default source-namespace folders (`google`, `us-government`, `european-union`, `finance-industry`, `owasp`, `w3c`, `web-vitals`, `react`, `node`, `typescript`, `slsa`, `linux-foundation`, `industry-self-regulatory`, `_universal`) + `_operator/`, `_community/`, `_meta/`. Initial v1.9 ships ~38 rule files.
- **G-2** Source-organized file format (ESLint-style per file): `source:` header (`id`, `authoritative_publisher`, `authoritative_url`, `registry_link`, `fetched_at`, `content_hash`, `fetch_frequency`, `fragility_tier`, `license_note`); `rules:` array per §2.1 with full E-8 metadata; `recommended_set:`; `all_set:`.
- **G-3** Rule ID namespacing: `g-` prefix for plugin-shipped, `g-universal-` for cross-cutting in `_universal/`, `<operator-id>-` for operator additions in `_operator/<my-org>/`, `<plugin-id>/` for community plugins in `_community/<plugin-id>/`. IDs stable across file moves; deprecation pathway via E-10.
- **G-4** Migration from `rubric/RUBRIC.yaml` to source-organized files: `scripts/migrate-rubric-to-source-folders.sh`; one-time week-1; archives original to `RUBRIC.legacy.yaml.archived`; audit record in `_meta/migration-from-rubric-yaml.md`. Mapping table for all 58 pre-baked rules to their primary source files (see §7-§9).
- **G-5** Aggregator (`rubric/runner.sh` extension): reads every YAML under `generated-code-quality-standards/` recursively; aggregation order: `_universal/*.yaml` → plugin folders alphabetically → `_community/<plugin-id>/*.yaml` → `_operator/**/*.yaml` (last so operator overrides win); within folder alphabetical files; within file declaration order. Conflict handling: operator overrides plugin defaults; community plugin redefining built-in ID rejected at install. Cache awareness via directory tree hash; lock file pins.
- **G-6** Source-file schema per §2.21 contract; `generated-code-quality-standards/validate-source-file.sh`.
- **G-7** Per-source granular extends in profiles (per §2.5): `extends: [<source-namespace>:<file>]`, `[<source-namespace>:<file>:all]`, `[<source-namespace>:*]`, `[<source-namespace>:*:all]`. `exclude_sources:` array. `include.operator_namespaces:` to scope to specific orgs. Per-industry profile templates: `financial.yaml`, `government.yaml`, `healthcare.yaml`, `eu-financial.yaml` demonstrate per-source extends.
- **G-8** Source-folder operator additions per §2.22; `_operator/<my-org>/conventions.yaml` for org rules; `_operator/<source-namespace>/<file>-extensions.yaml` for extending plugin defaults; `/operator-namespace-init <my-org>` and `/operator-extension-init <source-namespace> <file-name>` scaffold commands.
- **G-9** Sync with operator-curated registries (auto-scaffold):
  - `STANDARDS-URLS.yaml` entry → `<inferred-namespace>/<id>.yaml` via id prefix or operator-set `source_namespace`
  - `COMPLIANCE-URLS.yaml` entry → namespace by jurisdiction (US Federal → `us-government/`, EU → `european-union/`)
  - `PR-SOURCES.yaml` entry → namespace by `source_class` (`federal-financial-regulator` → `us-government/`, `financial-industry` → `finance-industry/`, `gold-standard-process` → `linux-foundation/`)
  - `/standards-add`, `/compliance-add`, `/pr-source-add` auto-create folder + scaffold file with populated `source:` header. `/standards-remove`, `/compliance-remove`, `/pr-source-remove` archive folder file to `_archived/`.
- **G-10** Index generation: `_meta/INDEX.md` auto-regenerated per source folder file change; per-namespace counts (files, rules, recommended); per-file metadata (title, last-fetched, rule count, link); operator-readable.
- **G-11** Plugin protocol — community plugin source-folder convention per E-7: plugin's `generated-code-quality-standards/<plugin-namespace>/` copied to `_community/<plugin-id>/<plugin-namespace>/`; detectors to `rubric/detectors/_community/<plugin-id>/`; tests to `rubric/tests/_community/<plugin-id>/`; rules namespaced `<plugin-id>/<rule-id>`.
- **G-12** Validation: `generated-code-quality-standards/validate-all.sh` runs in `/doctor` and CI (H-11). Failures: file's rules excluded from aggregation until fixed; `--allow-invalid-source-folder` bypass logged.
- **G-13** ESLint compliance verification: `validate-eslint-compliance.sh` checks every rule has full E-8 metadata; per-source-file ESLint config equivalence test (could the file be expressed as an ESLint plugin's recommended config? must answer yes).
- **G-14** Closed loop: operator browses → registry edit → folder auto-scaffold → rules authored → aggregator picks up → profile extends per-source → `/doctor` INDEX accurate → `/audit-pack` reports per-source-folder coverage; full loop validates within 10 minutes per closed-loop validation week 25.5.

## §18. Cumulative file/component inventory at v1.9

| Layer | Components |
|---|---|
| Substrate (v0.3) | `runner.sh` (now reads G-1), 17 commands, 11 subagents, 14 skills, 4 hooks, 6 detectors, 12 evals, 9 templates, 3 styles, MCP. `RUBRIC.yaml` archived; rules in `generated-code-quality-standards/` |
| F (Foundation) | +5 commands, +1 subagent (critical-path-verifier), +2 skills, +1 helper, +5 evals |
| G (Quality-Standards Directory) | `generated-code-quality-standards/` tree (14 namespaces + `_operator`/`_community`/`_meta`), ~38 source files, +4 commands (`operator-namespace-init`, `operator-extension-init`, `source-folder-validate`, `source-folder-rebuild-index`), +5 detectors/scripts (`validate-source-file`, `validate-all`, `validate-eslint-compliance`, `sync-from-registries`, `migrate-rubric-to-source-folders`), +20 evals, `INDEX.md` auto-generated |
| E (Rule Engine) | +9 commands (`fix-rules`, `plugin-install`, `plugin-list`, `plugin-update`, `plugin-remove`, `import-eslint-config`, `migrate-rule`, `scaffold-rule`, `clear-rule-cache`), +2 detectors (`rule-metadata-complete`, `wrap-eslint`), +6 formatters, +`rubric/test-rule.sh`, +`tests/<rule-id>/` tree, +`messages/<locale>/<rule-id>.json`, +`import/eslint-rule-mapping.yaml`, +`.claude-tdd-pro/plugins/` tree, +`.claude-tdd-pro/rule-cache/` tree, +`rubric/suppressions/` tree, +`profiles/_overrides/` tree, +50 evals |
| S (Standards) | +6 commands, +1 subagent (`standards-comparator`), +2 skills, +5 detectors/scripts, +12 evals, `standards/` tree (17 sources), `STANDARDS-URLS.yaml`, `standards-last-fetch/` |
| C (Compliance) | +5 commands (`risk-classify`, `audit-pack`, `legal-review-mark`, `compliance-add`, `compliance-remove`, `compliance-attest`), +1 subagent (`review-compliance`), +6 hooks/scripts, +24 evals, `compliance/` tree (25+ frameworks), `COMPLIANCE-URLS.yaml`, `compliance-last-fetch/`, `attestations/`, `attestations/_archived/` |
| P (Prompt lifecycle) | +4 commands, +1 detector, +5 evals, `prompts/` tree, `evals/datasets/` tree |
| R (React) | +2 subagents, +10 rules in source folders, +4 detectors, +3 templates, +1 skill, +5 evals |
| N (Node) | +2 subagents, +10 rules in source folders, +5 detectors, +5 evals |
| T (Types) | +1 subagent, +8 rules in source folders, +3 detectors, +1 template, +3 evals |
| Q (SPACE) | +1 command, +2 hooks, +2 skills, +5 evals, `space/` tree |
| H (Hardening) | +7 polish, +1 detector, +6 evals, +1 skill, `community/` tree, `.github/workflows/` |
| L (PR Corpus) | +4 commands (`pr-corpus-update`, `pr-corpus-learn`, `pr-source-add`, `pr-source-remove`), +2 subagents (`pr-pattern-extractor`, `comparator-grade quality eval`), +2 skills (`promote-standard pr-corpus variant`, `pr-to-eval-dataset`), +3 detectors/scripts, +18 evals, `pr-corpus/` tree (10 sources), `PR-SOURCES.yaml`, `pr-corpus-last-fetch/`, `evidence/_archived/` |
| O (Operational Readiness) | +3 commands (`uninstall-cleanup`, `self-test`, `migrate`), +1 skill (`sync`), +5 evals, `seed/`, `meta-eval/`, `migrations/` trees |
| X (Execution Surfaces) | +3 CI adapters, +1 skill (`local-llm`), `tui/` tree, +3 evals |
| W (Workflow Orchestration) | +2 commands (`architect`, `git-recommend`), +1 subagent (`architect`), +2 skills (`architect`, `git-workflow`), +20 evals, `docs/adr/` tree, `workflow-state.json` |

**Totals at v1.9:** ~25 subagents, ~25 skills, ~62 commands, ~45 detectors/scripts, ~221 eval specs, 14 templates, 6 built-in formatters, 9 profiles + override library + per-industry templates, 17 default standards sources, 25+ default compliance frameworks, 10 default PR-corpus sources, 14 source-namespace folders containing ~38 ESLint-compliant rule files holding 58 pre-baked rules, plugin protocol for community rules, full ESLint ecosystem consumable via E-15 wrapping or E-7 plugin install.

## §19. Out of scope — irreducible 0.15 gap to 10.0

- Production telemetry from your own users (closes when you ship to real users)
- Statistically valid prompt A/B at scale (P-5 honesty guard preserves signal-quality at solo scale)
- External SOC 2 Type 2 attestation (CPA firm + 6-month audit window required)
- EU AI Act conformity assessment for high-risk (notified body required)
- Tacit Google internal review judgment (private monorepo norms remain tacit)
- Formal-method assertions on critical paths (TLA+/Alloy + culture)
- First-run empirical quality of learning components (L-3.5 + canary gate scaling)
- CycloneDX-AI tooling maturity (downstream auditor acceptance external)
- Legal review of EU AI Act mappings (mechanically tracked; review remains human work)

## §20. Execution order — canonical staged path

| Week | Phase IDs | Score after | Discipline |
|---|---|---|---|
| 1 | F-0 + O-0 + O-1 + E-1, E-2, E-8 + G-1, G-2, G-4, G-6, G-12, G-13 | 7.1 | Telemetry + ESLint-parity + source-folder structure from day one |
| 2–4 | F-1 → F-6 + E-5, E-11, E-12 + G-3, G-5, G-10 | 7.8 | Foundation; rules organized in source folders |
| 5–7 | S-1, S-2, S-3, S-4, S-6, S-12, S-13, S-17 + G-9 (standards sync) | 8.1 | Standards substrate + auto-scaffold |
| 7.5 | S-14, S-15, S-16, S-18 | 8.15 | Standards operator curation |
| 8–9 | C-2, C-3, C-4, C-7 | 8.45 | Compliance baseline |
| 9.5 | C-13, C-15, C-19 + G-9 (compliance sync) | 8.5 | Compliance operator-editable |
| 10 | O-2, O-3, O-7, O-11, H-9 + E-3, E-6, E-10 + G-7 | 8.75 | Operational readiness + ESLint protocol + per-source granularity |
| 11–12 | R-1 → R-7, N-1 → N-5, T-1 → T-6 (in source folders) | 8.95 | Coverage; canary; rules born into proper source files |
| 13 | X-1, X-2, X-3 + E-9 | 9.05 | CI adapters with ESLint formatters |
| 14 | P-1, P-2, P-3, P-6 + E-4, E-15 | 9.15 | Prompt lifecycle + auto-fix + ESLint wraps |
| 15 | C-5, C-8, C-10, C-11 | 9.25 | Full compliance flow |
| 15.5 | C-16, C-17, C-18, C-20 | 9.3 | Compliance operator commands |
| 16 | Q-1 → Q-9 | 9.4 | SPACE measurement |
| 17 | L-1, L-2, L-3, L-3.5, L-4, L-5, L-6 + G-9 (pr sync) | 9.45 | PR corpus baseline |
| 17.5 | L-17, L-19 | 9.47 | PR-corpus operator-editable |
| 18 | L-7, L-8, L-9, L-11, L-12, L-13, L-14, L-16 | 9.52 | Full PR-corpus loop |
| 18.5 | L-20, L-21, L-22, L-23 | 9.55 | PR-corpus operator commands |
| 19 | L-10, O-6, O-9 + E-7, E-16 + G-8, G-11 | 9.65 | Continuous learning + community plugin convention |
| 20 | X-4, X-5, H-10, O-8, O-10, H-11 + E-13, E-14 | 9.7 | Polish, i18n, ESLint config import |
| 21 | W-1 | 9.75 | Architect |
| 22 | W-2, W-3 | 9.78 | Git workflow + state machine |
| 23 | W-4, W-5, W-6 | 9.8 | Decision provenance trail |
| 23.5 | S-19 closed-loop validation | 9.8 | Standards loop end-to-end |
| 24 | L-24 closed-loop validation | 9.82 | PR-corpus loop end-to-end |
| 24.5 | C-21 closed-loop validation | 9.83 | Compliance loop end-to-end |
| 25 | E-17 closed-loop validation | 9.84 | Rule engine ESLint-parity end-to-end |
| 25.5 | G-14 closed-loop validation | 9.85 | Source-folder loop end-to-end |

**Total CL count:** ~265. **Effort:** ~23–28 weeks part-time / ~12–14 weeks full-time.

**Critical sequencing rules:**
- Week-1 telemetry baseline non-negotiable; no subsequent component approved without budget impact estimate
- Each rule lands in canary state
- L-10 monitor blocked until L-3.5 quality eval passes
- Each new layer's first command shipped is `--dry-run` mode
- No production-telemetry/external-attestation claims until evidence exists
- W comes last because every W component depends on lower-layer maturity
- W-1 anti-hallucination eval (W-1.11.1) must pass before W-1 enabled in any default profile
- G-1 through G-6 ship in week 1 with F-0/E-1/E-2/E-8 — directory structure in place before any subsequent rule work
- R/N/T rules in weeks 11-12 are authored directly into source folders (not migrated later)

## §21. Definition of done — v1.9

The plugin is at v1.9 / 9.85-of-10 (build confidence 9/10 via canonical staged path) when, simultaneously:

- All v1.8 acceptance criteria met (32 v1.4 + 12 v1.5 + 14 v1.6 + 16 v1.7 + 20 v1.8 criteria)
- `generated-code-quality-standards/` exists at plugin root with 14+ source-namespace folders + `_operator/` + `_community/` + `_meta/`
- All 58 pre-baked rules migrated from `rubric/RUBRIC.yaml` into source-organized files; original archived; migration audit record in `_meta/migration-from-rubric-yaml.md`
- Every source file passes G-12 schema validation (`source:` header, full E-8 metadata, detectors exist, provenance URLs match registry entries, no duplicate IDs)
- Every source file passes G-13 ESLint-compliance verification
- `_meta/INDEX.md` auto-regenerated and accurate
- ≥1 operator namespace exists at `_operator/<my-org>/` with ≥1 custom rule
- ≥1 community plugin installed via `/plugin-install` populates `_community/<plugin-id>/`; rules namespaced correctly
- ≥1 profile demonstrates per-source granular extends
- ≥1 profile demonstrates `exclude_sources:` removing entire folder
- Adding STANDARDS-URLS / COMPLIANCE-URLS / PR-SOURCES entries auto-creates source-folder scaffolds within 60 seconds
- Removing any auto-archives source-folder file to `_archived/`
- `/doctor --explain <rule-id>` shows rule's `source_file` in resolution chain
- `/audit-pack` includes "Source Folder Coverage" section
- `profiles/standard.yaml` uses `extends: [rubric:recommended]` and resolves correctly
- Per-industry templates ship and demonstrate per-source extends
- Aggregator (G-5) handles 200+ rules across 38+ files in <500ms at startup
- G-14 closed-loop end-to-end test passes within 10 minutes
- README v1.9 includes "Browse the rules" section pointing at `generated-code-quality-standards/`
- Every E-1 through E-17 acceptance criterion met (severity overrides, options, glob overrides, auto-fix, inline suppression, recommended sets, plugin protocol, metadata, formatters, deprecation, RuleTester, cache, messageIds, ESLint config import, ESLint-as-detector wraps, plugin commands, closed-loop validation)
- Every S-1 through S-19, C-1 through C-21, L-1 through L-24, F-1 through F-6, P-1 through P-9, R/N/T full coverage, Q-1 through Q-9, H-1 through H-11, O-0 through O-11, X-1 through X-5, W-1 through W-6 acceptance criterion met
- README v1.9 documents the operator workflow end-to-end
- Symmetric documentation: STANDARDS-URLS.yaml + PR-SOURCES.yaml + COMPLIANCE-URLS.yaml all prominently referenced in `/doctor`, `/init-guardrails`, README, getting-started; `generated-code-quality-standards/` directory tree referenced as discoverability entry point

## §22. Confidence ranking summary

| Phase | v1.9 |
|---|---|
| F (Foundation) | 9/10 |
| G (Quality-Standards Directory) | 9/10 (mechanical reorganization; ESLint-style well-understood) |
| E (Rule Engine — ESLint-parity) | 9/10 |
| S (Standards) | 8.5/10 |
| C (Compliance) | 8.5/10 |
| P (Prompt lifecycle) | 8.5/10 |
| R/N/T (Coverage) | 9/10 |
| Q (SPACE) | 8/10 |
| H (Hardening) | 9/10 |
| L (PR Corpus) | 8/10 |
| O (Operational Readiness) | 9/10 |
| X (Execution Surfaces) | 9/10 |
| W (Workflow Orchestration) | 8.5/10 |

Capability ranking: 9.85/10. Build confidence: 8.5/10 for full v1.9 on timeline; 9/10 via canonical staged path.
