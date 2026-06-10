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
│  ║   + v1.9.1: IDE rules export (X-6) · installable hooks (X-7)       ║    │
│  ║   + v1.10:  LSP server (X-8) · cloud devcontainer (X-9)            ║    │
│  ╚═════════════════════════════════════════════════════════════════════╝    │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Diagram note — v1.9.1 (§23) and v1.10 (§24) amendments not all shown above.** The diagram summarizes the v1.9 base. Amendments outside the X row that are NOT redrawn: H-12 continuous cost-telemetry rollup (Hardening row), W-10 concurrent CL gate / W-11 parallel subagent orchestrator / W-12 conversational PR review subagent (Workflow Orchestration row), P-10 runtime model router (Prompt Lifecycle row), O-12 application scaffolds (Operational Readiness cross-cut), §2.23 concurrent-CL contract / §2.24 portable audit-pack format (cross-cutting contracts). The §23 and §24 blocks at the end of this document are authoritative; the diagram is illustrative.

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
  "ai_involvement": { "tier": "...", "models_used": [ { "model": "...", "tier_class": "fast | balanced | deep", "router_resolved": true, "frontmatter_model": "...", "decision_reason": "..." } ], "agents_invoked": [], "skills_invoked": [], "prompts": [] },
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

File: `space/metrics.yaml`. Top-level `metrics:` key wrapping an array of metric definitions.

```yaml
metrics:
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

Subject commands (every `destructive: true`): `/remediate`, `/promote-standard`, `/pr-corpus-learn`, `/risk-classify`, `/audit-pack`, `/prompt-promote`, `/space-export`, `/uninstall-cleanup`, `/migrate`, `/architect`, `/standards-add`, `/standards-remove`, `/pr-source-add`, `/pr-source-remove`, `/compliance-add`, `/compliance-remove`, `/fix-rules`, `/plugin-install`, `/plugin-update`, `/plugin-remove`, `/import-eslint-config`, `/operator-namespace-init`, `/operator-extension-init`, `/export-rules` (X-6), `/install-hooks` (X-7), `/cl-status` (W-10), `/scaffold` (O-12), `/router-set` (P-10), `tdd-pro-lsp --print-diagnostics` (X-8).

### §2.15 Workflow state contract

`.claude-tdd-pro/workflow-state.json`: `session_id`, `current_phase`, `feature_description`, `architect_session: { decisions: [{id, decision_point, options_presented, selected, rationale, adr_path}] }`, `spec_path`, `plan_approved_at`, `commits`, `branch_recommendations`, `standards_consulted`, `pr_corpus_consulted`, `compliance_consulted`, `_resumable`. When `userConfig.allow_concurrent_cls: true` (per §2.23 / W-10), the top-level shape becomes `{ "_concurrent": true, "sessions": { "<session_id>": { ...envelope above... } } }` — each `session_id` keys its own envelope; concurrent CLs each mutate only their own envelope.

### §2.16 Decision provenance schema (MADR ADRs auto-generated by W-1)

`docs/adr/<date>-<slug>.md` with `status`, `deciders`, `architect_session`, `decision_id`, `profile_active`, `context`, `considered_options` (verbatim from W-1.5), `decision_outcome` with `rationale`, full provenance trail. `status` enum: `proposed | accepted | rejected | superseded | deprecated` (MADR-standard). File name pattern: `^[0-9]{4}-[a-z0-9-]+\.md$`.

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

### §2.23 Concurrent CL execution contract (v1.9.1 amendment — see §23)

Two or more CLs MAY execute concurrently when ALL of: (a) disjoint phase set — no two CLs author specs or implementation for the same phase ID; (b) disjoint workflow-state subsections per §2.15 — each CL writes its own `session_id` envelope and does not mutate another CL's `current_phase`/`spec_path`/`commits`/`architect_session`; (c) disjoint lock sections per §2.7 — no two CLs hold concurrent writes on overlapping `_locks.<section>` names; (d) disjoint source-folder ownership — no two CLs author rules in the same `generated-code-quality-standards/<source-namespace>/<file>.yaml`; (e) disjoint commit branches — concurrency is per-branch, never on the same branch. Overlap on any condition rejects the second CL at the W-10 gate with the offending overlap reported (phase/lock/state-section/file/branch). Audit-log entries from concurrent CLs interleave through C-4's per-section Merkle chain; checkpoints (C-4 every 100 entries) tolerate interleaving without conflict because each entry is independently hash-chained against its predecessor. Concurrency is opt-in; default mode remains sequential per §20.

### §2.24 Portable audit-pack export format (v1.9.1 amendment — see §23)

`/audit-pack --emit <format>` writes a portable bundle to `compliance/audit-packs/<bundle-id>/` where `bundle-id = <commit-sha>-<utc-timestamp>`. Formats: `json` (machine-consumable schema), `markdown` (human review), `html` (self-contained for non-cloned review), `tarball` (all formats bundled with detached signature). JSON top-level schema: `{ bundle_schema_version: "1.0", bundle_id, generated_at, commit, profile_snapshot_hash, aibom_uri, control_coverage, evidence_set, risk_classification, audit_log_window: { first_entry, last_entry, checkpoint_uris }, provenance_manifest_uris, decision_trail, standards_freshness, pr_corpus_freshness, compliance_freshness, all_three_fresh_badge, cost_telemetry_summary, signature }`. Schema validates against `compliance/audit-pack-schema.json` (versioned via `bundle_schema_version`). Export is reproducible: same inputs at same commit produce byte-identical bundles via canonical JSON encoding (sorted keys, RFC 8785 JCS), pinned timestamps from C-4 audit log, no wall-clock-time leakage. Bundles are read-only artifacts; ingesting tools (code-review platforms, compliance pipelines, junior-onboarding viewers) consume the schema without coupling to TDD-Pro internals. No new data collected versus C-10; this is a serialization contract over existing content.

### §2.25 Pending-spec content fidelity contract (v1.9.2 amendment — see §25)

Every spec under `evals/pending/<phase>/<feature-id>-<descriptive-label>/` MUST assert behavior using only vocabulary that appears verbatim in `docs/architecture-v1.9.md` for the corresponding feature ID. Audited vocabulary includes: (a) field names referenced in spec setup arrays or command assertions; (b) YAML/JSON document shape (array vs map at top level, nested structure); (c) output format keys; (d) enum values; (e) substrate paths invoked. Test-affordance CLI flag names per §2.X (existing flag-invention discipline) are exempt — they are recognized as test-time invocation surface, not feature surface.

**Pre-promotion gate.** Before any pending feature transitions to `evals/specs/` (via `probe-feature` or `promote-pending`), the operator runs `rubric/detectors/audit-pending-spec-fidelity.sh --pending <path> --arch docs/architecture-v1.9.md --section <§X>`. The script extracts vocabulary candidates from pending specs and reports any not appearing in the architecture section. Output (per discrepancy): `unknown_vocab=<word> spec=<file>:<line>`. Exit 0 only when zero unknown vocabulary remains.

**Resolution options for discrepancies.** (1) Rewrite the pending spec to use arch-spec'd vocabulary. (2) Amend the architecture section to formally include the vocabulary (requires a separate architecture-amendment CL, not bundled with substrate work). (3) Move the spec to `evals/pending/_misfiled/` with a one-line note in the parent folder's `MISFILED.md` explaining why.

**Origin.** This contract codifies the failure mode discovered in CL-273 where 8 of 10 `CC/2-6-standards-source/` pending specs used an invented map-shape with fields `{publisher, license, last_verified, archive_url, etag, derivative_rules}` while §2.6 specifies array-shape with `{id, name, url, tier, applies_to, fetch_frequency}` (operator-facing) plus a defined plugin-internal field list. The folder name passed all existing fidelity audits (CLAUDE.md Step 0, Step 2 architecture fidelity, drift-mechanism catalog items 1–5) because those operate at folder-ID granularity. The drift sat inside spec bodies and would have shipped invented behavior under an arch-named feature. See `docs/memory/feedback-pending-spec-content-fidelity.md` for the worked example and CLAUDE.md drift mechanism #6.

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
- **P-10** Runtime model router (v1.10 amendment — see §24) `prompts/router.yaml` declares per-task-class tier defaults (`fast` → haiku, `balanced` → sonnet, `deep` → opus) and per-prompt-id overrides; runtime resolver `prompts/router.sh` consulted by every §2.3 subagent at invocation time; overrides static `model:` frontmatter when router-resolved tier differs (router decision logged with both values for §2.8 provenance manifest `models_used` block). H-1 token-cost reporting and H-12 cost rollup break down by tier in addition to model. P-4 model-rationale detector extended to verify the router decision matches the agent's `model_rationale` claim (mismatch → suggestion-level finding with the router-resolved tier as the suggested fix). Router policy is operator-editable; `prompts/router.yaml` follows §2.14 dry-run when changed via `/router-set <task-class> <tier>`.

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
- **H-12** Continuous cost telemetry rollup (v1.9.1 amendment — see §23): `cost-rollup/daily/<YYYY-MM-DD>.json` and `cost-rollup/weekly/<YYYY-Www>.json` aggregate H-1 per-call telemetry by skill, subagent, rule, profile, model; `/cost-report [--window=<period>] [--by=<dimension>] [--format=<text|json|tui>]` drill-down command; per-rule cost regression detector `rubric/detectors/rule-cost-regression.sh` flags rules whose tokens-per-check exceeds 2× their 30-day median (severity: warn); per-CL cost summary appears in `/audit-pack` Decision Trail section (tokens_in/out + monetary_estimate_usd per session_id); rollup honors §2.17 freshness state (cached rollups marked stale after profile-snapshot change). Privacy: local-only per Q-6; no upload.

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
- **O-12** Application scaffolds (v1.10 amendment — see §24) `scaffolds/<scaffold-id>/` ships four greenfield starters: `next-saas` (Next.js + RSC + Stripe billing + auth shell), `node-api` (Fastify + zod schema-validation + structured logging per N-4), `python-fastapi` (FastAPI + Pydantic + pytest), `react-spa` (Vite + React + Vitest). `/scaffold <id> <target-dir> [--profile <name>]` writes a fully-formed project starter with the appropriate profile pre-set (e.g., `next-saas` → `react.yaml` + W-9 UI regression pinner enabled; `node-api` → `node.yaml`; `python-fastapi` → `lite.yaml` + Python detectors enabled; `react-spa` → `react.yaml`). Each scaffold's `package.json` / `pyproject.toml` is pinned to a known-good toolchain version. Scaffolds include a baseline `evals/specs/` aligned with the chosen profile so the active suite is non-empty from minute one. Distinct from R-4 / T-4 / templates/ (config templates for existing projects); O-12 is greenfield. Scaffolds are operator-extensible: `_operator/scaffolds/<my-org>-<scaffold-id>/` per §2.22 cascade. Listed in §2.14 dry-run subjects.

## §14. Phase X — Execution Surfaces

- **X-1** GitHub Actions adapter `.github/workflows/rubric-check.yml`: reads `lock.json.profile_snapshot_hash`; runs runner against PR diff; uploads SARIF (E-9) to GitHub Code Scanning; comments findings with rule IDs and remediation links; `--format github-actions` workflow commands; pre-flight standards/PR/compliance freshness check for regulated/financial/government profiles.
- **X-2** GitLab CI adapter `ci/.gitlab-ci.template.yml`: `--format checkstyle`; MR comments via gitlab-cli.
- **X-3** pre-commit framework adapter `ci/pre-commit-hooks.yaml`: same detectors as Claude Code PreToolUse + CI; `--format markdown`.
- **X-4** Local LLM fallback `skills/local-llm/SKILL.md`: Ollama/llama.cpp/LM Studio; cheap-operation routing (L-3 triage, L-6 affiliation parsing, L-16 issue-label filtering); ~30-50% baseline daily token cost reduction.
- **X-5** Visualization layer `tui/`: `/space-report --tui`, `/coverage --tui`, `/audit-pack --tui` interactive views (charm.sh-style); markdown remains default.
- **X-6** IDE rules export adapter (v1.9.1 amendment — see §23) `skills/ide-rules-export/SKILL.md` + `/export-rules <ide> [--profile <name>] [--include <source-namespace>] [--exclude <source-namespace>] [--out <dir>]`: emits read-only consumable artifacts for non-Claude-Code IDEs from active profile + resolved standards source folders (G-1 directory). Targets: `cursor` (`.cursorrules` + per-rule prompts at `.cursor/rules/<rule-id>.md`), `vscode-copilot` (`.github/copilot-instructions.md` + `.github/prompts/<rule-id>.md`), `continue` (`config.json` rules section), `aider` (`.aider.conf.yml` + `CONVENTIONS.md`), `windsurf` (`.windsurfrules`). Export is strictly one-way; no rules flow back into TDD Pro from these surfaces, because the architectural moat — provenance per §2.1, control mapping per §2.9, grounded-standards citation — cannot be reconstructed from systems that do not produce it. Output stamped with `profile_snapshot_hash` + `exported_at` + `tdd_pro_version` in artifact header comment; stale stamps emit `/doctor` warning (rebuild recommended after profile or rule changes). Freshness gate per §2.17 applies; export refuses on stale standards unless `--skip-fresh` (logged to C-4). Listed in §2.14 dry-run subjects.
- **X-7** Installable Claude Code hooks bundle (v1.9.1 amendment — see §23) `skills/install-hooks/SKILL.md` + `/install-hooks [--scope user|project] [--include <component>...] [--dry-run]`: writes packaged hooks + slash commands + agents + detectors to target `settings.json` (user scope: `~/.claude/settings.json`; project scope: `.claude/settings.json`) with explicit uninstall metadata block `{ tdd_pro_installed_at, tdd_pro_components: [...], tdd_pro_version, tdd_pro_signature }`; refuses install when target `settings.json` already contains conflicting hook scripts unless `--force` (logged to C-4 audit log with conflict diff). Idempotent: re-running with no version change is a no-op; version change runs the appropriate `migrations/<from>-to-<to>.sh` per O-3. Install summary surfaces: hooks installed (with absolute paths), slash commands registered, agents added, permissions requested, detectors registered. `/uninstall-cleanup` (O-3) honors the metadata block to restore prior state; never auto-deletes audit-log or evidence directories per O-3 invariant. Listed in §2.14 dry-run subjects.
- **X-8** Language Server Protocol surface (v1.10 amendment — see §24) `lsp/tdd-pro-lsp/` ships a TDD-Pro LSP server (`tdd-pro-lsp` binary) plus a thin VS Code extension (`vscode-tdd-pro/`) as packaging layer; Cursor and any LSP-compliant editor consume directly via standard LSP protocol. Server emits per-rule diagnostics as the developer types, sourced from the same aggregator (G-5) that powers `runner.sh` and CI surfaces — identical findings, same exit-code-equivalent severities, same `messageId` (E-13). Code-action provider exposes E-4 auto-fix and E-5 inline-suppression-with-justification as quick-fixes. Hover provider shows `source_file` (G-1), `docs_url` (E-8), and provenance trail (§2.1). Server reads active profile + freshness gate per §2.17; degrades to warn-only on stale standards. Closes the inline-editor agent gap (LSP is the missing surface alongside X-1 CI, X-3 pre-commit, X-5 TUI). Listed in §2.14 dry-run subjects for `--print-diagnostics` mode.
- **X-9** Cloud devcontainer surface (v1.10 amendment — see §24) `.devcontainer/devcontainer.json` shipped at plugin root: pre-installed hooks per X-7, pre-installed LSP per X-8, pre-resolved profile per active `userConfig.profile`, pre-fetched standards / PR-corpus / compliance per S-13 / L-19 / C-15 (one-time at container build), pre-built rule cache per E-12. Codespaces-ready and Dev Containers-compatible. Identical toolchain runs locally and in Codespaces — no surface-specific behavior. Cloud-cost note in `/doctor`: standards/PR/compliance fetchers honor S-2 / L-2 / C-15 daily-fresh contract from inside the container (i.e., per-container daily refresh, not per-host). Mobile / remote-IDE workflows pass through this surface.

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
- **W-7** `/spec <feature-description>` writes failing tests from feature description (TDD red phase): skill `skills/spec/SKILL.md` reads (a) feature description from W-1 ADR or operator argument, (b) active profile's resolved standards source-folder set per §2.5 `extends:`, (c) applicable compliance controls per §2.9 `controls:` for active frameworks, (d) §2.4 eval spec schema; emits one `<feature-id>.test.<ext>` per testable contract; refuses to emit when active suite would already cover the contract (no duplicate tests); refuses to emit when feature description grounding lookup returns no relevant standards (declines per S-8 grounded-answer pattern); spec-writer subagent `agents/spec-writer.md` (sonnet, prompt_id `spec-writer`, prompt_version per §2.10) cites each emitted test to `source_file` (G phase) + `docs_url` (E-8); written tests categorized per §2.4 enum (`react|node|types|...`); commits emitted tests with `Test-Driven-By: <feature-id>` trailer; tests are red on commit (CI failure surfaces the red state explicitly).
- **W-8** `/feature` semantics + TDD-Guard: skill `skills/feature/SKILL.md` reads the failing tests written by W-7 from the active suite + the active profile's resolved standards source-folder set; generates the implementation that turns red tests green; TDD-Guard hook `hooks/scripts/tdd-guard.sh` (PreToolUse on commit) refuses commit when (a) any test added in the same feature scope is still red, (b) implementation introduced regressions to any previously-green spec in the active suite, (c) implementation touches paths outside the feature scope declared by W-7's emitted tests (scope drift); emits per-commit token telemetry to F-2; logs implementation completion to W-3 workflow state machine as `feature_complete: true`; `--allow-red-test` operator bypass logged to C-4 audit log per §2.17 live-freshness contract pattern; refuses operation when standards source-folder freshness gate fails per §2.17.
- **W-9** UI feature DOM regression pin: subagent `agents/ui-regression-pinner.md` (sonnet, prompt_id `ui-regression-pinner`) fires PostToolUse after `/feature` completes when commit diff touches UI paths (`src/components/**`, `app/**`, `pages/**`, `src/routes/**`, framework-detected per active profile's `applies_to: [react|...]`); generates Playwright DOM-based regression tests using `playwright.config.ts` template from R-4; tests pin click-state, navigation, rendered output, accessible-name (per WCAG-2.2 standards source folder); written tests added to active regression suite at `tests/e2e/<feature-id>.spec.ts` and join the suite immediately so future commits that break rendered UI fail the suite; refuses to emit when active suite already covers the rendered behavior (no duplicate DOM tests); `/feature --skip-ui-pin` operator bypass logged to C-4 audit log; UI-regression test failures gate the W-2 push-timing recommendation.
- **W-10** Concurrent CL gate (v1.9.1 amendment — see §23) `skills/concurrent-cl/SKILL.md` + `hooks/scripts/concurrent-cl-gate.sh` (PreToolUse on `/spec`, `/feature`, and `/architect`): enforces §2.23 by reading active CL envelopes from `.claude-tdd-pro/active-sessions/<session_id>.json` (one envelope per running CL — created on CL start, removed on CL completion or abort); rejects the new CL when overlap is detected on any of §2.23 (a)-(e), printing the offending resource (phase ID / lock section / state subsection / source-folder file / branch) and the holding `session_id`; logs accepted concurrent starts to C-4 audit log with both `session_id` envelopes referenced. Companion command `/cl-status [--format=<text|json|tui>]` lists running CLs and their held resources. Concurrency is opt-in: default sequential per §20; activated via `userConfig.allow_concurrent_cls: true` OR per-invocation `--concurrent` flag (on `/spec`, `/feature`, `/architect`). W-3 workflow state machine is extended to manage N parallel `session_id` envelopes within a single `workflow-state.json` (each envelope per §2.15); H-3 sectioned locks per-session. No three-way-merge semantics — overlap is rejection, not merge. Listed in §2.14 dry-run subjects.
- **W-11** Parallel subagent orchestrator (v1.10 amendment — see §24) `skills/parallel-subagents/SKILL.md` + coordinator subagent `agents/parallel-coordinator.md` (sonnet, prompt_id `parallel-coordinator`): orchestrates multiple §2.3 subagents within a single CL concurrently. Distinct from W-10 (W-10 is CL-level concurrency; W-11 is within-CL agent-level parallelism). Per-profile parallel-budget config `userConfig.max_parallel_subagents: <N>` (default 1 = sequential; opt-in N≥2). §2.7 sectioned-lock integration: concurrent subagents claiming overlapping lock sections (e.g., two reviewers both wanting `rubric` write) serialize via lock acquisition; non-overlapping subagents run in parallel. Per-subagent token-cost telemetry rolls into H-12 with `subagent_id` tag preserved. Coordinator emits a single consolidated finding set to W-3 workflow state (deduplication: by `rule_id + file + line`). Refuses parallel execution when total estimated tokens exceed `userConfig.parallel_budget_tokens: <N>` (default unbounded; operator sets per profile).
- **W-12** Conversational PR review subagent (v1.10 amendment — see §24) `agents/pr-review-conversational.md` (sonnet, prompt_id `pr-review-conversational`) extends C-11 review-compliance and substrate `pr-self-reviewer.md` with a multi-turn follow-up mode: reviewer (human or another agent) asks "why was X changed?" / "what about case Y?" / "show me where Z is tested" and the subagent answers grounded in the AI Provenance Manifest (§2.8), Decision Trail (W-4), eval datasets (P-2), and the active test suite. Refuses to answer ungrounded; cites every claim to a manifest field, ADR-id, eval spec id, or test path. Conversation log writes to `.claude-tdd-pro/pr-reviews/<pr-sha>/conversation.jsonl` for audit (C-4 chain inclusion). No memory across PRs by default; opt-in cross-PR memory via `userConfig.pr_review_cross_pr_memory: true`. Token cost per turn telemetered to H-1 / H-12.

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

**v1.9.1 amendment deltas (§23):** +2 contracts (§2.23 concurrent CL, §2.24 portable audit-pack format), +H-12 (cost rollup), +X-6 (IDE rules export), +X-7 (installable hooks bundle), +W-10 (concurrent CL gate). +6 commands (`/cost-report`, `/export-rules`, `/install-hooks`, `/cl-status`, plus `--concurrent` flag forms on `/spec`/`/feature`/`/architect`), +3 skills (`ide-rules-export`, `install-hooks`, `concurrent-cl`), +1 hook (`concurrent-cl-gate.sh`), +1 detector (`rule-cost-regression.sh`), +1 schema (`compliance/audit-pack-schema.json`), +trees: `compliance/audit-packs/`, `cost-rollup/{daily,weekly}/`, `.claude-tdd-pro/active-sessions/`. Estimated +30 evals across the new IDs.

**v1.10 amendment deltas (§24):** +X-8 (LSP surface), +X-9 (cloud devcontainer surface), +P-10 (runtime model router), +W-11 (parallel subagent orchestrator), +W-12 (conversational PR review subagent), +O-12 (application scaffolds). +5 commands (`/scaffold`, `/router-set`, plus LSP `--print-diagnostics` mode, parallel-subagents skill invocation, conversational reviewer trigger), +3 subagents (`parallel-coordinator`, `pr-review-conversational`, plus the X-8 LSP server itself is not a subagent but a runtime), +3 skills (`parallel-subagents`, scaffold runner, lsp-bootstrap), +1 binary (`tdd-pro-lsp`), +1 VS Code extension (`vscode-tdd-pro/`), +1 detector extension (P-4 router-mismatch surfacing), +trees: `lsp/tdd-pro-lsp/`, `vscode-tdd-pro/`, `.devcontainer/`, `prompts/router.yaml`, `scaffolds/{next-saas,node-api,python-fastapi,react-spa}/`, `.claude-tdd-pro/pr-reviews/<pr-sha>/`. Estimated +50 evals across the new IDs.

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
| 21.5 | W-7 | 9.76 | /spec writes failing tests from feature description |
| 22 | W-2, W-3, W-8 | 9.78 | Git workflow + state machine + /feature TDD-Guard |
| 22.5 | W-9 | 9.79 | UI feature DOM regression pin |
| 23 | W-4, W-5, W-6 | 9.8 | Decision provenance trail |
| 23.5 | S-19 closed-loop validation | 9.8 | Standards loop end-to-end |
| 24 | L-24 closed-loop validation | 9.82 | PR-corpus loop end-to-end |
| 24.5 | C-21 closed-loop validation | 9.83 | Compliance loop end-to-end |
| 25 | E-17 closed-loop validation | 9.84 | Rule engine ESLint-parity end-to-end |
| 25.5 | G-14 closed-loop validation | 9.85 | Source-folder loop end-to-end |
| 26 | H-12 + §2.24 (portable audit-pack schema) + C-10 emit amendment | 9.86 | Cost rollup + audit-pack becomes public interchange artifact |
| 26.5 | X-6 (IDE rules export) | 9.87 | Discipline plugs into Cursor/Copilot/Continue/Aider/Windsurf one-way |
| 27 | X-7 (installable hooks bundle) + O-3 amendment for X-7 uninstall metadata | 9.88 | Hooks-first packaging — TDD Pro installs as Claude Code artifact |
| 27.5 | §2.23 (concurrent CL contract) + W-10 (concurrent CL gate) | 9.9 | Disjoint CLs run in parallel; audit trail remains coherent |
| 28 | X-8 (LSP surface) + VS Code packaging | 9.91 | Inline-editor agent surface — Cursor/VS Code consume via standard LSP |
| 28.5 | P-10 (runtime model router) | 9.915 | Per-task-class tier routing with H-1/H-12 cost breakdown by tier |
| 29 | W-11 (parallel subagent orchestrator) + W-12 (conversational PR reviewer) | 9.92 | Within-CL agent parallelism + follow-up-capable grounded PR review |
| 29.5 | X-9 (cloud devcontainer surface) | 9.925 | Codespaces / Dev Containers parity with local toolchain |
| 30 | O-12 (application scaffolds) | 9.93 | Greenfield starters with profile pre-set — non-empty active suite from minute one |

**Total CL count:** ~268 (v1.9) + ~12 (v1.9.1 §23) + ~18 (v1.10 §24). **Effort:** ~23–28 weeks part-time / ~12–14 weeks full-time for v1.9; +~2 weeks for v1.9.1; +~3 weeks for v1.10.

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
- Every S-1 through S-19, C-1 through C-21, L-1 through L-24, F-1 through F-6, P-1 through P-10, R/N/T full coverage, Q-1 through Q-9, H-1 through H-12, O-0 through O-12, X-1 through X-9, W-1 through W-12 acceptance criterion met (upper bounds include v1.9.1 §23 and v1.10 §24 amendments)
- W-7 `/spec` writes failing tests from a feature description, grounded in the active profile's standards source folders, and refuses to emit when no relevant grounding standard is available
- W-8 `/feature` + TDD-Guard refuses commit when any feature-scope test is still red, when implementation introduces a regression to the previously-green active suite, or when implementation drifts outside the test scope
- W-9 UI regression pinner automatically generates Playwright DOM-based regression tests for any commit touching UI paths under the active profile's `applies_to` framework; these tests join the active suite and gate future commits that break rendered UI behavior
- README v1.9 documents the operator workflow end-to-end
- Symmetric documentation: STANDARDS-URLS.yaml + PR-SOURCES.yaml + COMPLIANCE-URLS.yaml all prominently referenced in `/doctor`, `/init-guardrails`, README, getting-started; `generated-code-quality-standards/` directory tree referenced as discoverability entry point
- **v1.9.1 amendments delivered (§23):** H-12 writes `cost-rollup/daily/<YYYY-MM-DD>.json` and `cost-rollup/weekly/<YYYY-Www>.json` aggregates plus per-CL cost in `/audit-pack` Decision Trail; `/audit-pack --emit json|markdown|html|tarball` produces bundles validating against `compliance/audit-pack-schema.json` with byte-identical reproducibility on identical inputs; `/export-rules <ide>` emits valid one-way artifacts for `cursor`, `vscode-copilot`, `continue`, `aider`, `windsurf` and refuses on stale standards; `/install-hooks [--scope user|project]` writes scoped `settings.json` entries with full uninstall metadata and is honored by `/uninstall-cleanup`; `/cl-status` lists active CL envelopes; two CLs with disjoint phase/lock/state/source-folder/branch ownership (verified by §2.23 contract checker) complete `/spec`→`/feature` concurrently and merge with a coherent C-4 audit chain; W-10 rejects overlapping CLs at PreToolUse with offending-resource explanation
- **v1.10 amendments delivered (§24):** X-8 LSP server emits per-rule diagnostics on edit in Cursor and VS Code, sourced from the same G-5 aggregator that powers CI; X-9 `.devcontainer/devcontainer.json` boots a Codespaces session with hooks + LSP + standards/PR/compliance pre-fetched; P-10 `prompts/router.yaml` resolves task-class → tier at subagent invocation and H-1 / H-12 break down cost by tier; W-11 parallel coordinator runs N subagents within a single CL with §2.7 lock serialization on overlap; W-12 conversational reviewer answers PR follow-up questions citing §2.8 manifest / W-4 ADR / P-2 eval / active suite — refuses ungrounded claims; `/scaffold {next-saas|node-api|python-fastapi|react-spa} <target-dir>` writes a greenfield project with the appropriate profile and a non-empty `evals/specs/` baseline

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

## §23. v1.9.1 — Optimization amendments

Additive amendments addressing five observed gaps versus the 2026 dev-tools landscape (Cursor, GitHub Copilot, Continue, Aider, Windsurf, Codespaces agent mode, parallel agent execution): (1) single-threaded CL workflow blocks feature-level parallelism even when CLs are disjoint; (2) the discipline layer lacks an installable surface outside this repo (clone-only); (3) `/audit-pack` is bundled but not a schema'd public interchange format; (4) discipline does not plug into peer IDEs whose user base is materially larger than this plugin's; (5) cost telemetry exists per-call (H-1) but lacks aggregation surface for cost regression detection. Each amendment is non-regressive: every existing F/E/G/S/C/P/R/N/T/Q/H/L/O/X/W feature retains its v1.9 semantics; every §2.1-§2.22 contract retains its v1.9 obligations.

**Authoritative IDs introduced by v1.9.1:** H-12 (Phase H, §11), W-10 (Phase W, §15), X-6 + X-7 (Phase X, §14), §2.23 + §2.24 (cross-cutting contracts, §2). All IDs are extractable verbatim from this document for use in CL plans, folder names, spec labels, and commit messages per the architecture-fidelity discipline in `CLAUDE.md`.

### §23.1 Why these gaps are architecture work, not execution work

(a) Concurrent CL execution requires a contract on workflow-state, lock sections, source-folder ownership, and branch ownership — these are architectural invariants, not implementation detail. Encoded as §2.23. (b) Portable audit-pack is a schema'd interchange format with reproducibility guarantees (canonical JSON, pinned timestamps) — schema and reproducibility are architectural. Encoded as §2.24. (c) IDE rules export defines what slice of discipline may leave the TDD-Pro surface and under what one-way constraint — boundary decision is architectural. Encoded as X-6. (d) Installable hooks bundle defines the uninstall contract and refuses-on-conflict semantics — reversibility is architectural. Encoded as X-7. (e) Cost rollup defines the aggregation surface (daily, weekly, by-skill/subagent/rule/profile/model) and regression-detection threshold (2× median) — aggregation semantics are architectural. Encoded as H-12.

### §23.2 Boundary discipline preserved

These amendments do NOT relax any v1.9 invariant. In particular:

- **TDD-Guard (W-8) remains the only path from red test to green code.** W-10 concurrent-CL gate does not bypass TDD-Guard; concurrent CLs each pass through their own W-8 enforcement.
- **`/audit-pack` portable format (§2.24) is a serialization of existing C-10 content.** No new data collected, no existing data dropped. Schema versioning (`bundle_schema_version`) ensures forward compatibility.
- **IDE rules export (X-6) is one-way.** Rules authored in Cursor/Continue/etc. do NOT flow back into TDD Pro. The architectural moat — provenance per §2.1, control mapping per §2.9, grounded-standards citation per S-8 — cannot be reconstructed from systems that do not produce it. Importing back would degrade provenance to "unknown" — explicitly disallowed.
- **Installable hooks (X-7) honor O-3 uninstall semantics.** Never auto-delete audit-log or evidence directories. Refuses conflict installs unless `--force` (logged).
- **Concurrent CL execution (§2.23) requires disjoint ownership across all five dimensions.** Overlapping CLs are rejected, not merged. No three-way-merge semantics — that would require conflict resolution policy outside the architecture's scope.
- **Cost rollup (H-12) honors Q-6 privacy posture.** Local-only; no upload; redacted on `/space-export`.

### §23.3 Out of scope for §23

- Pivoting any portion of the workflow to live inside Cursor / VS Code / Continue / Aider / Windsurf. Those IDEs are export targets only via X-6.
- Cross-CL conflict resolution beyond rejection. If two CLs want overlapping resources, they serialize. No automatic merge.
- Cost-attribution for non-Anthropic models beyond what H-1 already collects. H-12 rollup measures what H-1 measures; X-4 local-LLM calls reported with `monetary_estimate_usd: 0` and `model: <local-model-id>`.
- Bidirectional sync with IDE-native rule systems. Cursor's `.cursorrules` evolution, Copilot custom-instruction changes, etc. do not propagate back. Operators wanting roundtrip must reauthor in TDD Pro.
- Cloud-hosted execution of CLs. §2.23 concurrency is local-multi-session; remote orchestration is a separate concern.

### §23.4 Cumulative ranking impact

| Concern | v1.9 score | v1.9.1 score | Mechanism |
|---|---|---|---|
| Workflow concurrency | 6/10 (serial-by-design) | 8.5/10 (disjoint parallel + audit-coherent) | §2.23 + W-10 |
| Distribution surface | 6/10 (clone-only) | 9/10 (installable hooks bundle + IDE rules export) | X-6 + X-7 |
| Audit-pack interchange | 7/10 (bundled non-schema'd) | 9/10 (schema'd, reproducible, multi-format) | §2.24 + C-10 emit |
| Cost observability | 7/10 (per-call only) | 8.5/10 (rollup + regression detector + per-CL summary) | H-12 |
| **Capability ranking (overall)** | **9.85/10** | **9.9/10** | Cumulative |

Build confidence preserved at 9/10 via canonical staged path; v1.9.1 amendments land in weeks 26–27.5 per §20.

### §23.5 Cross-references to existing architecture

- §1 (thirteen-layer model): no change; the §23 amendments slot into existing layers (H, W, X) and cross-cutting contracts (§2). No new layer.
- §2.7 (lock file sectioned advisory locks): §2.23 (e) cites disjoint lock-section ownership.
- §2.14 (dry-run contract): X-6 `/export-rules`, X-7 `/install-hooks`, W-10 `/cl-status` listed as dry-run subjects.
- §2.15 (workflow state contract): §2.23 (b) extends `workflow-state.json` to manage N parallel `session_id` envelopes; W-10 enforces.
- §2.17 (live freshness contract): X-6 applies freshness gate to export; H-12 rollup honors freshness state.
- C-4 (audit log): C-4 Merkle chain absorbs concurrent CL entries via per-entry hash-chaining; per-section checkpoints unaffected.
- C-10 (`/audit-pack`): extended to emit per §2.24 portable format.
- H-1 (token-cost transparency): H-12 aggregates H-1 telemetry into daily/weekly rollups.
- O-3 (uninstall-cleanup): honors X-7 install metadata block for reversibility.
- Q-6 (privacy posture): H-12 rollups are local-only; X-6 export contains no telemetry.

### §23.6 Anti-drift note for future CLs touching §23

Per `CLAUDE.md`, every CL must extract literal feature IDs and §2.X labels from this document. The v1.9.1 IDs (H-12, W-10, X-6, X-7, §2.23, §2.24) are canonical and must be used verbatim — never paraphrased as "cost telemetry feature," "parallel-CL feature," "Cursor export feature," etc. Folder names under `evals/pending/` for these amendments must be exactly `evals/pending/h/h-12-continuous-cost-telemetry-rollup/`, `evals/pending/w/w-10-concurrent-cl-gate/`, `evals/pending/x/x-6-ide-rules-export/`, `evals/pending/x/x-7-installable-hooks-bundle/`, `evals/pending/cross-cutting/2-23-concurrent-cl-execution-contract/`, `evals/pending/cross-cutting/2-24-portable-audit-pack-format/`. Test-affordance flag invention discipline (CLAUDE.md) applies as usual for these features.

### §23.7 Substrate reconciliation status (drift-audit findings, 2026-05-14)

Two v1.9.1 amendments and one v1.9 amendment (W-8) have partial pre-existing substrate implementations that pre-date this document. Acknowledged here rather than papered over; reconciliation is part of the future implementation CL for each feature, not a separate work item.

- **X-6 (IDE rules export) — substrate exists.** `commands/sync-rules.md` substrate already generates Cursor `.cursor/rules/`, GitHub Copilot `.github/copilot-instructions.md`, Aider `.aider.conf.yml`, Windsurf `.windsurfrules`, and AGENTS.md from `CONVENTIONS.md` + `QUALITY-BAR.md`. This pre-dates the v1.9 source-folder model (G-1). The X-6 implementation CL must: (i) decide between renaming `/sync-rules` → `/export-rules` (consistent with §14 X-6 wording) and keeping both with documented distinction (substrate convention-driven export vs G-1 source-folder-driven export); (ii) re-source the export from the resolved profile + `generated-code-quality-standards/<namespace>/*.yaml` set rather than from `CONVENTIONS.md`/`QUALITY-BAR.md` (so the moat — provenance per §2.1, controls per §2.9, grounded standards — actually rides the export); (iii) add the `profile_snapshot_hash` + `exported_at` + `tdd_pro_version` artifact stamps required by §14; (iv) add the freshness gate per §2.17; (v) add the `continue` target (currently absent from substrate's five targets). Substrate is evidence that the demand exists and the export plumbing is tractable; X-6 specifies the canonical-architecture form.

- **W-8 (TDD-Guard) — substrate is active, not a stub.** `hooks/scripts/tdd-guard.sh` is a working PreToolUse hook implementing a path-mirror-based last-test-run check with allow-list (test files, config, docs, first-time creation) and disable surfaces (`.claude-tdd-pro/tdd-guard.disabled`, `CLAUDE_TDD_PRO_GUARD=off`). The architecture W-8 schema is materially different: (a) red-test refusal scoped to the feature, (b) regression refusal against the previously-green active suite, (c) scope-drift refusal based on W-7-emitted-test paths, (d) `feature_complete: true` emission to W-3 workflow state, (e) `--allow-red-test` operator bypass logged to C-4. The W-8 implementation CL must reconcile rather than overwrite: preserve substrate's path-mirror heuristic as a fallback when no W-7 scope is declared, layer the W-7-aware refusals on top, and migrate the disable surfaces to the §2.14 dry-run / §2.17 freshness contract pattern.

- **W-3 / §2.15 (workflow-state.json) — no substrate envelope.** `tdd-guard.sh` currently reads `.claude-tdd-pro/last-test-run.json`; W-3 expects `.claude-tdd-pro/workflow-state.json`. Reconciliation: keep `last-test-run.json` as a session-local cache; add `workflow-state.json` as the §2.15-canonical envelope; bridge by W-8's hook reading both.

- **No other v1.9.1 amendment has substrate.** H-12 (cost rollup), W-10 (concurrent CL gate), X-7 (installable hooks bundle), §2.23 (concurrent CL contract), §2.24 (portable audit-pack format) are entirely unimplemented at substrate level — their implementation CLs build from scratch.

- **No substrate is mislabeled drift.** All shipped commands, skills, subagents, hooks, detectors either (a) trace to a literal architecture feature ID, (b) extend §2.X contracts in advance of their phase landing (`validate-rubric-rule.sh` for §2.1, `validate-source-file.sh` for §2.21 + G-6), or (c) are pre-architecture substrate documented by §23.8 below. No invented Phase-N decomposition of the kind CL-08/09/10 introduced.

### §23.8 Substrate vs architecture phase-model glossary

Two phase models coexist in this repository. They are NOT equivalent.

**Substrate phase model (pre-v1.9, numeric):**

| Substrate phase | Surface | Meaning |
|---|---|---|
| Phase 0 | `skills/phase-0-snapshot/`, `commands/snapshot.md` | Snapshot an existing untested codebase before any cleanup; tag pre-remediation; write top-level README + CLAUDE.md + REMEDIATION.md |
| Phase 1 | `skills/phase-1-guardrails/`, `commands/init-guardrails.md` | Install bootstrap toolchain (lint / format / pre-commit / test framework) so subsequent changes can't make things worse |

**Architecture phase model (v1.9 / v1.9.1, letter-coded — see §3-§17 of this document):**

| Phase | Meaning |
|---|---|
| F | Foundation (§3) — postmortem, measure-rubric, agent-verify, incident, drift |
| E | ESLint-Parity Rule Engine (§16) — E-1..E-17 |
| G | Generated Quality-Standards Directory (§17) — G-1..G-14 |
| S | Standards Ingestion & Reconciliation (§4) — S-1..S-19 |
| C | Compliance, Audit & Provenance (§5) — C-1..C-21 |
| P | Prompt Engineering & AI Component Lifecycle (§6) — P-1..P-9 |
| R / N / T | React / Node / Types coverage (§7-§9) |
| Q | SPACE Productivity Measurement (§10) — Q-1..Q-9 |
| H | Hardening (§11) — H-1..H-12 |
| L | Public Engineering Corpus Learning (§12) — L-1..L-24 |
| O | Operational Readiness (§13) — O-0..O-11 |
| X | Execution Surfaces (§14) — X-1..X-7 |
| W | Workflow Orchestration (§15) — W-1..W-10 |

**Interaction between the two:**

- Substrate Phase 0 / Phase 1 is **pre-F bootstrap discipline** for cleaning up an existing untested codebase. It is NOT a prerequisite to or a subset of architecture Phase F. A repo using this plugin may have *never* needed substrate Phase 0/1 (if greenfield) and still uses every architecture phase.
- Architecture Phase F/E/G/... is the **building order of the TDD-Pro plugin itself** (§20 execution order), regardless of whether the host repo went through Phase 0/1.
- When the word "phase" appears without a qualifier in this document, it means the architecture letter-coded model. When the substrate's `skills/phase-0-snapshot/` or `commands/snapshot.md` say "Phase 0," they mean the numeric substrate model.

**Resolution path (non-urgent; retire in v2.0 or sooner):**

The numeric substrate naming is acceptable while substrate predates F. Once F-1..F-6 + O-0..O-1 implement (week 1-4 per §20), evaluate whether substrate Phase 0/1 should be: (a) renamed to architecture-neutral names (`bootstrap-snapshot`, `bootstrap-guardrails`) to remove the terminology collision; (b) retired into F-equivalent skills with provenance preserved in `_meta/migration-from-substrate-phase-numbers.md`; or (c) kept verbatim with this glossary as the sole reconciliation document. Decision belongs to the F-phase implementation CL, not §23.

## §24. v1.10 — Surface expansion amendments

Additive amendments that expand the **execution-surface and workflow-surface** reach of the plugin: where v1.9.1 (§23) addressed concurrency / packaging / interchange / cost-rollup, v1.10 addresses the inline-editor agent gap (LSP), the cloud-IDE workflow gap (Codespaces), the parallel-subagent gap, the multi-model-tier gap, the conversational PR-review gap, and the greenfield-starter gap. These are six new authoritative feature IDs added to existing phases.

**Authoritative IDs introduced by v1.10:** P-10 (Phase P, §6), O-12 (Phase O, §13), X-8 + X-9 (Phase X, §14), W-11 + W-12 (Phase W, §15). All IDs are extractable verbatim from this document for use in CL plans, folder names, spec labels, and commit messages per `CLAUDE.md`. No collision with v1.9 (§1-§22) or v1.9.1 (§23) IDs.

### §24.1 Why these gaps are architecture work

(a) **LSP surface (X-8)** is architecturally distinct from X-6 (IDE rules export, one-way artifact). X-8 is *runtime diagnostic emission* via the standard LSP protocol — findings appear as the developer types, sourced from the same aggregator that powers CI. X-6 ships static rule files; X-8 ships a live server. Both are valid; the IDE ecosystem needs both. (b) **Cloud devcontainer (X-9)** is the missing execution surface alongside X-1 (GitHub Actions), X-3 (pre-commit), X-5 (TUI) — a fully pre-built container for remote/mobile dev. (c) **Runtime model router (P-10)** moves §2.3 subagent model selection from static frontmatter to a per-task-class runtime decision, integrating with H-1 / H-12 cost telemetry by tier. (d) **Parallel subagent orchestrator (W-11)** is within-CL agent concurrency, complementary to W-10 (cross-CL concurrency); requires §2.7 lock-section coordination. (e) **Conversational PR reviewer (W-12)** turns the existing C-11 review-compliance subagent + substrate review agents into a follow-up-capable conversational surface grounded in §2.8 provenance + W-4 decision trail. (f) **Application scaffolds (O-12)** ships greenfield starters with profile pre-configured — distinct from R-4 / T-4 config templates which target existing projects.

### §24.2 Boundary discipline preserved

These amendments do NOT relax any v1.9 or v1.9.1 invariant:

- **X-8 LSP server emits the same findings as X-1 / X-3 / runner.sh** because it reads through G-5 aggregator. Identical exit-code-equivalent severities, identical `messageId` (E-13), identical fix-action semantics (E-4 auto-fix, E-5 inline suppression). No LSP-only rule semantics.
- **X-9 Codespaces surface uses the same toolchain as local.** No surface-specific behavior; same hooks, same LSP, same freshness gate. Cloud is a host, not a fork.
- **P-10 router overrides subagent `model:` frontmatter** but logs both values (router decision + frontmatter declaration) to §2.8 provenance manifest. P-4 model-rationale detector verifies the agent's rationale matches the router-resolved tier (mismatch surfaces as a suggestion). No silent tier shifts.
- **W-11 parallel subagents serialize on overlapping lock sections (§2.7).** No race conditions; lock acquisition is mandatory, not advisory. Per-subagent token cost preserved with `subagent_id` tag in H-12.
- **W-12 conversational PR reviewer refuses ungrounded answers.** Every claim cites a §2.8 manifest field, an ADR id, an eval spec id, or a test path. Hallucination → "I don't have grounding for that claim" response.
- **O-12 scaffolds pre-configure profile but do not pre-pass active suite.** Greenfield scaffold's `evals/specs/` is non-empty so the active suite has content from minute one, but the host project still has to author its own features through W-7 / W-8 / W-9.
- **W-10 (CL-level concurrency) and W-11 (subagent-level parallelism) are orthogonal.** A single CL with `max_parallel_subagents: 4` runs 4 subagents in parallel; two CLs each with `max_parallel_subagents: 4` (allowed by W-10 §2.23) run up to 8 subagents total, gated by per-profile parallel-budget.

### §24.3 Mapping from external proposal to canonical IDs

A v1.10 proposal originating outside this document used IDs that collide with v1.9.1 §23. Canonical re-IDs:

| External proposal ID | Canonical ID in this document | Reason |
|---|---|---|
| X-6 IDE Language Server | **X-8** | X-6 in this document is IDE rules export per §23 (one-way artifact) — different feature |
| W-10 Parallel agent orchestrator | **W-11** | W-10 in this document is concurrent CL gate per §23 — different scope |
| P-10 Runtime model router | **P-10** (no change) | P-10 was free |
| X-7 Codespaces devcontainer | **X-9** | X-7 in this document is installable hooks bundle per §23 — different feature |
| X-8 Conversational PR reviewer | **W-12** | Moved from X to W: reviewer is a workflow surface (per-PR, multi-turn), not an execution surface |
| W-11 Application scaffolds | **O-12** | Moved from W to O: scaffolds are operational-readiness / lifecycle (`/scaffold`), not workflow orchestration |

This re-ID is non-controversial — the external proposal's *content* is preserved verbatim under canonical IDs; only the numbering changes to avoid collision.

### §24.4 Out of scope for §24

- **A TDD-Pro IDE plugin marketplace.** X-8 LSP server + VS Code extension is the entry surface; broader IDE plugin distribution (JetBrains plugin marketplace, Sublime, etc.) is downstream packaging, not architecture.
- **A managed cloud Codespaces template registry.** X-9 ships a devcontainer.json; hosting / curation of derived templates is a GitHub-side concern.
- **Multi-model arbitration beyond tier selection.** P-10 routes by task-class to a tier (haiku/sonnet/opus); it does NOT do A/B model arbitration within a tier (that remains P-5 `/prompt-ab` territory).
- **Cross-PR memory by default.** W-12 conversational reviewer is per-PR by default; cross-PR memory requires explicit opt-in (`userConfig.pr_review_cross_pr_memory: true`) because cross-PR memory has privacy implications (§Q-6).
- **Non-LSP editor surfaces.** Vim / Emacs / Neovim users consume X-8 via their respective LSP clients (built-in or coc.nvim / lsp-mode); TDD Pro does not ship editor-specific glue beyond the VS Code packaging layer.
- **Scaffold support for languages outside JS/TS/Python.** O-12 ships four scaffolds in JS/TS + Python; Go / Rust / Ruby scaffolds are operator-extensible per §2.22 cascade, not core.

### §24.5 Cumulative ranking impact

| Concern | v1.9.1 score | v1.10 score | Mechanism |
|---|---|---|---|
| Inline-editor agent surface | 4/10 (CI / pre-commit only) | 9/10 (LSP via X-8 + VS Code packaging) | X-8 |
| Cloud / remote dev surface | 6/10 (CI is cloud; local-only otherwise) | 8.5/10 (Codespaces parity) | X-9 |
| Multi-model tier reasoning | 6/10 (static frontmatter + P-4 rationale check) | 8.5/10 (runtime router + tier-cost breakdown + P-4 mismatch detection) | P-10 |
| Within-CL agent parallelism | 5/10 (sequential subagents) | 8/10 (lock-coordinated parallel subagents) | W-11 |
| PR review depth | 7/10 (one-shot reviewer agents) | 8.5/10 (follow-up-capable conversational, grounded refusals) | W-12 |
| Greenfield onboarding | 5/10 (templates target existing projects) | 9/10 (four scaffolds with profile pre-set + active suite non-empty) | O-12 |
| **Capability ranking (overall)** | **9.9/10** | **9.93/10** | Cumulative |

Build confidence preserved at 9/10 via canonical staged path; v1.10 amendments land in weeks 28-30 per §20.

### §24.6 Cross-references to existing architecture

- §2.3 (subagent contract): P-10 router consulted at subagent invocation; W-11 coordinator and W-12 conversational reviewer are §2.3-compliant subagents.
- §2.7 (sectioned advisory locks): W-11 mandatory lock acquisition for overlapping sections.
- §2.8 (AI provenance manifest): P-10 router decision logged in `models_used`; W-12 conversational answers cite manifest fields.
- §2.14 (dry-run contract): X-8 `--print-diagnostics` mode, X-9 `/scaffold` (O-12), P-10 `/router-set`, W-12 conversational refresh — all dry-run subjects.
- §2.17 (live freshness): X-8 LSP degrades to warn-only on stale standards; X-9 container per-container daily refresh.
- E-13 (messageIds for i18n): X-8 LSP emits localized messages via existing E-13 surface.
- H-1 / H-12 (cost telemetry): P-10 reports by tier; W-11 reports per-subagent.
- C-4 (audit log): W-11 coordinator emissions, W-12 conversation logs both chain into C-4.

### §24.7 Anti-drift note for future CLs touching §24

Per `CLAUDE.md`, every CL must extract literal feature IDs and §2.X labels from this document. The v1.10 IDs (X-8, X-9, P-10, W-11, W-12, O-12) are canonical and must be used verbatim — never paraphrased as "the LSP feature," "the Codespaces feature," "the scaffolds thing," etc. Folder names under `evals/pending/` for these amendments must be exactly `evals/pending/x/x-8-language-server-protocol-surface/`, `evals/pending/x/x-9-cloud-devcontainer-surface/`, `evals/pending/p/p-10-runtime-model-router/`, `evals/pending/w/w-11-parallel-subagent-orchestrator/`, `evals/pending/w/w-12-conversational-pr-review-subagent/`, `evals/pending/o/o-12-application-scaffolds/`. Test-affordance flag invention discipline (CLAUDE.md) applies as usual.

**Important — ID-collision lesson:** This block exists in part because an external proposal independently assigned X-6 / W-10 / X-7 / X-8 / W-11 to different features, conflicting with v1.9.1 §23. The defense going forward: every proposal that suggests a new architecture feature MUST first read this document end-to-end and confirm the proposed ID is free. The `next available` cursor at v1.10 is: P-11, X-10, W-13, O-13, H-13, plus any unused IDs in F/E/G/S/C/R/N/T/Q/L (which are unchanged from v1.9 base). Future v1.11+ amendments should grep this file for `^\- \*\*[A-Z]-` to enumerate taken IDs before proposing.

## §25. v1.9.2 — Pending-spec content fidelity amendment

A non-feature, governance-only amendment introduced to close the drift class discovered in CL-273: pending specs in `evals/pending/<phase>/<feature-id>-<descriptive-label>/` whose **folder name** correctly traced to an architecture feature but whose **spec body** asserted behavior using vocabulary (field names, YAML shapes, output keys, enum values) not present in the architecture text for that feature ID. The CL-08/09/10 invented-features drift catalog defended against folder-level deviation; this amendment defends against the analogous deviation hidden inside spec contents.

### §25.1 Scope

This amendment introduces no new architecture *feature* IDs. It adds:

1. A new cross-cutting contract — §2.25 (Pending-spec content fidelity contract) — defining the audited vocabulary surface and the pre-promotion gate.
2. A new substrate detector — `rubric/detectors/audit-pending-spec-fidelity.sh` — that automates discrepancy detection between pending specs and the architecture text.
3. A new memory file — `docs/memory/feedback-pending-spec-content-fidelity.md` — documenting the discovered failure mode with the §2.6 worked example, indexed from `docs/memory/MEMORY.md` and referenced from `CLAUDE.md`.
4. A new step in the per-CL workflow loop — Step 0.5 (spec-content fidelity check) — inserted between the existing Step 0 (architecture extraction) and Step 1 (write tests). When the CL promotes pre-existing pending specs rather than writing new ones, Step 0.5 is the binding gate.
5. A new entry in the CLAUDE.md drift-mechanism catalog — mechanism #6 (Pending-spec invented vocabulary) — with defense pointing back at the substrate detector and the memory file.

### §25.2 Operational semantics

Per `audit-pending-spec-fidelity.sh`:

- **Vocabulary extraction.** Parse each pending spec's `setup` array and `command` string for YAML/JSON key tokens (regex `[a-z][a-z0-9_]*:`), substrate paths (`$CLAUDE_PLUGIN_ROOT/<path>`), and enum-shaped string literals (CLI args, JSON values).
- **Architecture lookup.** Read the architecture section for the feature ID (resolved from the parent folder name `<feature-id>-<label>`). Extract all words appearing in code-spans, fenced blocks, and field-list lines.
- **Comparison.** Vocabulary candidates appearing in spec bodies but NOT in architecture are reported as `unknown_vocab=<token> spec=<filename>:<line>`. CLI flag names matching `--[a-z-]+` are exempt (covered by the existing CLI-flag-invention disclosure).
- **Exit code.** 0 when zero unknowns remain; 1 when discrepancies found (blocks promotion). 2 on usage errors.

### §25.3 Resolution paths for discrepancies

When `audit-pending-spec-fidelity.sh` flags a token, the operator picks one path and disclosures the choice in the next CL's commit body:

1. **Spec rewrite** — change the pending spec to use arch-spec'd vocabulary. Disclosed under "Spec patches in this CL (architecture-fidelity corrections):" — same disclosure surface CL-273 used.
2. **Architecture amendment** — formally amend the architecture to include the vocabulary. Ships as a separate governance CL (like this §25) without substrate. References the spec being unblocked.
3. **Misfiled relocation** — move the spec to `evals/pending/_misfiled/<feature-id>/` with a one-line entry in `evals/pending/_misfiled/MISFILED.md` explaining why. Does not block other specs in the same feature.

Mixing paths within one CL is allowed when motivated; commit body must list each path used.

### §25.4 Cross-references

- §2.25 — the contract.
- CLAUDE.md Step 0.5, drift mechanism #6 — the workflow integration.
- `rubric/detectors/audit-pending-spec-fidelity.sh` — the substrate.
- `docs/memory/feedback-pending-spec-content-fidelity.md` — the discipline document.
- CL-273 — the originating worked example (8/10 CC/2-6-standards-source specs rewritten under path 1 above).

### §25.5 Non-goals

- Does not retroactively audit specs already promoted to `evals/specs/`. Those passed earlier gates and ship behavior the project owns. Re-audit is a separate decision; this amendment is forward-only.
- Does not amend the existing CLI-flag-invention discipline. Flag names remain a separate disclosure surface (test-affordance), with the auditor exempting them as the existing process expects.
- Does not change which features ship in §20 weeks. This amendment is governance-only, not surface expansion.

### §25.6 Anti-drift note for future CLs touching §25

The contract surface is fixed at five artifacts (§2.25 contract, the detector, the memory file, CLAUDE.md Step 0.5, drift catalog item #6). Future CLs that extend the auditor (richer vocabulary extraction, additional architecture sections, exemption rules) ship under this §25 umbrella and amend the detector. Future CLs that change the **workflow shape** (e.g., a new Step 0.6 or a different gating point) require a new amendment section, not an in-place edit of this one — preserving the per-amendment historical record the v1.9.1 and v1.10 sections established.

## §26. v1.11 — Frontend platform & quantifiable productivity amendment

Additive amendments responding to two industry shifts observable by mid-2026: (1) frontier-model commoditization makes the **harness** (context, tools, validation, orchestration around the model) the durable competitive surface — Anthropic, OpenAI, Meta, Microsoft are all publishing on long-running harness patterns; (2) enterprise frontend platforms (Wayfair, Stripe, Airbnb, Shopify) need codified discipline for Next.js + design-system + Storybook workflows, plus quantifiable productivity-uplift telemetry that operators can show to leadership (Wayfair publicly reported ~65% uplift in some areas via Gemini). v1.9..v1.10 cover most of the harness layer; v1.11 closes the frontend-platform-depth gap and the operator-facing productivity-metrics gap.

**Authoritative IDs introduced by v1.11:** R-8 (Phase R, §7), R-9 (Phase R, §7), R-10 (Phase R, §7), O-13 (Phase O, §13), Q-10 (Phase Q, §10), Q-11 (Phase Q, §10), Q-12 (Phase Q, §10), H-13 (Phase H, §11), §2.26 (cross-cutting contracts, §2), §2.27 (cross-cutting contracts, §2). All IDs are extractable verbatim from this document for use in CL plans, folder names, spec labels, and commit messages per `CLAUDE.md`. No collision with v1.9 (§1-§22), v1.9.1 (§23), v1.10 (§24), or v1.9.2 (§25) IDs.

**Standard-form bullets (for `^- \*\*[A-Z]-` grep traversal compatibility with §1-§24):**

- **R-8** Next.js component scaffolder with design-token enforcement (v1.11 amendment — see §26.1(a)) `commands/component-add.sh` per-component generator; refuses to emit code referencing untokenized values; ships matching Storybook story + Vitest skeleton + a11y axe smoke per component.
- **R-9** Design-system token registry (v1.11 amendment — see §26.1(b)) `design-tokens/registry.yaml`: operator-facing schema with `id`, `value`, `contrast_pair`, `deprecated`, `replaced_by`. Frontend analog to S-2 / S-6 / S-16 for standards layer.
- **R-10** Component-API drift detector across PRs (v1.11 amendment — see §26.1(c)) `rubric/detectors/component-api-drift.sh`: walks PR diff; surfaces prop-name / prop-type / return-element-shape changes as "potentially-breaking-for-consumers" finding with deprecated-prop migration suggestion.
- **O-13** Design-token freshness gate (v1.11 amendment — see §26.1(b)) auto-demotes rules referencing deprecated tokens to warn-only until operator upgrades the reference or marks suppression per E-5. Substrate at `rubric/detectors/design-token-freshness.sh`.
- **Q-10** Velocity-uplift dashboard (v1.11 amendment — see §26.1(d)) `commands/velocity-report.sh` per-skill + per-rule cycle-time deltas vs. baseline window.
- **Q-11** AI-assisted PR quality scorecard (v1.11 amendment — see §26.1(d)) `commands/pr-quality-scorecard.sh` per-PR scoring against §2.8 manifest, W-4 decision trail, R-10 prop-change findings; rolls up per-author and per-team (anonymized author bands unless `userConfig.q_individual_attribution: true`).
- **Q-12** Agent-invocation observability log (v1.11 amendment — see §26.1(d)) `space/agent-invocations.sh` per-invocation: `subagent_id`, `prompt_id`, `prompt_version`, `tokens_in/out`, `model`, `latency_ms`, `exit_code`, `finding_count`. Distinct from H-12 (aggregated cost rollup); same telemetry stream, different consumer surface. Local-only by default; export requires Q-6 redaction filter.
- **H-13** Long-running agent harness continuity contract (v1.11 amendment — see §26.1(e) + §2.27) `commands/agent-continuity.sh` + `skills/agent-continuity/SKILL.md`: continuation artifact `.claude-tdd-pro/agent-continuations/<session_id>.json` containing `current_phase`, `completed_steps[]`, `pending_steps[]`, `context_summary`, `last_tool_calls[]`, `next_action`. Intra-CL continuity across context-window boundaries; distinct from §2.23 (cross-CL).


### §26.1 Why these gaps are architecture work

(a) **Next.js component scaffolder with design-token enforcement (R-8)** is architecturally distinct from O-12 `next-saas` scaffold (greenfield) and from R-5 `skills/react-component-build/SKILL.md` (general). R-8 ships a per-component generator that consults a design-token registry and refuses to emit component code that references untokenized values (raw hex, magic numbers); generated components ship with matching Storybook story + Vitest skeleton + a11y axe smoke test. The contract is: a Next.js platform team gets one command (`/component-add <name>`) that produces five files in five locations, each pre-conformed to the active profile (W-9 UI regression pin, R-3 a11y-axe detector, R-3 bundle-budget detector, F-3 critical-paths pre-registered for high-traffic components). Distinct from R-5 because R-5 is documentation-shaped (the skill explains the discipline); R-8 is a generator with an enforcement contract.

(b) **Design-system token registry + freshness gate (R-9 + O-13)** is the missing frontend analog to S-2 / S-6 / S-16 for the standards layer. R-9 ships the operator-facing `design-tokens/registry.yaml` schema (token id, value, contrast pair, deprecated, replaced_by); O-13 ships the freshness gate that auto-demotes any rule referencing a deprecated token to warn-only until the operator either upgrades the token reference or marks the suppression with E-5 inline justification. The architectural distinction from C-18 (control-mapping freshness) is that design tokens are intra-codebase (a deprecation event ripples through hundreds of component files) whereas compliance frameworks are extra-codebase (a stale framework only blocks new citation, not existing call-sites). The blast radius is what makes R-9 / O-13 a separate contract.

(c) **Component-API drift detector across PRs (R-10)** is the missing surface alongside L-9 (PR provenance) and F-4 (code-side bypass). R-10 walks the PR diff, identifies any exported component whose **public API surface** (prop names, prop types, return-element shape) changed, and surfaces a "potentially-breaking-for-consumers" finding with a suggested deprecated-prop migration entry. Reads from the design-tokens registry (R-9) when prop names reference token ids. Cross-references W-12 conversational reviewer (consumers ask "what about case Y?" → R-10's prop-change finding becomes the citation).

(d) **Quantifiable productivity-uplift metrics (Q-10, Q-11, Q-12)** extend Phase Q from "SPACE telemetry for solo developers" (Q-1..Q-9 scope) to "operator-facing productivity narrative" — what leadership-reporting frontend platforms need. Q-10 ships the velocity-uplift dashboard (`/velocity-report` per-skill + per-rule cycle-time deltas vs. baseline window). Q-11 ships the AI-assisted PR quality scorecard (per-PR scoring against §2.8 manifest, W-4 decision trail, R-10 prop-change findings; rolls up per-author and per-team). Q-12 ships the agent-invocation observability log (per-invocation: subagent_id, prompt_id, prompt_version, tokens_in/out, model, latency_ms, exit_code, finding_count) — distinct from H-12 cost rollup because Q-12 is per-invocation observability (debug/trace surface) whereas H-12 is aggregated cost (budget/regression surface). Same underlying telemetry stream; different consumer surfaces. Privacy posture: Q-10..Q-12 honor Q-6 export/redaction rules — telemetry is local-only by default; `/velocity-report --export` requires the same redaction filter as `/space-export`.

(e) **Long-running agent harness continuity contract (H-13 + §2.27)** codifies the Anthropic "initializer + incremental coding agent + artifacts" pattern: when a CL's work exceeds a single agent context window, the initializer agent writes a continuation artifact (`.claude-tdd-pro/agent-continuations/<session_id>.json`) containing: current_phase, completed_steps[], pending_steps[], context_summary, last_tool_calls[], next_action. The incremental agent reads the artifact at startup and resumes from `next_action` without losing the §2.15 workflow state envelope. Distinct from §2.23 concurrent-CL contract (W-10) which is cross-CL coordination; H-13 is intra-CL continuity across context-window boundaries within a single CL.

(f) **Customer-facing AI agent contract (§2.26)** is the missing template surface alongside O-12 application scaffolds. §2.26 specifies the schema that customer-facing agent templates must satisfy: (1) explicit grounding source list (which RAG store / knowledge base the agent reads); (2) refusal contract for ungrounded queries (mirrors W-12's "I don't have grounding" template, mandatory per §2.26); (3) per-turn cost reporting to H-12 with `agent_kind: customer-facing` tag; (4) audit log path (mandatory); (5) safety-classifier hook (PreToolUse). Distinct from W-12 conversational PR reviewer because W-12 is internal-facing (developer is the consumer); §2.26 is external-facing (end user is the consumer) and therefore has stricter refusal + safety contracts. Wayfair's Muse (home design visualization) and Decorify are the operator-facing examples; §2.26 codifies what makes such agents safe-by-construction.

### §26.2 Boundary discipline preserved

These amendments do NOT relax any v1.9 / v1.9.1 / v1.10 / v1.9.2 invariant:

- **R-8 component generator emits files that go through the same active profile.** Generated component, story, test, and a11y smoke are subject to the same H-5 multi-language honesty (TS/JS), the same R-3 detectors (a11y, bundle budget, RSC boundary, exhaustive deps), and the same E-5 inline-suppression discipline as hand-written components.
- **R-9 design-token registry freshness is rule-state, not source-folder ownership.** R-9 lives in `design-tokens/registry.yaml` (operator-editable) and integrates with the §2.5 profile precedence; it does NOT create a new source-folder under `generated-code-quality-standards/` (those are upstream-citation-pinned per §2.6).
- **O-13 design-token freshness gate honors the §2.17 status enum.** Deprecated-token references demote rules to `warn-only` (same status as standards-stale) — the freshness state machine is shared, not forked.
- **R-10 component-API drift findings cite the W-3 workflow state envelope** so the W-12 conversational reviewer can answer "why was this prop renamed?" without re-running R-10. Findings are append-only to `.claude-tdd-pro/component-api-history/<component-id>.jsonl` per the §2.7 sectioned-lock contract.
- **Q-10..Q-12 honor Q-6 privacy contract.** Q-12 per-invocation logs are local-only; export requires the Q-6 redaction filter. Cross-team rollup in Q-11 reports anonymized author bands (P0..P3 quartiles by cycle-time, not individual names) unless `userConfig.q_individual_attribution: true` is set — which has the same privacy implications as `pr_review_cross_pr_memory` and is documented in the operator-facing schema.
- **H-13 continuation artifact is part of W-3 workflow state, not a parallel state surface.** The artifact under `.claude-tdd-pro/agent-continuations/` references the parent `session_id` from `.claude-tdd-pro/workflow-state.json` (§2.15 envelope); restart drops the artifact into the active envelope's `_resumable` block. No state divergence.
- **§2.26 customer-facing agent template is opt-in.** Plugin does NOT ship customer-facing agents by default (only the internal-facing ones in `agents/` are bundled); operators activate `/customer-agent-add <name>` (which `O-12`-style scaffolds into `agents/_customer/<name>.md`) and the contract validates the result. Refusal contract is mandatory at the schema level (validator rejects agent files that don't declare a refusal template).
- **§2.27 long-running harness continuity does not bypass §2.23 concurrent-CL contract.** A continuation artifact is per-session_id; two CLs each with their own continuation artifact still must satisfy §2.23 (a)-(e) disjoint ownership before W-10 admits them concurrently.

### §26.3 Out of scope for §26

- **Vendor-portable agent invocation log format.** Q-12 ships the local schema; cross-vendor (Anthropic / Gemini / OpenAI / Grok) log normalization is a downstream packaging concern, not v1.11 architecture. The local Q-12 schema is rich enough for a future adapter; the adapter itself ships separately.
- **Outer-planner / inner-executor hybrid routing across vendors.** P-10 (v1.10 §24) is the router; v1.11 does NOT add a "router for routers" that splits planning to one vendor and execution to another. Operators who want hybrid routing build it via P-10's `prompts/router.yaml` per-task-class extension; the architecture stays vendor-agnostic.
- **A managed customer-facing agent marketplace.** §2.26 ships the contract for safe customer-facing agents; it does NOT ship a hosted directory or template registry. That's a downstream offering.
- **Design-token migration codemods.** R-9 + O-13 surface deprecated-token findings; the actual codemod to migrate hex `#FF0000` → token `color.brand.primary` ships through R-5 component-build skill orchestration, not as a separate v1.11 feature.
- **Velocity-baseline normalization across teams.** Q-10 reports cycle-time deltas vs. a per-team baseline window; cross-team productivity normalization (which company-wide processes affect velocity differently) is honest-scope-limited per Q-8.
- **Long-context agent models replacing H-13 artifact pattern.** Even with 1M-token Claude / 2M-token Gemini context windows, the H-13 continuation artifact remains canonical for audit-trail (the artifact is what the §2.8 provenance manifest cites). Long context reduces the *frequency* of continuation events but does not replace the artifact contract.

### §26.4 Cumulative ranking impact

| Concern | v1.10 score | v1.11 score | Mechanism |
|---|---|---|---|
| Frontend-platform component generation depth | 6/10 (R-5 skill + O-12 scaffold) | 8.5/10 (R-8 token-enforcing generator + Storybook/a11y/budget pre-conformance) | R-8 |
| Design-token freshness & deprecation discipline | 4/10 (no contract; ad-hoc per-team) | 8/10 (R-9 registry + O-13 freshness gate + auto-demote) | R-9 + O-13 |
| Cross-PR component-API drift | 5/10 (L-12 PR diff → eval-dataset; no API-shape diff) | 8.5/10 (R-10 prop-change findings cite W-3 envelope) | R-10 |
| Operator-facing productivity narrative | 5/10 (Q-1..Q-9 SPACE telemetry, single-author scope) | 8.5/10 (Q-10 velocity-uplift + Q-11 PR quality scorecard + Q-12 per-invocation observability) | Q-10..Q-12 |
| Long-running agent continuity (per Anthropic pattern) | 6/10 (W-3 state envelope; no across-context-window contract) | 9/10 (§2.27 + H-13 continuation artifact, session_id-keyed) | H-13 + §2.27 |
| Customer-facing AI agent safety contract | 4/10 (no template; operators build ad-hoc) | 8/10 (§2.26 grounding + refusal + per-turn cost + audit + safety-classifier hook) | §2.26 |
| **Capability ranking (overall)** | **9.93/10** | **9.95/10** | Cumulative |

Build confidence preserved at 9/10 via canonical staged path. v1.11 amendments land in weeks 31-33 per §20 extension.

### §26.5 Cross-references to existing architecture

- §2.3 (subagent contract): R-8 component generator dispatches to R-5 + R-1 reviewer agents per §2.3; H-13 continuation initializer is itself a §2.3-compliant agent.
- §2.5 (profile precedence): R-9 design-token registry integrates with profile cascade (operator override allowed; bundled tokens versioned via O-10 rubric semver).
- §2.7 (sectioned advisory locks): R-10 component-API history append uses dedicated `component-api` lock section to avoid contention with E-5 inline-suppression writes.
- §2.8 (AI provenance manifest): §2.26 customer-facing agents emit per-turn manifests with `agent_kind: customer-facing`; H-13 continuation artifacts cite the parent manifest.
- §2.14 (dry-run contract): R-8 `/component-add --dry-run`, R-9 `/token-add --dry-run`, R-10 `/api-drift-check --dry-run`, Q-10 `/velocity-report --dry-run`, §2.26 customer-agent activation — all dry-run subjects.
- §2.15 (workflow state contract): H-13 continuation artifact references parent `session_id`; resumption drops into the parent envelope's `_resumable` block.
- §2.17 (live freshness): O-13 deprecated-token gate honors the same status enum (`fresh-within-fetch-frequency` mapped to `fresh-within-deprecation-window` per the schema extension in §2.26 / §26.7).
- §2.23 (concurrent CL contract, v1.9.1): H-13 continuation artifacts are per-session_id; do not bypass disjoint-ownership.
- §2.25 (pending-spec fidelity, v1.9.2): vocabulary additions in §26.7 are explicitly added to the architecture-vocabulary set so the auditor accepts them.
- C-3 (provenance manifest emitter): §2.26 customer-facing agents extend the `ai_involvement` block with `agent_kind` field.
- H-12 (cost rollup, v1.9.1): Q-12 per-invocation observability shares the same telemetry stream as H-12 aggregates; consumers differ.
- W-3 (workflow state machine): H-13 continuation reads/writes the `_resumable` block.
- W-12 (conversational PR reviewer, v1.10): R-10 findings become citable evidence for W-12's grounded answers.
- O-12 (application scaffolds, v1.10): R-8 component generator reuses O-12's scaffold-driven file-emission pattern.

### §26.6 Cross-cutting contracts introduced

**§2.26 Customer-facing AI agent safety contract.** Every customer-facing agent template under `agents/_customer/<name>.md` MUST declare: (a) `grounding_sources: [<rag-store-id>, ...]` — explicit list of knowledge bases the agent reads; (b) `refusal_template: "I don't have grounding for that..."` — verbatim template (or `inherits: w-12` to reuse the W-12 internal-reviewer template); (c) `per_turn_cost_target: <int>` — soft cost ceiling per turn (warn above; `safety_classifier_hook: <path>` mandatory). (d) `audit_log: .claude-tdd-pro/customer-agents/<name>/turns.jsonl` — append-only conversation log per the C-4 audit chain. (e) `safety_classifier_hook: <path>` — PreToolUse hook that classifies output for safety (defaults to the v1.11-shipped `hooks/scripts/customer-agent-safety-classifier.sh` which blocks unsafe-content output). Validator at `agents/_customer/validate.sh` rejects agent files missing any of (a)-(e).

**§2.27 Long-running agent harness continuity contract.** When a single CL exceeds an agent's context window, the harness writes a continuation artifact at `.claude-tdd-pro/agent-continuations/<session_id>.json` with: `parent_session_id`, `parent_cl_id`, `current_phase`, `completed_steps: [{step_id, completed_at, summary}]`, `pending_steps: [{step_id, queued_at, prerequisite_ids}]`, `context_summary: "<≤500 char>"`, `last_tool_calls: [<≤10 entries>]`, `next_action: {action, rationale}`. The successor agent reads the artifact at startup, validates `parent_session_id` matches an active W-3 envelope, drops the artifact contents into the envelope's `_resumable` block, and resumes from `next_action`. Artifacts are TTL'd: 24h since last write deletes the artifact (rationale: stale continuations are stale state, not historical record). Resumption preserves all §2.X invariants (lock-section ownership, source-folder ownership, etc.) — the continuation artifact is a context-window-crossing mechanism, not a contract-relaxation mechanism.

### §26.7 Anti-drift note for future CLs touching §26

Per `CLAUDE.md`, every CL must extract literal feature IDs and §2.X labels from this document. The v1.11 IDs (R-8, R-9, R-10, O-13, Q-10, Q-11, Q-12, H-13, §2.26, §2.27) are canonical and must be used verbatim — never paraphrased as "the design token feature," "the velocity dashboard," "the customer agent thing," etc. Folder names under `evals/pending/` for these amendments must be exactly `evals/pending/r/r-8-component-generator-with-design-token-enforcement/`, `evals/pending/r/r-9-design-token-registry/`, `evals/pending/r/r-10-component-api-drift-detector/`, `evals/pending/o/o-13-design-token-freshness-gate/`, `evals/pending/q/q-10-velocity-uplift-report/`, `evals/pending/q/q-11-pr-quality-scorecard/`, `evals/pending/q/q-12-agent-invocation-observability/`, `evals/pending/h/h-13-long-running-agent-continuity/`, `evals/pending/cross-cutting/2-26-customer-facing-agent-contract/`, `evals/pending/cross-cutting/2-27-long-running-harness-continuity/`. Test-affordance flag invention discipline (`CLAUDE.md`) applies as usual.

**Vocabulary additions for §25 fidelity audit (operator-facing, frontend-platform).** The following tokens are now part of the architecture vocabulary surface and the §25 auditor accepts them when they appear in pending spec bodies: `design-tokens`, `registry`, `deprecated`, `replaced_by`, `contrast_pair`, `prop`, `prop_type`, `component_api`, `velocity_uplift`, `cycle_time_delta`, `pr_quality_scorecard`, `agent_invocation`, `subagent_id`, `prompt_id`, `latency_ms`, `finding_count`, `agent_kind`, `customer-facing`, `grounding_sources`, `refusal_template`, `per_turn_cost_target`, `safety_classifier_hook`, `continuation_artifact`, `parent_session_id`, `completed_steps`, `pending_steps`, `context_summary`, `last_tool_calls`, `next_action`. These appear in §26.1 / §26.6 above; the §25 auditor reads the whole architecture file, so adding them here satisfies the vocabulary surface without a separate detector amendment.

### §26.8 v1.11 sequencing note for §20

§20 canonical staged path is extended with weeks 31-33 for v1.11 amendments. Suggested order: week 31 R-8 + O-12 reuse, R-9 + O-13 paired (design-token surface ships as one CL pair); week 32 R-10 + Q-12 (R-10 emits findings that Q-12 logs); week 33 Q-10 + Q-11 (productivity dashboard atop Q-12 stream), §2.26 + §2.27 contracts (governance-only). H-13 ships alongside §2.27 as the substrate. These amendments preserve the v1.9 `definition-of-done` (§21) by NOT changing what counts as "done" — they extend the surface, not the gate.

## §27. v1.12 — Continuous cloud-architecture education amendment (reference)

Additive amendment giving the plugin a standing watch on authoritative cloud-architecture guidance: poll tier-1 sources at any operator-specified frequency (millisecond-granular, **default `daily`**), cheaply (RFC 7232 conditional GETs), **only while a Claude Code session is active** (in-use semantics via the §2.13 active-flow stack), and roll the upstream delta into an operator-readable education digest organised by the six Well-Architected pillars and six curriculum phases. Promotes the two v1.8-candidate backlog notes (`docs/memory/architecture-backlog-in-use-polling.md`, `docs/memory/architecture-backlog-conditional-gets.md`) to active features and seeds a new Phase-S source domain. Reuses Phase S (S-2 fetcher, S-5 diff, S-10 monitor, S-13/S-16/S-17 freshness, S-18 trace) rather than building a parallel engine. Non-regressive: every existing F/E/G/S/C/P/R/N/T/Q/H/L/O/X/W feature and every §2.1–§2.27 contract retains its semantics; calendar `fetch_frequency` values keep exact current behavior (the grammar is *extended*, not replaced).

**Full design text — the authoritative source for this amendment's rationale, requirement→mechanism mapping, §27.1–§27.8 subsections, the 12-source domain seed table, the 10-behavior TDD spec sketches, and the 17-ticket time-bound plan — lives at [docs/design/v1.12-cloud-architecture-curriculum.md](design/v1.12-cloud-architecture-curriculum.md).** This §27 is an additive reference block: it registers the canonical IDs, the §25-auditor vocabulary, and the anti-drift folder map here in the constitution (per `CLAUDE.md`, these must be extractable from this file), and delegates the detailed text to the referenced design file. No existing §1–§26 content is altered.

**Status:** PROPOSED. Reference block appended without modifying any prior section. The substrate-and-spec build proceeds per the design file's ticket plan; the §25 fidelity gate reads this file, so the §27.6 vocabulary below is authoritative now.

**Ratified:** 2026-06-08 — operator approved ("Let's build it"); the PROPOSED status above is superseded by this additive note (per the append-only discipline, ratification is recorded as a new line, never by rewriting the prior one). Build commenced at S-20 (configurable-frequency / in-use polling scheduler) per the design-file ticket plan (CL-B1 specs → CL-B2 substrate).

**Authoritative IDs introduced by v1.12:** S-20, S-21, S-22, S-23, S-24 (Phase S, §4); §2.28, §2.29 (cross-cutting contracts, §2). No collision with §1–§26 IDs (S stopped at S-19; contracts at §2.27; amendment sections at §26).

Standard-form bullets (for `^- \*\*[A-Z]-` grep traversal compatibility):

- **S-20** Configurable-frequency / in-use polling scheduler (v1.12 amendment — see design file §27.1(a)). `standards/poll-scheduler.sh` re-fetches each registry source on its resolved `fetch_frequency` cadence while a session is active (in-use detection via §2.13 active-flow stack). Cadence grammar per §2.28.
- **S-21** Conditional-GET fetcher layer (v1.12 amendment — see design file §27.1(b)). Extends S-2 fetchers to persist `etag` + `last_modified` and send `If-None-Match` / `If-Modified-Since`; a `304` proves freshness without re-parsing/re-diffing. Contract §2.29.
- **S-22** `FETCH-FREQUENCIES.yaml` operator registry (v1.12 amendment — see design file §27.1(c)). Top-level `.claude-tdd-pro/FETCH-FREQUENCIES.yaml` mapping per-registry default and per-source override cadence; `any-frequency` resolves here; global default `daily`.
- **S-23** Cloud-architecture standards domain seed (v1.12 amendment — see design file §27.1(d)). Default cloud-architecture sources added to `STANDARDS-URLS.yaml` / `standards/sources.yaml`, each mapping via G-9 to a source-namespace folder. New namespaces by registry id prefix: `aws`, `azure`, `gcp`, `hashicorp` (DoD/NIST cloud guidance reuses `us-government`; CNCF/Kubernetes reuses `linux-foundation`).
- **S-24** Continuous cloud-architecture education digest (v1.12 amendment — see design file §27.1(e)). `commands/curriculum-digest.sh` rolls up the cross-source delta since last review into a brief organised by the six Well-Architected pillars and six curriculum phases; surfaces "new technologies" as an explicit `new_technology` delta class. Output `standards/curriculum-digest/<utc>.md` + `.json`.

**Cross-cutting contracts introduced (full text in the design file §27.3):**

- **§2.28 Configurable-frequency in-use polling contract.** A source's `fetch_frequency` (in §2.6 standards, §2.12 PR-corpus, §2.19 compliance) accepts EITHER a calendar token `daily | weekly | monthly | quarterly | on-demand` (existing, unchanged) OR a sub-day interval matching `^[0-9]+(ms|s|m|h)$` OR the shorthand `any-frequency`. Default when unset is `daily`. Sub-day intervals fire only while a session is active (non-empty §2.13 active-flow stack); offline degrades to the calendar default with `freshness_at_generation: offline-cached`. `any-frequency` resolves via S-22 `FETCH-FREQUENCIES.yaml` (override → registry-default → global `daily`). `/doctor` shows `next-fetch-eta`; H-1/H-12 record per-source fetch cost; the resolved cadence is recorded in the §2.8 manifest `standards_state.<source>`.
- **§2.29 Conditional-GET freshness-economy contract.** Each non-paywalled fetcher persists upstream `etag` and `last_modified` alongside `content_hash` in `.claude-tdd-pro/standards-last-fetch/<id>.json` and sends `If-None-Match` / `If-Modified-Since` on subsequent fetches. On `304 Not Modified`: update the freshness timestamp, increment the 304 counter, skip the parse/diff/hash-compare pipeline. On `200`: full S-2 pipeline + refresh stored headers. H-12 records the per-source `304:200` ratio. Paywalled/HEAD-only sources exempt. Conditional GET never advances `content_hash` or suppresses an S-5 diff when content actually changed.

**Vocabulary additions for §25 fidelity audit.** The following tokens become part of the architecture vocabulary surface and the §25 auditor (`rubric/detectors/audit-pending-spec-fidelity.sh`) accepts them in pending spec bodies for S-20..S-24 / §2.28 / §2.29: `fetch_frequency`, `any-frequency`, `FETCH-FREQUENCIES`, `poll-scheduler`, `in-use`, `active-flow`, `etag`, `last_modified`, `if-none-match`, `if-modified-since`, `not-modified`, `304`, `conditional-get`, `next-fetch-eta`, `standards-last-fetch`, `curriculum-digest`, `new_technology`, `well-architected`, `pillar`, `aws`, `azure`, `gcp`, `hashicorp`, `source_namespace`, `freshness_at_generation`.

**S-23 implementation note (additive clarification, 2026-06-08).** The S-23 cloud-architecture domain seed ships as its OWN domain catalog at `standards/cloud-architecture-sources.yaml` (plugin-internal §2.6 schema, one entry per seed source), kept SEPARATE from the S-1 catalog `standards/sources.yaml` so the S-1 "exactly 17 default sources" baseline is preserved unchanged. The operator-facing `.claude-tdd-pro/STANDARDS-URLS.yaml` merges both catalogs. Each seed entry maps via G-9 to its `generated-code-quality-standards/<namespace>/<id>.yaml` reading-source file — a source file with a populated `source:` header (per §2.21) and empty `rules: []` / `recommended_set: []` / `all_set: []` (cloud-architecture WAF guidance is educational reading for the S-24 digest, not lint rules; the empty-rules reading-source shape is the same one the active `validate-all` suite already blesses). The four new namespaces `aws`, `azure`, `gcp`, `hashicorp` are registered in `generated-code-quality-standards/validate-all.sh` `KNOWN_NAMESPACES`. **Additional §25 vocabulary (S-23/S-24):** `curriculum_phase`, `cloud-architecture-sources`, `architected`, `architecture-framework`, `reading-source`, `pillars`, `phases`.

**Anti-drift note (per `CLAUDE.md`).** The v1.12 IDs (S-20, S-21, S-22, S-23, S-24, §2.28, §2.29) are canonical and must be used verbatim. Pending folder names MUST be exactly: `evals/pending/s/s-20-configurable-frequency-polling-scheduler/`, `evals/pending/s/s-21-conditional-get-fetcher-layer/`, `evals/pending/s/s-22-fetch-frequencies-registry/`, `evals/pending/s/s-23-cloud-architecture-standards-domain-seed/`, `evals/pending/s/s-24-continuous-cloud-architecture-education-digest/`, `evals/pending/cross-cutting/2-28-configurable-frequency-polling-contract/`, `evals/pending/cross-cutting/2-29-conditional-get-freshness-economy-contract/`.

**§20 sequencing (full table in the design file §27.8).** Extends the canonical staged path with weeks 34–36: week 34 §2.28 + S-22 + S-20 (cadence grammar + registry + scheduler); week 35 §2.29 + S-21 (conditional-GET economy); week 36 S-23 then S-24 (seed the domain, then ship the digest). Preserves the §21 definition-of-done — extends surface, not gate.

### §27.9 S-25 curriculum study loop (additive amendment, 2026-06-08)

S-25 closes the divide → reach → learn loop over the S-24 digest. It is an ORCHESTRATOR over already-shipped Phase-S primitives — it reimplements none of them. Confirmed existing primitives it composes: **divide** = the S-24 digest `.json` `topics[]` (one topic per delta) + the S-2 section fetchers (`standards/fetchers/{markdown-headers,html-anchor,pdf-section,rfc-style}.sh`) + the S-3 coverage matrix; **reach** = `standards/fetcher.sh` (S-2) + `standards/conditional-get.sh` (S-21) + `standards/poll-scheduler.sh` (S-20) + `standards/freshness-gate.sh` (S-13/16/17); **learn** = `agents/standards-comparator.md` (S-8 grounded, decline-on-ungrounded summary) + `commands/standards-diff.sh` (S-5 Adopt/Defer/Reject → `standards/decisions.jsonl`) + optional `commands/promote-standard.sh` (S-7 section → rule). S-25 adds only the per-topic iteration + a resumable learning ledger.

**Authoritative ID introduced:** S-25 (Phase S, §4). No collision with §1–§27 IDs (S-20..S-24 are the prior v1.12 IDs).

Standard-form bullet (for `^- \*\*[A-Z]-` grep traversal):

- **S-25** Curriculum study loop (v1.12 addendum — see §27.9). `commands/curriculum-study.sh` iterates the S-24 digest `topics[]`; for each topic it reaches the section (S-2 fetcher + S-21 conditional-get), learns it (S-8 grounded summary + S-5 adopt/defer/reject decision, optional S-7 promote), and records a per-topic learning record to a resumable ledger `standards/curriculum-ledger.jsonl` (state `learned`; a topic already learned is skipped on re-run — learn-once + resumable). Each record cites the topic's `source_id` + `section_id` (grounding). `--dry-run` previews without writing the ledger (§2.14).

**Vocabulary additions for §25 fidelity audit (S-25):** `curriculum-study`, `curriculum-ledger`, `studied`, `learned`, `reach`, `reached`, `decision`, `adopt`, `defer`, `reject`, `resumable`, `topic_id`, `studied_at`, `delta_class`, `best_practice_updated`.

**Anti-drift note (S-25).** The ID is S-25, used verbatim. Pending folder name MUST be exactly: `evals/pending/s/s-25-curriculum-study-loop/`.

**§20 sequencing (S-25).** Extends the staged path with week 37: S-25 ships after S-24 (it consumes the S-24 digest). Governance-only ID addition; preserves the §21 definition-of-done (extends surface, not gate). Full divide/reach/learn rationale and the confirmation of pre-existing primitives are in the design file `docs/design/v1.12-cloud-architecture-curriculum.md` (to be appended there as the S-25 section).

### §27.10 Cloud-architect application layer (additive amendment, 2026-06-08)

S-26 and S-27 APPLY the cloud-architecture curriculum that the monitoring layer (S-20..S-25) keeps fresh. They consume the S-23 seed catalog + S-24 digest + S-25 ledger and reuse the S-8 standards-comparator grounding discipline (cite-or-decline). They add no new fetch/diff/learn logic — they are operator-facing application surfaces over the existing data.

**Authoritative IDs introduced:** S-26, S-27 (Phase S, §4). No collision with §1–§27.9 IDs.

Standard-form bullets (for `^- \*\*[A-Z]-` grep traversal):

- **S-26** Well-Architected pillar review (v1.12 addendum — see §27.10). `commands/well-architected-review.sh`: given a workload description and the active cloud-architecture sources, emits a review scaffold organised by the six Well-Architected pillars (`operational-excellence`, `security`, `reliability`, `performance-efficiency`, `cost-optimization`, `sustainability`); each pillar lists the grounding sources that cover it (from the S-23 catalog `pillars` field), with `findings` / `trade_offs` / `risk_tier` slots; a pillar with no grounding source is marked `needs_grounding` (mirrors the S-8 decline contract). Output `standards/well-architected-reviews/<utc>.md` + `.json`.
- **S-27** Curriculum progress and gap tracker (v1.12 addendum — see §27.10). `commands/curriculum-progress.sh`: reads the S-25 ledger + S-23 catalog and reports per-pillar and per-curriculum-phase coverage (studied vs available) plus the not-yet-studied gaps. Output `standards/curriculum-progress/<utc>.md` + `.json`.

**S-23 catalog enrichment (additive data).** Each `standards/cloud-architecture-sources.yaml` entry gains a `pillars: [...]` field listing the Well-Architected pillars that source covers (single source of truth that S-26 reads). This is additive to the §2.6 plugin-internal schema for the cloud-architecture domain catalog; it does not alter the S-1 `standards/sources.yaml`.

**Vocabulary additions for §25 fidelity audit (S-26/S-27):** `well-architected-review`, `pillars`, `needs_grounding`, `findings`, `trade_offs`, `risk_tier`, `workload`, `curriculum-progress`, `coverage`, `gap`, `studied`, `mastery`, `operational-excellence`, `security`, `reliability`, `performance-efficiency`, `cost-optimization`, `sustainability`.

**Anti-drift note (S-26/S-27).** IDs used verbatim. Pending folder names MUST be exactly: `evals/pending/s/s-26-well-architected-pillar-review/`, `evals/pending/s/s-27-curriculum-progress-and-gap-tracker/`.

**§20 sequencing (S-26/S-27).** Week 38: S-26 (review) then S-27 (progress) — both consume the v1.12 monitoring-layer outputs. Governance-only ID additions; preserve the §21 definition-of-done.

### §27.11 Cloud-architecture ADR generator (additive amendment, 2026-06-08)

S-28 extends the cloud-architect application layer with the curriculum's "Architecture Decision Log" practice. It generates MADR-conformant Architecture Decision Records per the existing §2.16 decision-provenance schema, grounded in the S-23 cloud-architecture sources. It introduces no new ADR schema — it produces §2.16-format ADRs for cloud design decisions and cites the grounding sources for the decision's Well-Architected pillar (reusing the S-26 pillar→source mapping).

**Authoritative ID introduced:** S-28 (Phase S, §4). No collision with §1–§27.10 IDs.

Standard-form bullet (for `^- \*\*[A-Z]-` grep traversal):

- **S-28** Cloud-architecture ADR generator (v1.12 addendum — see §27.11). `commands/cloud-adr.sh`: generates a MADR-conformant Architecture Decision Record (per §2.16) for a cloud design decision — `<out-dir>/<NNNN>-<slug>.md` whose filename matches the §2.16 `^[0-9]{4}-[a-z0-9-]+\.md$` pattern — with `status` (enum `proposed|accepted|rejected|superseded|deprecated`), `context`, `considered_options`, and `decision_outcome` with `rationale`; grounded by citing the S-23 cloud-architecture sources that cover the decision's Well-Architected `pillar` (a pillar with no source is marked `needs_grounding`). Emits a json sidecar. Output default dir `docs/adr/`.

**Vocabulary additions for §25 fidelity audit (S-28):** `cloud-adr`, `adr`, `slug`, `decision_outcome`, `considered_options`, `deciders`, `decision_id`, `superseded`, `deprecated`, `accepted`, `rejected`.

**Anti-drift note (S-28).** ID used verbatim. Pending folder name MUST be exactly: `evals/pending/s/s-28-cloud-architecture-adr-generator/`.

**§20 sequencing (S-28).** Week 39: S-28 ships after S-26/S-27 (it grounds ADRs in the same pillar→source mapping). Governance-only ID addition; preserves the §21 definition-of-done.

### §27.12 Cloud-architecture build units — test-first IaC from design (additive amendment, 2026-06-08)

S-29 closes the design->build gap: the infrastructure the cloud-architect layer DESIGNS (the S-28 ADR + S-26 pillar review) must be DEVELOPED with the same excellence as every other type of code the plugin builds — test-first, standards-grounded, decision-traced, red-until-green. S-29 makes Infrastructure-as-Code a first-class TDD build target rather than a second-class side path. It reuses the existing core contracts: the §2.16 ADR is the design input, the test-first discipline (the plugin's universal build loop) governs the order, and the S-23/S-26 pillar->source grounding supplies the conformance criteria's provenance (cite-or-needs_grounding).

**Authoritative ID introduced:** S-29 (Phase S, §4). No collision with §1–§27.11 IDs.

Standard-form bullet (for `^- \*\*[A-Z]-` grep traversal):

- **S-29** Cloud-architecture build units (v1.12 addendum — see §27.12). `commands/cloud-build.sh`: turns a cloud design decision (an S-28 ADR) into a test-first IaC build unit. `scaffold` writes, together, a `conformance` spec (the test, derived from the decision's Well-Architected `pillar` + requirements, with grounding citations), an IaC stub (`terraform`->`.tf`, `bicep`->`.bicep`, `cloudformation`->`.json`), a `grounding` manifest, and a `unit` metadata record that traces to the ADR `decision_id`; the fresh unit starts RED (the `check` action fails until the IaC satisfies the conformance requirements, then it is GREEN). Requirements default per pillar and are overridable; a pillar with no grounding source is marked `needs_grounding`. This enforces the same spec-first / grounded / ADR-traced build excellence on infrastructure as on application code.

**Vocabulary additions for §25 fidelity audit (S-29):** `cloud-build`, `build-unit`, `conformance`, `scaffold`, `iac`, `terraform`, `bicep`, `cloudformation`, `requirements`, `red`, `green`, `decision_id`, `needs_grounding`.

**Anti-drift note (S-29).** ID used verbatim. Pending folder name MUST be exactly: `evals/pending/s/s-29-cloud-architecture-build-units/`.

**§20 sequencing (S-29).** Week 40: S-29 ships after S-28 (it consumes the ADR design output and feeds the plugin's existing implement loop). Governance-only ID addition; preserves the §21 definition-of-done.

### §27.13 Cloud-architecture convention enforcement — syntax + patterning (additive amendment, 2026-06-08)

S-30 extends the cloud-architect feature so that EVERYTHING concerning the software development of cloud architecture — the syntax used in IaC implementations and all patterning — is enforced from authoritative best-practice sources. Comprehensiveness assessment (2026-06-08): the S-23 architecture seed covers Well-Architected guidance + design patterns but carried no dedicated style/convention authorities for Terraform/Bicep/CloudFormation or general software engineering, so the best world-class engineering sources were secured (URLs verified) into a new engineering catalog. Convention rules ground their rules in those source ids plus the S-23 catalog (cite-or-decline).

**Authoritative ID introduced:** S-30 (Phase S, §4). No collision with §1–§27.12 IDs.

**Sources secured (new engineering catalog `standards/cloud-engineering-sources.yaml`, all tier 1, applies_to cloud-architecture, with a `discipline: [syntax|patterning]` tag):** `hashicorp-terraform-style-guide`, `terraform-recommended-practices`, `azure-bicep-best-practices`, `aws-cloudformation-best-practices`, `twelve-factor-app`, `google-eng-practices`.

Standard-form bullet (for `^- \*\*[A-Z]-` grep traversal):

- **S-30** Cloud-architecture convention enforcement (v1.12 addendum — see §27.13). `commands/cloud-conventions.sh`: enforces the syntax and patterning of IaC against grounded convention rulesets at `standards/cloud-conventions/<tool>.yaml` (terraform, bicep, cloudformation). Each rule `{id, source_id, kind (syntax|patterning), mode (require|forbid), token, message}` cites a best-practice source from the S-30 engineering catalog or the S-23 architecture catalog; a rule whose source is in neither is REJECTED (cite-or-decline, exit 2). `require` tokens must appear, `forbid` tokens (e.g. `0.0.0.0/0`) must not; each violation cites its grounding source. Lints an `--iac <file>` or a build unit (`--unit`); exit 0 green / 1 red. Composes with S-29: the build gate is `check` (requirements) AND `cloud-conventions` (syntax + patterning).

**Vocabulary additions for §25 fidelity audit (S-30):** `cloud-conventions`, `convention`, `discipline`, `syntax`, `patterning`, `kind`, `mode`, `require`, `forbid`, `token`, `ruleset`, `violation`, `ungrounded`, `terraform`, `bicep`, `cloudformation`, `twelve-factor-app`, `google-eng-practices`.

**Anti-drift note (S-30).** ID used verbatim. Pending folder name MUST be exactly: `evals/pending/s/s-30-cloud-architecture-convention-enforcement/`. The new engineering catalog is `standards/cloud-engineering-sources.yaml` (distinct from the S-23 `standards/cloud-architecture-sources.yaml`, whose exactly-twelve invariant is preserved).

**§20 sequencing (S-30).** Week 41: S-30 ships after S-29 (it enforces convention on the IaC that S-29 scaffolds). Governance-only ID addition; preserves the §21 definition-of-done.

### §27.14 Secured-source expansion + sources-catalog + DoD/observability profiles (additive amendment, 2026-06-08)

S-31 deepens the cloud-architect feature toward government-grade (DoD/DARPA, IL4/IL5, Zero Trust) and elite-scale (SRE, observability, FinOps, GitOps) excellence by securing additional verified primary authorities into the engineering catalog, generating the project's auditable sources-catalog document, and adding grounded convention profiles that cite the new authorities. No existing source/rule is altered; cite-or-decline still holds (every rule cites a catalog source).

**Authoritative ID introduced:** S-31 (Phase S, §4). No collision with §1–§27.13 IDs.

**Sources secured (appended to `standards/cloud-engineering-sources.yaml`, all tier 1, applies_to cloud-architecture, with a `discipline` tag; URLs verified 2026-06-08):** `aws-dod-scca-prescriptive`, `nist-800-53`, `nist-800-171`, `nist-rmf`, `google-sre-book`, `opentelemetry-docs`, `finops-framework`, `argocd-gitops`.

Standard-form bullet (for `^- \*\*[A-Z]-` grep traversal):

- **S-31** Secured-source expansion and sources catalog (v1.12 addendum — see §27.14). Appends DoD/NIST security-controls, Google SRE reliability, OpenTelemetry observability, FinOps and GitOps authorities to the S-30 engineering catalog. `commands/sources-catalog.sh` generates `standards/SOURCES.md` — the auditable Markdown catalog mirroring both the S-23 and S-30/S-31 registries with links + metadata. Adds two grounded convention profiles at `standards/cloud-conventions/`: `dod-zero-trust.yaml` (require `encrypt` + `logging`, forbid `0.0.0.0/0` + hardcoded secrets; grounded in nist-800-53 / aws-dod-scca-prescriptive / aws-prescriptive-security) and `observability.yaml` (require OpenTelemetry instrumentation + SRE monitoring; grounded in opentelemetry-docs / google-sre-book), enforced via S-30 `cloud-conventions.sh --ruleset`.

**Vocabulary additions for §25 fidelity audit (S-31):** `sources-catalog`, `security-controls`, `governance`, `reliability`, `observability`, `finops`, `gitops`, `telemetry`, `sre`, `zero-trust`, `aws-dod-scca-prescriptive`, `nist-800-53`, `nist-800-171`, `nist-rmf`, `google-sre-book`, `opentelemetry-docs`, `finops-framework`, `argocd-gitops`.

**Anti-drift note (S-31).** ID used verbatim. Pending folder name MUST be exactly: `evals/pending/s/s-31-secured-source-expansion-and-sources-catalog/`. New sources append to the existing `standards/cloud-engineering-sources.yaml`; the S-23 `standards/cloud-architecture-sources.yaml` exactly-twelve invariant is untouched.

**§20 sequencing (S-31).** Week 42: S-31 ships after S-30 (it expands the same grounding catalog and convention surface). Governance-only ID addition; preserves the §21 definition-of-done.

### §27.15 Business-language architect advisory layer (additive amendment, 2026-06-08)

S-32..S-36 add a business-language advisory front-end so an engineer with little cloud knowledge can act through the plugin as a competent architect — eliciting business inputs, translating them to technical concerns, recommending grounded decisions, and explaining the output in plain language. Detailed design + ticket plan: `docs/design/v1.13-business-language-architect.md`. These features COMPOSE the existing S-26 (review), S-28 (ADR), S-29 (build), S-30 (enforce) stack and reuse its schemas; the conversational layer is the agent acting on these deterministic, grounded artifacts. Cite-or-decline preserved (every translation/recommendation/glossary entry cites a catalog source or declines).

**Authoritative IDs introduced:** S-32, S-33, S-34, S-35, S-36 (Phase S, §4). No collision with §1–§27.14 IDs.

Standard-form bullets (for `^- \*\*[A-Z]-` grep traversal):

- **S-32** Business-language requirements intake (v1.13 — see §27.15). `commands/business-intake.sh`: a structured questionnaire capturing business inputs (workload, criticality, availability_tolerance, data_sensitivity, compliance_regime, scale, budget_posture) with allowed-answer enums; validates answers, surfaces `unanswered`/`invalid` for agent follow-ups, emits `business-profile.json`.
- **S-33** Business-to-technical translation (v1.13 — see §27.15). `commands/business-translate.sh`: maps a business-profile to pillar-keyed technical concerns, each `{concern, driver, source_id}` grounded in a catalog source; emits `technical-requirements.json` (the bridge into S-26/S-29).
- **S-34** Architect recommendation engine (v1.13 — see §27.15). `commands/architect-recommend.sh`: emits opinionated recommended decisions `{decision, pillar, driver, rationale, source_id}` from the profile + requirements; emits S-28 ADR args and S-29 build requirements; `needs_grounding` when unbacked.
- **S-35** Plain-language explainer (v1.13 — see §27.15). `commands/explain.sh`: a grounded glossary translating technical terms and review/ADR findings to business language `{term, plain, why_it_matters, source_id}`; annotates a review; declines `unknown_term`.
- **S-36** Guided architect session orchestrator (v1.13 — see §27.15). `commands/architect-session.sh`: chains intake -> translate -> recommend -> S-26 review -> S-28 ADR -> S-29 build, surfaces `next_question` while the profile is incomplete, and emits a plain-language `session.md` summary via S-35 plus a `session.json` artifact.

**Vocabulary additions for §25 fidelity audit (S-32..S-36):** `business-intake`, `business-profile`, `criticality`, `availability_tolerance`, `data_sensitivity`, `compliance_regime`, `budget_posture`, `scale`, `unanswered`, `business-translate`, `technical-requirements`, `concern`, `driver`, `architect-recommend`, `recommendation`, `rationale`, `explain`, `glossary`, `plain`, `why_it_matters`, `unknown_term`, `architect-session`, `next_question`, `session_complete`.

**Anti-drift note (S-32..S-36).** IDs used verbatim. Pending folder names MUST be exactly: `evals/pending/s/s-32-business-language-requirements-intake/`, `evals/pending/s/s-33-business-to-technical-translation/`, `evals/pending/s/s-34-architect-recommendation-engine/`, `evals/pending/s/s-35-plain-language-explainer/`, `evals/pending/s/s-36-guided-architect-session-orchestrator/`.

**§20 sequencing (S-32..S-36).** Weeks 43–47: S-32 intake, then S-33 translate, S-34 recommend, S-35 explain, then S-36 orchestrator last (it composes the others + S-26/S-28/S-29). Governance-only ID additions; preserve the §21 definition-of-done.

**§27.15.1 Sources secured for S-32/S-33 (additive, 2026-06-08).** The business-language layer grounds in additional verified authorities appended to `standards/cloud-engineering-sources.yaml`: `azure-waf-business-requirements` (Listen->Probe->Clarify intake methodology), `aws-rpo-rto-targets` and `aws-reliability-pillar` (availability/criticality questions + reliability mappings), `aws-wa-tool-profiles` (business-context questionnaire). Additional §25 vocab: `motivation`, `data_loss_tolerance`, `availability`, `rto`, `rpo`, `grounded_in`, `intake`, `business-requirements`, `azure-waf-business-requirements`, `aws-rpo-rto-targets`, `aws-wa-tool-profiles`, `aws-reliability-pillar`.

### §27.16 Layered multi-cloud advisor — common core + platform boundaries + data/distributed domain (additive amendment, 2026-06-08)

S-37..S-45 layer the cloud-architect feature: one COMMON platform-agnostic business-to-technical core holding all cross-platform best-practice patterns (cloud + data + distributed-systems/integration) that guides beginners in business language, plus THREE platform-expert boundaries (AWS/Azure/GCP) that add platform-specific knowledge and wrap each vendor's native advisory API. The already-registered S-34 is built as the multi-option recommendation composer (improving on the AWS Well-Architected Tool: business-first, multi-option with trade-offs, multi-authority grounded, feeding S-28 ADR + S-29 build). Detailed design: `docs/design/v1.14-layered-multicloud-advisor.md`. Determinism preserved: native API responses are INJECTED fixtures (as with S-21 HTTP / S-24 deltas); the deterministic substrate is the normalizer. Cite-or-decline preserved across all layers.

**Authoritative IDs introduced:** S-37, S-38, S-39, S-41, S-42, S-43, S-44, S-45 (Phase S, §4). No collision with §1–§27.15 IDs.

Standard-form bullets (for `^- \*\*[A-Z]-` grep traversal):

- **S-37** Data and distributed-systems source catalogs (v1.14 — see §27.16). Secures + registers `standards/data-architecture-sources.yaml` (AWS Data Analytics Lens, Azure/GCP data-architecture guidance) and `standards/distributed-systems-sources.yaml` (Enterprise Integration Patterns free catalog, Patterns of Distributed Systems on martinfowler.com, Fowler CQRS/Event-Sourcing/Saga) as grounding fuel for the data + integration domain.
- **S-38** Data-aware business intake (v1.14 — see §27.16). Extends `business-intake.sh` with grounded business-language questions: data volume/growth, read/write pattern, consistency need, communication style (sync vs event-driven), integration scope, real-time vs batch.
- **S-39** Data and distributed translation mappings (v1.14 — see §27.16). Extends `business-translate.sh` with grounded mappings to data/distributed concerns: sharding/replication/partition_strategy, message_queue/dead_letter_queue/outbox_pattern, saga/cqrs/event_sourcing, api_gateway/anti_corruption_layer.
- **S-41** Platform-boundary contract and dispatcher (v1.14 — see §27.16). `commands/platform-boundary.sh`: the common->boundary handoff envelope (`{business_profile, technical_requirements, selected_option, target_platform}` in; `{platform, recommendations, iac_targets, build_units, native_review_ref}` out) and routing to the chosen platform boundary.
- **S-42** AWS platform boundary (v1.14 — see §27.16). `commands/aws-boundary.sh`: AWS pattern depth + a normalizer wrapping the AWS Well-Architected Tool API (injected response -> common grounded concerns/options); platform-aware IaC Terraform/CloudFormation.
- **S-43** Azure platform boundary (v1.14 — see §27.16). `commands/azure-boundary.sh`: Azure pattern depth + Azure Advisor REST API normalizer; platform-aware IaC Bicep.
- **S-44** GCP platform boundary (v1.14 — see §27.16). `commands/gcp-boundary.sh`: GCP pattern depth + GCP Recommender API normalizer; platform-aware IaC Terraform/Deployment Manager.
- **S-45** Implementation-toolchain advisor (v1.14 — see §27.16). `commands/toolchain-advisor.sh`: grounded recommendations + deterministic scaffolds for the toolchain beyond IaC (containers/orchestration, GitOps/CD, CI/CD, config mgmt, DB migrations, messaging, observability, policy-as-code, testing, FinOps), per chosen option + platform.

**Vocabulary additions for §25 fidelity audit (S-37..S-45):** `data-architecture`, `distributed-systems`, `integration-patterns`, `enterprise-integration-patterns`, `patterns-of-distributed-systems`, `aws-data-analytics-lens`, `consistency`, `replication`, `partitioning`, `sharding`, `polyglot`, `event-driven`, `messaging`, `queue`, `dead_letter_queue`, `outbox_pattern`, `saga`, `cqrs`, `event_sourcing`, `anti_corruption_layer`, `option`, `options`, `trade_offs`, `platform-boundary`, `boundary`, `aws-boundary`, `azure-boundary`, `gcp-boundary`, `normalize`, `native_review_ref`, `toolchain`, `toolchain-advisor`, `gitops`.

**Anti-drift note (S-37..S-45).** IDs used verbatim. Pending folder names MUST be exactly: `evals/pending/s/s-37-data-and-integration-sources-catalog/`, `evals/pending/s/s-38-data-aware-business-intake/`, `evals/pending/s/s-39-data-and-distributed-translation/`, `evals/pending/s/s-41-platform-boundary-contract-and-dispatcher/`, `evals/pending/s/s-42-aws-platform-boundary/`, `evals/pending/s/s-43-azure-platform-boundary/`, `evals/pending/s/s-44-gcp-platform-boundary/`, `evals/pending/s/s-45-implementation-toolchain-advisor/`. New catalogs are `standards/data-architecture-sources.yaml` and `standards/distributed-systems-sources.yaml` (distinct from the S-23/S-30 catalogs; their invariants are untouched).

**§20 sequencing (S-37..S-45).** Weeks 48–55, after the v1.13 common layer (S-34 option composer, S-35, S-36) is built: S-37 sources, then S-38 intake + S-39 translation (common-layer domain depth), then S-41 boundary contract, then S-42/S-43/S-44 boundaries, then S-45 toolchain. Governance-only ID additions; preserve the §21 definition-of-done.

### §27.17 Experience-first roadmap + objective-weighted optimization (additive amendment, 2026-06-08)

Reframes the v1.13/v1.14 build around the end-user journey: a non-technical founder states an app vision and the plugin guides every cloud-architecture decision in business language, then implements it across the available platform APIs, optimized to be cost-effective, performance-optimized, customer-centric, and shareholder-centric. Two consequences: build the thinnest end-to-end path first (walking skeleton, M0) before deepening any stage; and make the four optimization objectives a first-class, grounded, scored dimension (S-46) from the skeleton onward. Detailed roadmap + milestones M0..M6: `docs/design/v1.15-experience-first-roadmap.md`.

**Authoritative ID introduced:** S-46 (Phase S, §4). No collision with §1–§27.16 IDs.

Standard-form bullet (for `^- \*\*[A-Z]-` grep traversal):

- **S-46** Objective-weighted optimization and option scoring (v1.15 — see §27.17). `commands/optimize-options.sh`: scores and ranks the S-34 options against four grounded objectives — cost-effective (`finops-framework` + AWS WAF Cost pillar), performance-optimized (AWS WAF Performance Efficiency pillar), customer-centric (`aws-reliability-pillar` / `aws-rpo-rto-targets`), shareholder-centric (`finops-framework` / `google-eng-practices` + operational-excellence). Weights derive from the business-profile (e.g. `budget_posture=cost-first`, `criticality=mission-critical`) and are overridable; emits a ranked `option-scoring.json` with per-objective scores + grounded rationale; cite-or-decline marks an unbacked objective `needs_grounding`.

**Vocabulary additions for §25 fidelity audit (S-46):** `optimize-options`, `objective`, `objectives`, `cost-effective`, `performance-optimized`, `customer-centric`, `shareholder-centric`, `scoring`, `ranked`, `weight`, `time-to-market`, `vision`, `walking-skeleton`.

**Anti-drift note (S-46).** ID used verbatim. Pending folder name MUST be exactly: `evals/pending/s/s-46-objective-weighted-optimization/`.

**§20 sequencing (experience-first).** Delivery is milestone-ordered, not feature-ordered: M0 walking skeleton (S-34 + S-36 entry over the built S-32/S-33/S-26/S-28/S-29/S-30) -> M1 guided architect (S-35 + full S-36 + S-34 multi-option) -> M2 objectives first-class (S-46) -> M3 data/distributed depth (S-37, S-38, S-39) -> M4 platform APIs (S-41, S-42, S-43, S-44) -> M5 toolchain (S-45) -> M6 closed loop. Dependencies preserved (S-34 before S-46/boundaries; S-37 before S-38/S-39; S-41 before S-42/S-43/S-44). Governance-only ID addition; preserves the §21 definition-of-done.

### §27.18 Requirement clarification loop + objective-weighting requirement (additive amendment, 2026-06-08)

Refines S-35: an unrecognised term must not dead-end. The plugin CLARIFIES it (asks the founder, in business language, what it should do) and keeps clarifying until the requirement resolves to a technical concern that S-33/S-34 can translate to architecture. Also records the standing requirement that S-46 (held) must weigh all four objectives, grounded in the provided knowledge corpus, to produce first-class decisions.

**Authoritative ID introduced:** S-47 (Phase S, §4). No collision with §1–§27.17 IDs.

Standard-form bullet (for `^- \*\*[A-Z]-` grep traversal):

- **S-47** Requirement clarification loop (v1.13 refinement of S-35 — see §27.18). `commands/explain.sh` gains: an unrecognised `--term` emits a `clarification_prompt` (a plain-language question) alongside the preserved `unknown_term` signal; `--clarify "<term>=<business description>"` maps the description to a known technical concern via a grounded keyword index, emitting `clarified=<term> mapped_to=<concern> source=<id>` on resolution, or another `clarification_prompt` (`unresolved`) to continue the loop. The loop ends when the requirement resolves to a concern S-33/S-34 can translate. cite-or-decline preserved (the resolved concern carries its grounding source).

**S-46 objective-weighting requirement (standing, for the held M2 build).** When built, S-46 MUST weigh all four objectives — cost-effective, performance-optimized, customer-centric, shareholder-centric — grounded in the secured knowledge corpus (the S-23/S-30/S-31 + v1.13 sources), so its rankings are first-class (on par with the world's best cloud architects' decisions), not heuristic. No option is recommended on a single objective alone.

**Vocabulary additions for §25 fidelity audit (S-47):** `clarify`, `clarification`, `clarification_needed`, `clarification_prompt`, `clarified`, `mapped_to`, `unresolved`, `requirement`.

**Anti-drift note (S-47).** ID used verbatim. Pending folder name MUST be exactly: `evals/pending/s/s-47-requirement-clarification-loop/`.

**§20 sequencing (S-47).** M1 refinement, built immediately after S-36 (it strengthens S-35's unknown-term handling). Governance-only ID addition; preserves the §21 definition-of-done.

### §27.19 Platform-boundary external-call safety + plugin-standard normalized response (additive amendment, 2026-06-08)

Two cross-cutting contracts binding every platform boundary (S-41 dispatcher + S-42/S-43/S-44 boundaries). No new feature ID.

**Contract A — external-call safety (no POST/PUT on invalid input).** A boundary MUST validate the handoff BEFORE any interaction with an external platform API, and MUST NOT issue any mutating call (POST/PUT/create/update) for an invalid platform or an unknown/invalid option. Boundaries are SAFE-BY-DEFAULT: they normalize only; a mutating external call requires explicit `--apply` AND a passed validation. A would-be mutating call that is stopped by validation emits the observable marker `external_call=blocked-validation-failed` and exits 2; a non-applied run emits `external_call=skipped-not-applied`; an authorized, validated run emits `external_call=apply-authorized` (the production network edge). Validation failure never reaches the external API.

**Contract B — plugin-standard normalized response.** Every boundary normalizes its DISTINCT native API response (AWS Well-Architected Tool risks, Azure Advisor recommendations, GCP Recommender insights) into ONE plugin-standard schema: `{schema_version, platform, source_api, validated, normalized:{recommendations:[{id, title, pillar, severity, source, mapped_concern, grounding}], native_review_ref}, build_units, iac_targets, applied}`. Each native finding maps to a grounded concern where possible (cite-or-decline: an unmappable finding is `grounding=needs_grounding`). `source` is `native-<platform>`; `source_api` names the vendor API.

**Vocabulary additions for §25 fidelity audit (§27.19):** `source_api`, `normalized`, `validated`, `applied`, `mapped_concern`, `external_call`, `severity`, `aws-well-architected-tool`, `azure-advisor`, `gcp-recommender`, `apply`.

**§20 note.** Contracts apply to the already-registered S-41..S-44; no new IDs or pending folders. Preserves the §21 definition-of-done.
