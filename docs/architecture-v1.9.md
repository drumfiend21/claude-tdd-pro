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

### §27.20 Toolchain alternatives survey (additive amendment, 2026-06-08)

Refines S-45: a category must not present a single tool. The advisor SURVEYS all viable alternatives across every cloud platform (platform-native + portable), annotates each with grounding (cite-or-decline) and platform-fit, and presents the full landscape so the developer can consider all options and choose. The S-45 primary recommendation is preserved (one of the alternatives).

**Authoritative ID introduced:** S-48 (Phase S, §4). No collision with §1–§27.19 IDs.

Standard-form bullet (for `^- \*\*[A-Z]-` grep traversal):

- **S-48** Toolchain alternatives survey (v1.14 refinement of S-45 — see §27.20). `commands/toolchain-advisor.sh` attaches to every recommendation an `alternatives[]` array surveying the field per category (e.g. observability: opentelemetry / prometheus-grafana / datadog / amazon-cloudwatch / azure-monitor / google-cloud-operations; gitops: argocd / flux; messaging: apache-kafka / rabbitmq / amazon-sqs-sns / azure-service-bus / google-pubsub; iac: terraform / cloudformation / bicep / pulumi / crossplane). Each alternative carries `{tool, platform_native, portable, source_id, grounding}`; `platform_native` is true when the tool is native to the target platform; grounded where a secured source backs it, else needs_grounding. The S-45 primary `tool` remains and appears among the alternatives.

**Vocabulary additions for §25 fidelity audit (S-48):** `alternatives`, `alternative`, `portable`, `survey`, `prometheus-grafana`, `flux`, `pulumi`, `crossplane`, `kubernetes`.

**Anti-drift note (S-48).** ID used verbatim. Pending folder name MUST be exactly: `evals/pending/s/s-48-toolchain-alternatives-survey/`.

**§20 sequencing (S-48).** M5 refinement, built immediately after S-45. Governance-only ID addition; preserves the §21 definition-of-done.

### §27.21 Plain-language toolchain alternatives (additive amendment, 2026-06-08)

Refines S-48: every surveyed alternative must be explained in plain business language (what it means for you and the trade-off), not only the technical name/rationale, so a non-technical founder can choose between options like "observability for AWS".

**Authoritative ID introduced:** S-49 (Phase S, §4). No collision with §1–§27.20 IDs.

Standard-form bullet (for `^- \*\*[A-Z]-` grep traversal):

- **S-49** Plain-language toolchain alternatives (v1.14 refinement of S-48 — see §27.21). `commands/toolchain-advisor.sh` attaches a `plain` business-language explanation to every alternative in `alternatives[]` (e.g. CloudWatch -> "AWS's built-in monitoring; works out of the box on AWS, keeps you on AWS"; OpenTelemetry -> "a vendor-neutral way to watch your system's health, so you are not locked to one monitoring vendor"). The `plain` text states the business meaning and the trade-off (managed vs self-run, native-lock-in vs portable, cost vs effort), alongside the existing `{tool, platform_native, portable, source_id, grounding}`.

**Vocabulary additions for §25 fidelity audit (S-49):** `plain`, `plain-language`, `trade-off`, `lock-in`.

**Anti-drift note (S-49).** ID used verbatim. Pending folder name MUST be exactly: `evals/pending/s/s-49-plain-language-toolchain-alternatives/`.

**§20 sequencing (S-49).** M5 refinement, built immediately after S-48. Governance-only ID addition; preserves the §21 definition-of-done.

### §27.22 Closed-loop decision package (additive amendment, 2026-06-08)

M6 capstone: closes the vision->implementation loop. Given the chosen option (S-34), its objective scores (S-46), and the toolchain (S-45), it produces ONE decided, enforceable decision package + a plain-language decision summary, and emits the next-step commands that feed S-28 (ADR), S-29 (build), S-30 (enforce). It reports whether the loop is closed (the choice is scored and has build requirements) or open (with the gap).

**Authoritative ID introduced:** S-50 (Phase S, §4). No collision with §1–§27.21 IDs.

Standard-form bullet (for `^- \*\*[A-Z]-` grep traversal):

- **S-50** Closed-loop decision package (v1.15 M6 — see §27.22). `commands/decision-package.sh`: reads the S-34 `architecture-options.json` + the S-46 `option-scoring.json` (+ optional S-45 `toolchain.json`), selects the chosen option (`--select`, default the scoring `recommended_option_id`), and emits a `decision-package.json` bundling `{chosen_option, objective_scores, toolchain_summary, next_steps:{adr_title, build_requirements, enforce_command}, loop_closed, gaps}` plus a plain-language `decision.md`. `loop_closed` is true only when the choice is scored and carries build requirements; otherwise `loop_closed=false` with the gap named. The next_steps feed S-28/S-29/S-30.

**Vocabulary additions for §25 fidelity audit (S-50):** `decision-package`, `decision`, `loop_closed`, `gaps`, `next_steps`, `objective_scores`, `toolchain_summary`, `enforce_command`, `chosen_option`.

**Anti-drift note (S-50).** ID used verbatim. Pending folder name MUST be exactly: `evals/pending/s/s-50-closed-loop-decision-package/`.

**§20 sequencing (S-50).** Week M6: ships after S-46 + S-45 (it bundles their outputs). Governance-only ID addition; preserves the §21 definition-of-done.

### §27.23 End-to-end integration validation (additive amendment, 2026-06-08)

The definition-of-done validation for the v1.13-v1.15 layered cloud-architect feature: a real common-case founder vision run through the ENTRY function (S-36 architect-session) and the full pipeline, producing a resulting cloud architecture for AWS, GCP, and Azure. It composes S-32 intake -> S-33 translate -> S-34 options -> S-46 scoring -> S-41 boundary dispatch -> S-42/S-43/S-44 boundary normalize -> S-45 toolchain -> S-50 decision package -> S-28 ADR -> S-29 build (red->green) -> S-30 enforce. No new feature ID (it validates the composition). Integration specs live at `evals/pending/integration/cloud-architect-e2e/` (promoted as `cl459-e2e-`).

**§20 note.** Pure validation of S-32..S-50; preserves the §21 definition-of-done (adds the end-to-end gate).

### §27.24 Observability and logging design (additive amendment, 2026-06-08)

Refines S-33/S-39 so the design evidences ROBUST logging and analysis of the deployed services, tailored to the user's needs (not just generic monitoring). A mission-critical workload gets SLO alerting; any compliance regime gets audit-log retention; regulated data gets access logging; event-driven or mission-critical systems get distributed tracing; every workload gets centralized logging. Grounded in OpenTelemetry / Google SRE / NIST 800-53.

**Authoritative ID introduced:** S-51 (Phase S, §4). No collision with §1–§27.23 IDs.

Standard-form bullet (for `^- \*\*[A-Z]-` grep traversal):

- **S-51** Observability and logging design (v1.14 refinement of S-33/S-39 — see §27.24). `commands/business-translate.sh` emits, under operational-excellence, tailored logging + analysis concerns: `centralized_logging` (always) and `distributed_tracing` (event-driven or mission-critical) grounded in `opentelemetry-docs`; `slo_alerting` (mission-critical) grounded in `google-sre-book`; `audit_log_retention` (compliance regime present) and `access_logging` (regulated/confidential data) grounded in `nist-800-53`. Each carries its business driver and grounding; the toolchain (S-45/S-48) then surveys the analysis stack (OpenTelemetry, Prometheus/Grafana, Datadog, cloud-native) per platform.

**Vocabulary additions for §25 fidelity audit (S-51):** `centralized_logging`, `distributed_tracing`, `slo_alerting`, `audit_log_retention`, `access_logging`, `observability`, `logging`, `analysis`.

**Anti-drift note (S-51).** ID used verbatim. Pending folder name MUST be exactly: `evals/pending/s/s-51-observability-and-logging-design/`.

**§20 sequencing (S-51).** M3 refinement; extends the translation layer. Governance-only ID addition; preserves the §21 definition-of-done.

### §27.25 Software-engineering design surfaces (additive amendment, 2026-06-08)

Extends S-33/S-39 so the cloud-architect designs the remaining world-class surfaces: testing (unit/integration/contract), dependency versioning and compatibility (futureproofing), authentication, authorization, object storage (data buckets), REST APIs, real-time sockets, and HTTP security headers/CORS. Each is a grounded concern under a dedicated pillar key, tailored to the profile. Grounded in newly secured authorities (Fowler test pyramid, SemVer, OAuth 2.0, OWASP ASVS, OWASP Secure Headers, Microsoft REST API Guidelines) plus existing NIST/EIP.

**Authoritative ID introduced:** S-52 (Phase S, §4). No collision with §1–§27.24 IDs.

**Sources secured (appended to `standards/cloud-engineering-sources.yaml`):** `fowler-test-pyramid`, `semver`, `oauth2-oidc`, `owasp-asvs`, `owasp-secure-headers`, `microsoft-rest-api-guidelines`.

Standard-form bullet (for `^- \*\*[A-Z]-` grep traversal):

- **S-52** Software-engineering design surfaces (v1.16 refinement of S-33/S-39 — see §27.25). `commands/business-translate.sh` emits, under dedicated pillar keys, grounded tailored concerns: `testing` (`unit_testing`, `integration_testing` always; `contract_testing` when services integrate) grounded in fowler-test-pyramid / enterprise-integration-patterns; `dependencies` (`dependency_pinning`, `automated_dependency_updates`, `compatibility_testing`) grounded in semver / google-eng-practices; `identity` (`authentication`, `mfa`, `authorization_rbac`, `token_validation`) grounded in oauth2-oidc / owasp-asvs / nist-800-53; `storage` (`object_storage_encryption`, `public_access_block`, `bucket_versioning`, `lifecycle_policy`) grounded in nist-800-53 / aws-well-architected; `api` (`rest_api_gateway`, `rate_limiting`, `request_validation`, `api_versioning`) grounded in microsoft-rest-api-guidelines / enterprise-integration-patterns; `realtime` (`websocket_gateway`, `connection_auth`) grounded in enterprise-integration-patterns / oauth2-oidc; `edge` (`security_headers`, `cors_policy`) grounded in owasp-secure-headers. New pillar keys do not disturb the five Well-Architected pillars consumed by S-34/S-29.

**Vocabulary additions for §25 fidelity audit (S-52):** `testing`, `unit_testing`, `integration_testing`, `contract_testing`, `dependencies`, `dependency_pinning`, `automated_dependency_updates`, `compatibility_testing`, `futureproofing`, `identity`, `authentication`, `mfa`, `authorization_rbac`, `token_validation`, `storage`, `object_storage_encryption`, `public_access_block`, `bucket_versioning`, `lifecycle_policy`, `api`, `rest_api_gateway`, `rate_limiting`, `request_validation`, `api_versioning`, `realtime`, `websocket_gateway`, `connection_auth`, `edge`, `security_headers`, `cors_policy`, `fowler-test-pyramid`, `semver`, `oauth2-oidc`, `owasp-asvs`, `owasp-secure-headers`, `microsoft-rest-api-guidelines`.

**Anti-drift note (S-52).** ID used verbatim. Pending folder name MUST be exactly: `evals/pending/s/s-52-software-engineering-design-surfaces/`.

**§20 sequencing (S-52).** v1.16 refinement of the translation layer. Governance-only ID addition; preserves the §21 definition-of-done.

### §27.26 Global delivery and frontend performance (additive amendment, 2026-06-08)

Extends S-33 so the cloud-architect designs the full-stack, international, UI-responsive surface a public consumer app needs: a CDN and edge caching for fast requests, a multi-region footprint with latency-based routing for international users, and frontend hosting with HTTP compression for UI responsiveness. Grounded in the AWS Well-Architected + Reliability Pillar authorities (already secured).

**Authoritative ID introduced:** S-53 (Phase S, §4). No collision with §1–§27.25 IDs.

Standard-form bullet (for `^- \*\*[A-Z]-` grep traversal):

- **S-53** Global delivery and frontend performance (v1.16 refinement of S-33 — see §27.26). `commands/business-translate.sh` emits, when the workload is public-facing (and at scale for the global concerns), grounded tailored concerns: under performance-efficiency `cdn` and `edge_caching` (aws-well-architected) for fast requests; under reliability `multi_region` and `latency_based_routing` (aws-reliability-pillar) for international users at scale; under a `frontend` pillar `spa_hosting` and `http_compression` (aws-well-architected) for UI responsiveness. Tailored to the profile; cite-or-decline grounded.

**Vocabulary additions for §25 fidelity audit (S-53):** `cdn`, `content_delivery_network`, `edge_caching`, `multi_region`, `latency_based_routing`, `frontend`, `spa_hosting`, `http_compression`, `global-delivery`, `ui_responsiveness`, `international`.

**Anti-drift note (S-53).** ID used verbatim. Pending folder name MUST be exactly: `evals/pending/s/s-53-global-delivery-and-frontend-performance/`.

**§20 sequencing (S-53).** v1.16 refinement of the translation layer. Governance-only ID addition; preserves the §21 definition-of-done.

### §27.27 Cloud-architect output conformance contract (additive amendment, 2026-06-08)

STANDING CONTRACT: every cloud-architecture design the plugin produces for a user MUST conform to the world-class, fully-cited standard proven by the end-to-end integration suite. Conformance criteria, enforced by cite-or-decline and gated by the integration tests:

1. **Every decision is cited.** Every emitted technical concern carries a `source_id` and `grounding=grounded`; the design has `needs_grounding=[]`. No decision is made on authority the plugin cannot cite.
2. **World-class authorities.** The sources cited are the secured tier-1 authorities (AWS Well-Architected + pillars, NIST 800-53/DoD SCCA, OWASP ASVS/Secure Headers, OAuth 2.0, SemVer, Fowler, Google SRE, OpenTelemetry, Microsoft REST API Guidelines, Enterprise Integration Patterns, Patterns of Distributed Systems, FinOps, Azure/AWS data + reliability guidance).
3. **Full-stack + cloud breadth.** A complete design spans frontend/UI, backend API, database, messaging, real-time, authentication/authorization, object storage, edge/headers, performance (CDN/edge), reliability/global delivery, security, observability (logging + analysis), testing, dependency versioning, distributed patterns, and cost.
4. **Tailored + optimized.** Concerns fire per the founder's profile; options are scored against cost/performance/customer/shareholder objectives (S-46).
5. **Test-first + enforceable.** Decisions become S-28 ADRs, S-29 red->green build units, and S-30 grounded convention enforcement.

**Golden reference (persisted):** `standards/golden/fullstack-international-aws-profile.json` (the canonical vision), `standards/golden/fullstack-international-aws-requirements.json` (the machine design), and `docs/golden/fullstack-international-aws-architecture.md` (the human, cited design). Regenerable deterministically; the conformance suite (`cl465-conformance-*`) pins it, and the integration suites (`cl459-e2e`..`cl464-e2e`) are the definition-of-done gate.

**§20 note.** Pure conformance contract over S-32..S-53; preserves the §21 definition-of-done (the integration suite is the gate).

### §27.28 S-30 cloud-convention enforcement wired into the /doctor surface (M6 completion, additive amendment, 2026-06-12)

Completes the M6 roadmap step "Wire S-30 enforcement into /doctor + CI" on the `/doctor` side. Detail + rationale: `docs/design/v1.17-s30-doctor-ci-wiring.md`. **No new feature ID** — refines the existing **S-30** (`commands/cloud-conventions.sh`, §27.13) and the `/doctor` surface (H-1/H-5/H-7). Honors the overview through-line "every enforcement runs in three execution surfaces with the same exit-code contract."

`commands/doctor.sh` gains a `--check cloud-conventions --root <dir>` arm (a new `case` arm; no existing arm/flag/default altered). It discovers IaC under the root (`.tf`→terraform, `.bicep`→bicep, `.json`/`.yaml`/`.yml` carrying `AWSTemplateFormatVersion`→cloudformation; ordinary JSON/YAML is never mistaken for IaC; discovery is recursive), runs the unchanged S-30 engine per file, and aggregates to the S-30 exit-code contract (0 green / 1 red; 2 usage).

**Safe-by-default (no-regression property):** a repo with no cloud IaC is a no-op — `cloud-conventions no_cloud_iac=true status=skipped`, exit 0 — so adding this check to any aggregate `/doctor`/CI run can never turn a previously-green non-cloud repo red.

**Observable markers (§27.28):** `cloud-conventions no_cloud_iac=true status=skipped` (exit 0); `cloud-conventions status=green files=<n> convention_violations=0` (exit 0); per-file `cloud-conventions file=<path> tool=<tool> status=red convention_violations=<n>` plus summary `cloud-conventions status=red files=<n> red=<r> convention_violations=<m>` (exit 1).

**§20 note.** Governance + substrate addition over the already-registered S-30 + `/doctor`; the CI (`closed-loop.yml`) half of M6 is staged for a follow-up CL and will call this same arm (`doctor.sh --check cloud-conventions --root .`). Preserves the §21 definition-of-done.

### §27.29 S-30 enforcement wired into the CI closed-loop surface + precise IaC detection (M6 completion, additive amendment, 2026-06-12)

Completes the CI half of M6 that §27.28 staged ("the CI (`closed-loop.yml`) half of M6 is staged for a follow-up CL"). Detail: `docs/design/v1.17-s30-doctor-ci-wiring.md`. **No new feature ID** — refines S-30 + the `/doctor` arm of §27.28 and the X-1 GitHub Actions surface.

`.github/workflows/closed-loop.yml` gains a step "Cloud-architecture convention enforcement (S-30 / §27.28)" running `bash commands/doctor.sh --check cloud-conventions --root .` (a new workflow step appended after the C-21 compliance step; no existing step/job altered). This realizes the through-line "every enforcement runs in three execution surfaces (Claude Code, pre-commit, CI) with the same exit-code contract" for cloud-convention enforcement.

**Precise CloudFormation detection (no-regression hardening).** The §27.28 `/doctor` arm now detects CloudFormation ONLY when `AWSTemplateFormatVersion` appears as a real top-level key at the start of a line (optionally after a leading brace, quoted or not), matching `^[[:space:]]*[{]?[[:space:]]*"?AWSTemplateFormatVersion"?[[:space:]]*:`. Files that merely MENTION the marker (documentation, test fixtures carrying an escaped `\"AWSTemplateFormatVersion\"` inside a string) are no longer misclassified as IaC. Discovery also prunes `.git/` and `node_modules/`. This makes `--root .` a true green no-op on this IaC-free repository, so adding the CI step cannot turn CI red.

**§20 note.** Completes M6 (the closed loop is now wired in all three surfaces). Governance + substrate addition over S-30 + §27.28 + X-1; preserves the §21 definition-of-done.

## §28. v1.18 — AI security & governance (EO-aligned) amendment (reference)

Additive amendment translating the White House executive order **"Promoting Advanced Artificial Intelligence Innovation and Security"** (signed 2026-06-02; Federal Register 2026-06-05) into faithful, registered plugin surface. The EO's posture is innovation-first and **voluntary** — its Sec. 1 expressly disclaims any mandatory licensing/preclearance — paired with stronger cyber defenses. Three operative sections map onto surfaces the plugin already owns: **Sec. 2 (Upgrading American Systems for Advanced AI)** — an AI Cybersecurity Clearinghouse focused on *finding and fixing software vulnerabilities*; **Sec. 3 (Secure Frontier Model Deployment)** — a voluntary framework for up-to-30-day pre-release government access subject to *confidentiality, cybersecurity, insider-risk, and IP protections*; **Sec. 4 (Protection Against Criminal Actors)** — prioritized criminal enforcement against AI-enabled cyber activity. This amendment **composes** existing primitives (§2.8 manifest, §2.9 control mapping, O-6 signed checkpoints, §2.24 audit-pack, S-2 fetchers, the §27.28/§27.29 three-surface enforcement pattern, cite-or-decline) into EO-aligned developer-side governance/engineering features; it invents no new engine and makes no government determination.

**Full design text — the authoritative source for this amendment's EO→mechanism mapping, requirement table, spec sketches, and ticket plan — lives at [docs/design/v1.18-eo-ai-security-governance.md](design/v1.18-eo-ai-security-governance.md).** This §28 is an additive reference block registering the canonical IDs, the §25-auditor vocabulary, and the anti-drift folder map here in the constitution (per `CLAUDE.md`); it delegates detail to the design file. No existing §1–§27 content is altered.

**Status:** PROPOSED. Reference block appended without modifying any prior section. The substrate-and-spec build proceeds per the design file's §28.4 sequencing only after operator ratification; the §25 fidelity gate reads this file, so the §28.6 vocabulary below is authoritative now.

**Ratified:** 2026-06-13 — operator approved ("Ratify + build S-54 now") after three convergent leadership-panel reviews. The PROPOSED status above is superseded by this additive note (per the append-only discipline, ratification is recorded as a new line, never by rewriting the prior one). Build commenced at S-54 (EO security-governance source catalog — the grounding fuel all other v1.18 features cite) per the §28.4 sequencing.

**Authoritative IDs introduced by v1.18:** H-14, H-15, H-16 (Phase H, §11); S-54 (Phase S, §4); C-22, C-23 (Phase C); X-10 (Phase X, §14); §2.30, §2.31, §2.32 (cross-cutting contracts, §2). No collision with §1–§27 IDs (H stopped at H-13; S at S-53; C at C-21; X at X-9; contracts at §2.29).

Standard-form bullets (for `^- \*\*[A-Z]-` grep traversal compatibility):

- **H-14** Dependency vulnerability scan + remediation gate (v1.18 — see design file §28.1). `commands/vuln-scan.sh` reads declared dependencies, matches an injected (deterministic) advisory dataset, classifies by CVSS severity, and gates per §2.30 (critical/high block, medium/low warn, clean ⇒ green no-op), naming the `fixed_in` remediation for each finding (the EO Sec. 2 find-and-fix loop). Grounded in cisa-ssdf / nist-800-53 (S-54). Reuses §2.2 exit-code contract + §2.4 `security` eval category.
- **H-15** SBOM generation + signed provenance attestation (v1.18 — see design file §28.1). `commands/sbom.sh` emits a CycloneDX (default) or SPDX SBOM for the build artifact and a SLSA-style signed provenance attestation binding the SBOM digest to the §2.8 AI Provenance Manifest (EO IP-protection). Reuses O-6 / H-4 signing-key trust model and the `slsa` namespace.
- **H-16** Frontier-model pre-release governance readiness checklist (v1.18 — see design file §28.1). `commands/frontier-eval.sh` emits an advisory, voluntary readiness scaffold for an org engaging the EO Sec. 3 framework: a cyber-capability self-assessment plus the four EO control families (confidentiality, cybersecurity, insider-risk, ip-protection) for the up-to-30-day pre-release window, each grounded in nist-ai-rmf (cite-or-decline; ungrounded ⇒ `needs_grounding`). A governance checklist, NOT a model evaluator; records the Sec. 1 no-mandatory-licensing disclaimer. Per §2.32.
- **S-54** EO security-governance source catalog (v1.18 — see design file §28.1). Secures + registers the EO authorities not already held into a new `standards/eo-security-sources.yaml`: `cisa-ssdf` (NIST SP 800-218), `nist-ai-rmf` (NIST AI 100-1), `slsa-framework`, `openssf-scorecard`, `cisa-kev`. NIST 800-53/171/RMF (already secured §27.14) are reused, not re-added. New namespace `security-governance`; the S-1 exactly-17-default-sources baseline is untouched (own catalog file, per the S-23/S-30/S-31 pattern).
- **C-22** EO control-mapping + national-security-systems compliance profile (v1.18 — see design file §28.1). Registers an EO control mapping in the §2.9 schema (`framework: eo-advanced-ai-2026`; `eo-sec2-*`/`eo-sec3-*`/`eo-sec4-*` controls) tying each EO directive to the plugin control that satisfies it (Sec. 2 ⇒ H-14/H-15; Sec. 3 ⇒ H-16/H-15; Sec. 4 ⇒ C-4 + L-14 misuse-resistant audit trail), cross-walked to nist-ai-rmf / cisa-ssdf / nist-800-53; adds a `national-security-systems` profile extending `government` (§2.5).
- **C-23** Coordinated vulnerability-disclosure evidence record (v1.18 — see design file §28.1). `commands/cvd-record.sh` produces a clearinghouse-style coordinated-disclosure record from H-14 findings (`{advisory_id, severity, component, fixed_in, disclosed_at, remediation_status, source}`) and feeds it into the C-4 audit log + §2.24 portable audit-pack for government/agency review. Reuses the L-14 audit-integration pattern.
- **X-10** Vulnerability + SBOM CI gate (v1.18 — see design file §28.1). Wires H-14 + H-15 into `.github/workflows/closed-loop.yml` and the `/doctor` surface with the same exit-code contract, mirroring §27.28/§27.29's S-30 wiring. Safe-by-default: a repo with no dependencies/IaC is a green no-op. Reuses the X-1 GitHub Actions surface.

**Cross-cutting contracts introduced (full text in the design file §28.2):**

- **§2.30 Vulnerability-remediation gate contract.** find→classify→remediate→record loop: `critical`/`high` ⇒ block (exit 1), `medium`/`low` ⇒ warn (exit 0 + marker), none ⇒ green no-op (exit 0). Safe-by-default: no resolvable manifest ⇒ `vuln-scan no_dependencies=true status=skipped` (exit 0). Every blocked finding names its `fixed_in` (the "and fix" half is mandatory). Findings recorded via C-23. Advisory dataset is injected (deterministic substrate); the live feed is a production edge (per the §27.19 external-call-safety discipline). Markers: `vuln-scan status=green deps=<n> vulnerabilities=0`; `vuln-scan component=<c> severity=<s> fixed_in=<v>`; `vuln-scan status=red critical=<n> high=<n>`.
- **§2.31 SBOM + signed-provenance attestation contract.** SBOM emitted in a named standard format (`cyclonedx` default | `spdx`) with `schema_version`, component inventory, content digest. The signed attestation binds `{sbom_digest, artifact_digest, builder, materials, signature}` and links to the §2.8 manifest; signing reuses O-6/H-4 key handling. An unsigned run is marked `attestation=unsigned` and never claims provenance. SLSA-level claims grounded in `slsa-framework` (cite-or-decline).
- **§2.32 Frontier pre-release governance contract.** The H-16 checklist MUST cover the four EO control families (`confidentiality`, `cybersecurity`, `insider_risk`, `ip_protection`) for the up-to-30-day pre-release window, each grounded (cite-or-decline) in a secured authority (nist-ai-rmf / nist-800-53); ungrounded ⇒ `needs_grounding`. Advisory and voluntary: emits no determination, sets no threshold, and records the EO Sec. 1 no-mandatory-licensing disclaimer in its header.

**Vocabulary additions for §25 fidelity audit (H-14..H-16 / S-54 / C-22 / C-23 / X-10 / §2.30 / §2.31 / §2.32):** `vuln-scan`, `vulnerability`, `remediation`, `remediation_status`, `fixed_in`, `cve`, `cvss`, `severity`, `critical`, `high`, `medium`, `low`, `advisory`, `advisory_id`, `no_dependencies`, `dependency`, `sbom`, `cyclonedx`, `spdx`, `attestation`, `provenance`, `signed`, `unsigned`, `signature`, `sbom_digest`, `artifact_digest`, `builder`, `materials`, `slsa`, `slsa-framework`, `openssf-scorecard`, `cisa-kev`, `cisa-ssdf`, `ssdf`, `nist-ai-rmf`, `ai-rmf`, `frontier`, `frontier-eval`, `covered-frontier-model`, `pre-release`, `confidentiality`, `cybersecurity`, `insider_risk`, `ip_protection`, `needs_grounding`, `voluntary`, `cvd-record`, `coordinated-disclosure`, `clearinghouse`, `eo-advanced-ai-2026`, `national-security-systems`, `nss`, `security-governance`, `eo-security-sources`.

**Anti-drift note (per `CLAUDE.md`).** The v1.18 IDs (H-14, H-15, H-16, S-54, C-22, C-23, X-10, §2.30, §2.31, §2.32) are canonical and must be used verbatim. Pending folder names MUST be exactly: `evals/pending/h/h-14-dependency-vulnerability-remediation-gate/`, `evals/pending/h/h-15-sbom-signed-provenance-attestation/`, `evals/pending/h/h-16-frontier-pre-release-governance-checklist/`, `evals/pending/s/s-54-eo-security-governance-source-catalog/`, `evals/pending/c/c-22-eo-control-mapping-and-nss-profile/`, `evals/pending/c/c-23-coordinated-vulnerability-disclosure-evidence/`, `evals/pending/x/x-10-vulnerability-and-sbom-ci-gate/`, `evals/pending/cross-cutting/2-30-vulnerability-remediation-gate-contract/`, `evals/pending/cross-cutting/2-31-sbom-signed-provenance-attestation-contract/`, `evals/pending/cross-cutting/2-32-frontier-pre-release-governance-contract/`. New catalog: `standards/eo-security-sources.yaml` (distinct from the S-1/S-23/S-30/S-31/S-37 catalogs; their invariants untouched).

**§20 sequencing (full table in the design file §28.4).** EO-deadline-anchored: S-54 first (secure the grounding fuel) → §2.30 + H-14 then C-23 (the Sec. 2 find-and-fix loop + evidence) → §2.31 + H-15 (SBOM/provenance) → §2.32 + H-16 (Sec. 3 readiness checklist) → C-22 (control mapping + NSS profile) → X-10 (three-surface CI wiring, mirroring §27.28/§27.29). Governance-only ID additions; preserve the §21 definition-of-done (extends surface, not gate).

### §28.8 Leadership-panel refinement (additive, 2026-06-13)

A four-persona engineering-leadership review (xAI / Microsoft / Amazon / Apple lenses) of the PROPOSED v1.18 surface endorsed building H-14/15/16 + provenance and recommended a focused set of additions. The architecture-faithful, EO-grounded, primitive-composing subset is registered here; the rest are refinements or explicitly deferred. Full text: design file §28.8. **Status:** PROPOSED. Append-only — no §1–§28.7 content altered.

**Authoritative IDs introduced by this refinement:** W-13 (Phase W, §15); Q-13 (Phase Q, §10). No collision with §1–§28.7 IDs (W stopped at W-12; Q at Q-12).

Standard-form bullets (for `^- \*\*[A-Z]-` grep traversal):

- **W-13** Adversarial red-team / blue-team review exercise (v1.18 refinement — see design file §28.8). `commands/redteam-review.sh` orchestrates a blue-team (defensive) + red-team (attacker) subagent pass over a generated artifact, producing a red-team summary pack that feeds the H-16 pre-release readiness checklist (EO Sec. 3 pre-release red-teaming) and the C-23 evidence record. Grounded in nist-ai-rmf red-teaming (S-54) + OWASP. Reuses W-11 parallel subagent orchestrator + existing review subagents + §2.3 findings format.
- **Q-13** Security-remediation posture metric (v1.18 refinement — see design file §28.8). Extends the §2.11 SPACE metric schema with a local-only (Q-6 privacy-by-default) security dimension: `mttr_to_remediate` (H-14 finding → C-23 `remediation_status=fixed`), `vulnerability_density` (findings per 1k deps), and percent-of-deps-with-known-fix-applied — making the EO Sec. 2 find-and-fix loop measurable. Reuses §2.11 + H-14/C-23 outputs.

**§2.31 refinement (no new contract).** The signed-provenance attestation additionally accepts an **in-toto** predicate alongside the SLSA-style predicate, and the signing mechanism may be **Sigstore/cosign** (keyless) in addition to the O-6 keyed checkpoint; the artifact names `predicate_type` + `signing_mechanism`; claims still cite-or-decline. CISA KEV "continuous monitoring" is the S-20 poll-scheduler + S-21 conditional-GET over the S-54 `cisa-kev` source (composition, no new engine), read by H-14 as one advisory input.

**Explicitly NOT adopted (flagged per the drift catalog).** A gate-bypassing "exploration mode" is REJECTED — it contradicts the F-gate / append-only law; the legitimate velocity intent is honored by throwaway-branch spikes that MUST still reconcile to the manifest before merge (gate deferred in time, never skipped). Any true bypass is a constitution-level governance CL, not a v1.18 feature. Differential-privacy / data-minimization is deferred to a separate Phase-E/G rules CL.

**Vocabulary additions for §25 fidelity audit (W-13 / Q-13 / §2.31 refinement):** `redteam-review`, `red-team`, `blue-team`, `adversarial`, `red-team-pack`, `mttr`, `mttr_to_remediate`, `vulnerability_density`, `posture`, `security-posture`, `in-toto`, `predicate_type`, `signing_mechanism`, `sigstore`, `cosign`, `keyless`.

**Anti-drift note (W-13 / Q-13).** IDs used verbatim. Pending folder names MUST be exactly: `evals/pending/w/w-13-adversarial-red-team-blue-team-review/`, `evals/pending/q/q-13-security-remediation-posture-metric/`.

**§20 sequencing (W-13 / Q-13).** Both ship after their inputs: W-13 after H-16 + C-23; Q-13 after H-14 + C-23 — slotting at the end of the §28.4 order, after X-10. Governance-only ID additions; preserve the §21 definition-of-done.

### §28.9 Leadership-panel refinement, round 2 (additive, 2026-06-13)

Second-round review (A/A+/A/A- scores) converged on "ratify and build, S-54 first → H-14 → C-23" and added only micro-refinements — **zero new feature IDs** (restraint over inventing IDs to look responsive). Full text: design file §28.9. **Status:** PROPOSED. Append-only — no §1–§28.8 content altered.

**Refinements (no new ID):** (a) H-16/W-13 — the §28.8 throwaway-branch-with-mandatory-reconciliation pattern is the sanctioned mode for internal frontier pre-release red-team spikes (no skip-gate flag; the §28.8 rejection stands). (b) Q-13 gains a **STRIDE threat-model coverage score** (from W-13 red/blue findings, reusing the multi-agent review output — no new engine) + deployment-frequency/security-score trend lines in COMPLIANCE-REPORT; local-only per Q-6; ties to §2.5 `aibom` + §2.8 manifest. (c) W-13/H-16 gain lightweight **data-minimization checklist items** grounded in nist-800-53 (full differential privacy stays deferred to a Phase-E/G rules CL). (d) W-13 may target an O-12 scaffold for a critical-infrastructure resilience pass (composition, no new scaffold engine).

**Standing framing rule (extends §2.32 artifact-wide).** The §2.32 voluntary / non-mandatory framing (the EO Sec. 1 no-mandatory-licensing disclaimer) is a standing requirement for **every** v1.18 artifact — W-13 packs, C-22/C-23 exports, H-15 attestations all carry the disclaimer header. No new contract number; applies the existing §2.32 framing across the artifact set.

**Vocabulary additions for §25 fidelity audit (§28.9):** `stride`, `threat-model`, `threat_model_coverage`, `deployment_frequency`, `security_score`, `data-minimization`, `data_minimization`, `pii`, `resilience`, `disclaimer`, `non-mandatory`.

**§20 note.** Governance-only refinement; preserves the §21 definition-of-done. The convergent build order (ratify → S-54 → H-14 → C-23) matches §28.4 exactly; the first build CL on ratification is S-54.

### §28.10 Plugin-wide scope (standing clarification, 2026-06-13)

**STANDING CLARIFICATION (operator-requested): the entire v1.18 EO surface applies to ALL code the plugin develops — every full-stack / normal software-development workflow — NOT only the cloud-architect (S-20..S-53) lane.** The recent architecture growth happened to be cloud-architect-heavy, so this note removes any inference that §28 inherits that lane. It does not. Evidence, by construction:

1. **Phase placement is cross-cutting, not the S application lane.** The v1.18 features live in the hardening (H-14/15/16), compliance (C-22/23), execution-surface (X-10), workflow (W-13), and SPACE-measurement (Q-13) phases — the phases that, per §1/§2, *touch all layers*. The only Phase-S item, S-54, is a **grounding source catalog** consumed by all of them, not a cloud-architect application feature. The three new contracts §2.30/§2.31/§2.32 are **cross-cutting contracts** (the §2.X namespace explicitly "touch all layers").
2. **Targets are general full-stack, every first-class language.** H-14 scans `package.json`/`package-lock.json`, `requirements.txt`, `go.mod`, `Cargo.toml` (JS/TS, Python, Go, Rust — the plugin's first-class languages per H-5), i.e. any application/library/service the plugin builds. H-15 SBOMs "the build artifact" of any project. The single "IaC" mention in this block (X-10's "no dependencies/IaC ⇒ green no-op") is a *no-regression safety* statement (works on any repo, including ones with neither), not a scope restriction.
3. **Same three-surface enforcement as every other gate.** X-10 wires H-14/H-15 into `/doctor` + the closed-loop CI for the *whole repository*, under the project through-line "every enforcement runs in three execution surfaces (Claude Code, pre-commit, CI) with the same exit-code contract" (§1). The EO find-and-fix loop, SBOM/provenance, and red/blue review therefore run on a React app, a Node service, a Python library, or a Terraform module alike.
4. **Composition with the universal TDD build loop.** W-13 reviews "a generated artifact" (any artifact); Q-13 measures remediation posture across the whole project via the §2.11 SPACE schema; C-22/C-23 map and evidence compliance for the whole codebase. None is conditioned on a cloud workload, an S-32 business profile, or an S-28 ADR.

**Consequence for the build:** when each remaining v1.18 feature is implemented, its specs MUST demonstrate it operating on a *non-cloud, ordinary full-stack* target (e.g. a JS/TS or Python app) — not only a cloud/IaC fixture — so this plugin-wide scope is proven by the active suite, not merely asserted here. No existing §1–§28.9 content is altered by this clarification (append-only).

### §28.11 EO governance applied to the Cloud Architect feature (standing requirement, 2026-06-13)

**STANDING REQUIREMENT (operator-directed): the same EO governance, patterning, process, and quality checks bind the Cloud Architect feature (S-20..S-53) as bind every other code type.** §28.10 established that v1.18 reaches all full-stack code (cloud included by phase placement); this section is the symmetric, *active* obligation — because the cloud-architect lane uniquely **produces** software (S-28 ADR → S-29 IaC build unit → S-30 convention enforcement), the EO surface must be wired *into that pipeline*, not merely inherited. Full text: design file §28.11. **Zero new feature IDs** (refinements of S-30/S-29/§27.27 per the §27.14 dod-zero-trust precedent; S-55 reserved if a dedicated EO-cloud-governance orchestrator later proves necessary). **Status:** the convention ruleset + gate composition are named build deliverables (PROPOSED, build on the same per-CL approval as the rest of v1.18); the conformance obligation is binding now. Append-only — no §1–§28.10 content altered.

1. **Patterning (design).** A new EO-grounded S-30 convention ruleset `standards/cloud-conventions/eo-security.yaml` (an S-30 refinement, exactly like §27.14's `dod-zero-trust.yaml` / `observability.yaml` — no new ID) grounded in the S-54 sources: `require` provenance/SBOM attestation + digest-pinned images + KEV-free dependencies; `forbid` known-exploited components (cisa-kev) + unsigned artifacts. Enforced via the existing S-30 `cloud-conventions.sh --ruleset`. The S-33/S-39/S-51/S-52 translation also emits EO-grounded security concerns (supply-chain integrity, remediation SLA, SBOM/provenance, KEV monitoring) for cloud workloads, cite-or-decline grounded in S-54.
2. **Process (build).** The S-29 cloud-build gate **composes with** the §2.30 H-14 vulnerability gate and the §2.31 H-15 SBOM/provenance: an IaC build unit is RED until it passes conformance AND `cloud-conventions` (existing) AND the EO vuln-clean/provenance gates — the same test-first red→green discipline the plugin applies to every artifact.
3. **Quality checks.** W-13 red/blue adversarial review runs over S-26 pillar reviews and S-29 build units (incl. critical-infrastructure O-12 scaffolds per §28.9); Q-13 measures the cloud project's remediation posture; C-22/C-23 map + evidence the cloud design's EO compliance (reusing the already-secured NSS/DoD authorities: nist-800-53, aws-dod-scca-prescriptive, the dod-zero-trust convention).
4. **Conformance contract extension (binding).** The §27.27 cloud-architect output-conformance contract is EXTENDED: every cloud design the plugin produces MUST additionally pass the EO governance gates — vuln-clean-or-remediation-tracked (§2.30), SBOM + provenance present (§2.31), EO conventions enforced (eo-security ruleset), and red/blue reviewed (W-13). This is the symmetric mirror of §27.27's "world-class, fully-cited" gate, now including EO security governance.
5. **Symmetric build obligation (mirror of §28.10).** Each remaining v1.18 feature's spec set MUST ALSO include at least one behavior on a **cloud/IaC target** (a Terraform/Bicep fixture), so BOTH lanes — ordinary full-stack (§28.10) AND cloud-architect (§28.11) — are proven by the active suite. Every remaining v1.18 feature is therefore proven on a non-cloud app fixture and a cloud/IaC fixture.

**Vocabulary additions for §25 fidelity audit (§28.11):** `eo-security`, `supply-chain`, `supply_chain_integrity`, `digest-pinned`, `image-pinning`, `kev-free`, `known-exploited`, `unsigned-artifact`, `attestation-required`, `remediation_sla`.

### §28.12 Build progress log (append-only)

Tracks the v1.18 substrate build as each CL lands (per §28.4). Append-only; never rewrite a prior line.

- **CL-469 — S-54 EO security-governance source catalog.** `standards/eo-security-sources.yaml` (cisa-ssdf, nist-ai-rmf, slsa-framework, openssf-scorecard, cisa-kev) + 10 specs. Suite 4175→4185. (2026-06-13)
- **CL-470 — §2.30 + H-14 dependency vulnerability scan + remediation gate.** `commands/vuln-scan.sh` (the EO Sec. 2 find-AND-fix gate) + 10 specs. Both lanes proven per §28.10/§28.11: app manifests (package.json, requirements.txt, go.mod, Cargo.toml) AND cloud IaC supply chain (`.terraform.lock.hcl` provider pins). critical/high block, medium/low warn, clean green no-op, no-manifest skipped; every blocked finding names `fixed_in`; `--emit` writes the C-23 disclosure record. Suite 4185→4195. (2026-06-13)
- **Remaining (per §28.4):** C-23 (consume H-14 `--emit`), §2.31 + H-15, §2.32 + H-16, C-22, X-10, W-13, Q-13, and the §28.11 `standards/cloud-conventions/eo-security.yaml` S-30 ruleset.
- **CL-471 — §28.11 EO-catalog import into the architecting + coding engines.** (1) Architecting: `commands/cloud-conventions.sh` (S-30) extended to import `standards/eo-security-sources.yaml` as a third grounding catalog (additive `--eo-catalog`, default-on; only expands the grounded id set — no-regression) + new ruleset `standards/cloud-conventions/eo-security.yaml` grounded SOLELY in the EO authorities (require provenance/digest-pin/scan; forbid open-ingress/`:latest`). (2) Coding: new `security-governance` namespace registered in `generated-code-quality-standards/validate-all.sh` + 5 reading-source files importing the EO authorities into the coding standards directory. The cl437-s31-10 "every shipped ruleset grounded" spec was extended to include the EO catalog (mirrors the engine's new 3-catalog grounding; still fails if any ruleset cites a source in none of the three). + 10 specs (6 architecting, 4 coding). Suite 4195→4205. (2026-06-14)
- **Remaining (as of CL-471, supersedes the §28.4 line above):** C-23 (consume H-14 `--emit`), §2.31 + H-15, §2.32 + H-16, C-22, X-10, W-13, Q-13.
- **CL-472 — §2.33 universal citation-conformance auditor + spec battery.** `rubric/detectors/audit-citation-conformance.sh` (deterministic, `--root`, exit 0/1/2; per-surface `citation-conformance surface=<s> status=<green|red> items=<n> ungrounded=<m>` markers) audits 5 producing surfaces — cloud-conventions (grounded in the 3 cloud catalogs), coding-rules (provenance), reading-sources (source header), the 3 registries, the 3 cloud catalogs. Green on the real tree (cloud-conventions 22, coding 28, reading-sources 17, registries 3, catalogs 3). + 15 specs: 6 surface-green + 3 per-cloud-catalog grounding (S-23/S-30/S-54) + 3 per-registry (STANDARDS/COMPLIANCE/PR-CORPUS) + 3 negative paths (injected ungrounded rule / missing provenance / missing reading-source header caught red). Suite 4205→4220. (2026-06-15)

### §28.13 Universal citation-conformance — contract §2.33 + deepened spec battery (operator-directed, 2026-06-15)

**STANDING CONTRACT (operator-directed): every artifact the plugin PRODUCES — full-stack and cloud, architecture and design and code — must conform to cited rules drawn from the plugin's authoritative sources, across ALL of them.** This generalizes the §25 pending-spec fidelity gate, the §27.27 cloud-output conformance contract, and the S-30/S-8 cite-or-decline discipline into ONE standing invariant over every producing surface, enforced by a deterministic auditor plus a widened+deepened active-suite spec battery. Full text + surface map: design file §28.13. **No new feature ID** (a conformance gate over existing producing surfaces, like the §25 `audit-pending-spec-fidelity.sh`). New cross-cutting contract **§2.33** (next free; contracts stopped at §2.32). **Status:** building.

- **§2.33 Universal citation-conformance contract.** Every artifact the plugin produces MUST cite a grounded source drawn from one of the plugin's authoritative source systems, spanning BOTH source triads: (i) the three operator registries — **STANDARDS**, **COMPLIANCE**, **PR-CORPUS** (the §1 through-line: full-stack coding rules, regulatory controls, peer-review patterns); and (ii) the three cloud grounding catalogs — **cloud-architecture (S-23)**, **engineering (S-30/S-31)**, **EO-security (S-54)** (cloud architecting/design/build). Producing surfaces in scope: G-directory coding rules (`provenance[]` with a `source`/`class`), cloud-convention rules (`source_id` ∈ the 3 catalogs), translated design concerns + architect recommendations + ADRs (`source_id`, else `needs_grounding`), and vulnerability findings (`source`). **cite-or-decline is universal:** an artifact citing no grounded source is `needs_grounding`/declined, never silently emitted. Enforced by `rubric/detectors/audit-citation-conformance.sh` (deterministic, `--root <dir>`, exit 0 green / 1 red / 2 usage; per-surface `citation-conformance surface=<s> status=<green|red> ...` markers) and a deepened active-suite spec battery that covers full-stack AND cloud across both triads, including negative paths (an injected ungrounded artifact must be caught).

**Vocabulary additions for §25 fidelity audit (§28.13 / §2.33):** `citation-conformance`, `citation`, `cited`, `conformance`, `grounded_source`, `producing-surface`, `registry`, `standards-registry`, `compliance-registry`, `pr-corpus`, `provenance`, `needs_grounding`, `cite-or-decline`, `ungrounded`, `surface`.

**§20 note (§28.13).** Conformance-hardening over the existing producing surfaces; preserves the §21 definition-of-done (the auditor + battery extend the active-suite gate, they add no new product feature). Governance + test/audit substrate.

### §28.14 Generative-function integration tests — the non-technical-user journey (operator-directed, 2026-06-15)

**STANDING REQUIREMENT (operator-directed): every generative function the plugin exposes — across BOTH cloud architecture AND full-stack development — is exercised by an end-to-end integration test that simulates a NON-TECHNICAL user describing a unique software use case, and asserts the plugin delivers world-class software satisfying that use case.** Extends §27.23 (the existing cloud-architect E2E validation) and §27.27 (the world-class output-conformance contract); generalizes them from a single golden vision to a SET of diverse non-technical-user scenarios that each exercise DIFFERENT tailored outputs. Full text + scenario matrix: design file §28.14. **No new feature ID** (integration validation, like §27.23). **Status:** building.

**The integration contract.** Each scenario starts from a plain-language vision a non-technical founder could state (no architecture vocabulary) and drives the generative pipeline end-to-end — intake (S-32) → translate (S-33 + the S-51/S-52/S-53 full-stack surfaces) → recommend (S-34) → optimize (S-46) → review (S-26) → ADR (S-28) → build (S-29) → conventions (S-30, incl. the §28.11 EO ruleset) → toolchain (S-45/S-48/S-49) → decision-package (S-50), with the S-36 architect-session orchestrator as the entry. The test asserts the delivered design is: **tailored** (the scenario's unique inputs fire the scenario-specific concerns — e.g. regulated data ⇒ audit logging; public + at-scale ⇒ CDN/multi-region; payments ⇒ encryption + compliance), **fully cited** (passes the §2.33 citation-conformance auditor and §27.27's "every decision cited / needs_grounding=[]"), **full-stack + cloud in breadth** (frontend, API, database, auth, storage, messaging, observability, testing, dependencies AND cloud infra), **secure** (the EO governance gates of §28.10/§28.11 hold), and **test-first** (decisions become S-28 ADRs + S-29 red→green build units). Scenarios span distinct domains (e.g. healthcare booking, e-commerce storefront, fintech payments, two-sided marketplace, low-budget content site) so tailoring — not a single fixed template — is what is proven.

**Vocabulary additions for §25 fidelity audit (§28.14):** `integration-test`, `end-to-end`, `e2e`, `non-technical`, `founder`, `vision`, `use-case`, `tailored`, `world-class`, `scenario`, `journey`, `delivered`, `healthcare`, `e-commerce`, `fintech`, `marketplace`.

**§20 note (§28.14).** End-to-end validation over the already-built S-32..S-53 + EO surfaces; preserves the §21 definition-of-done (extends the active-suite gate with integration scenarios; adds no new product feature). Composes existing generative commands — no new engine.

**Build progress (§28.14).** **CL-474 — persisted end-to-end demonstration + front-page surfacing.** `examples/dog-walker-marketplace/` ships the full walkthrough (README), the real regenerable artifacts (`artifacts/01..08`: profile → 51-concern cited requirements → options → scoring → explanation → decision-package → MADR ADR), and `regenerate.sh` (deterministic, `--out` hermetic). Surfaced as one of the first things in the docs: a callout under the README tagline (before Quick Start) + the first item in `docs/getting-started.md` + an `examples/README.md` index. 5 demo-pinning specs (`cl474-demo-01..05`: regenerates fully-cited / committed design cited / loop closed / surfaced from front page / ADR grounded+accepted). Suite 4236→4241. (2026-06-15)

**Build progress (§28.14).** **CL-473 — generative-function integration suite.** 16 end-to-end specs (`cl473-e2e-01..16`) driving the real pipeline (`architect-session` → translate → recommend → optimize → decision-package → cloud-build) from plain-language non-technical founder visions across 5 diverse domains: healthcare booking (HIPAA), e-commerce storefront (public/hyperscale), fintech payments (PCI), event-driven marketplace, low-budget content site. Proves tailoring (17 concerns for the simple site vs 43–47 for regulated/hyperscale apps), full citation (`needs_grounding=0` every scenario), cloud + full-stack breadth (≥10 pillars incl. api/testing/identity/frontend), the vision→implementation loop closing (`loop_closed=true`), test-first IaC (`conformance=red` until built), and plain-language explanation. Suite 4220→4236. (2026-06-15)

### §28.15 Cloud/EO guidance → enforced detector rules — Layer-A activation (operator-directed, 2026-06-15)

**STANDING ACTIVATION (operator-directed): the cloud/governance namespaces are promoted from rule-empty GUIDANCE corpora into first-class, grounded, ESLint-style enforced DETECTOR rules.** The namespaces `aws`, `azure`, `gcp`, `hashicorp`, `linux-foundation`, `security-governance`, `us-government` ship reading-source guidance (`rules: []`) per the §27 S-23 note — that guidance *grounds* `/architect` (Layer C) and the `standards/cloud-conventions/*.yaml` rulesets *enforce* IaC (Layer B). This amendment adds **Layer A**: write-time detector rules inside those namespaces themselves, so the source authorities (AWS WAF, Azure WAF, GCP, HashiCorp, CNCF, CISA/NIST SSDF/KEV/SLSA, NIST Zero-Trust/DoD SCCA) enforce as ESLint-style hierarchical rules. **No new feature ID** — this is the existing **S-7 promotion** producing **§2.1** rules run by a **§2.2** detector; full detail: design file §28.15. **Status:** building.

**Mechanism.** `commands/promote-cloud-rules.sh` generates, from ONE manifest (single source of truth → no drift): (i) a §2.1 rule file `generated-code-quality-standards/<ns>/<ns>-iac-enforcement.yaml` per namespace, each rule citing an authoritative source via `provenance` and naming the shared detector `cloud-guidance-rule.sh`; and (ii) the detector's check table `rubric/detectors/cloud-guidance-rules.json`. The detector `rubric/detectors/cloud-guidance-rule.sh` (§2.2: `--rule <id> [--paths <glob>] [--root <dir>] [--json]`; exit 0 green / 1 findings / 2 usage) enforces each rule's `require`/`forbid` token over the files it applies to. Deterministic + idempotent (re-run yields byte-identical files).

**Non-regressive (additive only).** The reading-source GUIDANCE files are PRESERVED untouched (`rules: []`) — guidance (Layer C) and enforcement (Layer A) coexist; no §27 S-23 content is removed. The existing 28 code-detector rules are unchanged. The promoted rules appear in the §2.33 citation-conformance `coding-rules` surface and pass (each carries `provenance`); the auditor stays green (coding-rules 28 → 42, all grounded). The `standards/cloud-conventions` Layer-B enforcement (§27.13/§28.11) is unchanged.

**Vocabulary additions for §25 fidelity audit (§28.15):** `promote-cloud-rules`, `cloud-guidance-rule`, `cloud-guidance-rules`, `iac-enforcement`, `layer-a`, `activation`, `promoted`, `detector-rule`, `enforced`, `guidance-corpus`, `required_version`, `required_providers`, `livenessProbe`.

**§20 note (§28.15).** S-7 promotion over the already-secured cloud/EO source corpora; preserves the §21 definition-of-done (extends enforcement surface; reuses §2.1/§2.2/S-7, adds no new product feature). Composes with §2.33.

### §28.16 Install-surface fixes from downstream (GCTP) install testing (2026-06-15)

A downstream consumer (GCTP) ran a clean-machine install test and routed CTP-side findings upstream. Fixed here (CL-476), test-pinned, no regression:

- **P-1 — bash 3.2 empty-array crash (`scripts/install.sh`).** `detect_conflicts` ended with `printf '%s\n' "${conflicts[@]}"`; under `set -u` on stock-macOS **bash 3.2**, an empty `conflicts` array raises "unbound variable" and aborts the installer before clone. Guarded on `${#conflicts[@]} -gt 0` (project bash-3.2 portability gotcha #5). A clean target now reports no conflicts and exits 0; a real conflict is still reported.
- **P-3 — `/architect` is now a real slash command.** The architect feature shipped `commands/architect.sh` + `skills/architect` + `agents/architect.md` but **no `commands/architect.md`**, so `/architect` was not a slash command (a docs/usage inaccuracy the install test surfaced). Added `commands/architect.md` (loads the `architect` skill, mirroring `onboard.md`), making `/architect` first-class.
- **P-2 — ruby preflight** was verified ALREADY correct: `preflight_check` hard-stops (`exit 3`) on ruby `<3.0` or missing. No change.

5 specs (`cl476-p1-01..03`, `cl476-p3-01..02`). Governance + bugfix; no new feature ID / contract. Suite 4253→4258.

### §28.17 External-tree enforcement entrypoint ("Fix E") + downstream (GCTP) consumption contract (2026-06-15)

A downstream consumer (GCTP) built a real O'Reilly-kata submission and found that only IaC was *actually* enforced by CTP detectors; the TypeScript was scoped to two rules and never re-run (asserted, not enforced). Root causes split CTP-side ("Fix E/F/G") and consumer-side ("Fix A–D", not in this repo). CL-477 ships **Fix E** — the stable contract surface a consumer calls to enforce CTP detectors against an external app tree. Incorporates four corrections GCTP verified that are invisible from inside CTP:

- **`rubric/enforce.sh`** (new): `--root <app-dir> --rule <id>… | --rules <csv> [--paths <glob>] [--json]`. Resolves each rule id → detector and runs it against the external tree; exit `0` all-pass / `1` ≥1 fail / `3` incomplete (≥1 not-enforced, no fail) / `2` usage.
- **Correction 1 — dispatch by the `generated-code-quality-standards/` catalog, NOT `RUBRIC.yaml`.** The bare ids collide: `g-ts-001` = `no-any.sh` in the standards catalog (what a consumer holds via `active.json`) but `g-ts-001-naming-style` in `RUBRIC.yaml`. `enforce.sh` builds its id→detector map from `generated-code-quality-standards/` so a consumer's `applicable_rules` dispatch matches; keying on `RUBRIC.yaml` would be a silent false-green/red class.
- **Correction 2 — tri-state per rule (`pass | fail | not_enforced`).** A detector that could not run (tool absent / not-applicable / deferred → detector exit `3` or other) is reported `not_enforced`, never collapsed into a pass; the entrypoint's exit `3` (incomplete) is distinct from `1` (fail) so a consumer can tell *clean* from *un-run*.
- **Correction 3 — generalizes the proven `cloud-guidance-rule.sh --rule <id> --root <dir>` contract** (the §28.15 cloud detector, the one tree that *was* enforced) up to a dispatcher over all detectors; cloud/EO rules route through their `--rule/--root` convention, code detectors through `--paths`.
- **Correction 4 (for Fix F, not yet built)** — any new doc/prose detectors MUST be emitted into `generated-code-quality-standards/` with an `id` + `source_namespace` so `standards-sync` carries them into `active.json`; otherwise a consumer can never scope them into `applicable_rules`.

8 specs (`cl477-e-01..08`): external-tree run; catalog dispatch (g-ts-001→no-any, g-ts-006→type-test-coverage — the collision proof); clean pass; tri-state not_enforced; cloud-rule generalization; per-rule verdicts; unknown-rule + missing-root usage errors. No new feature ID / contract (reuses §2.2 detectors). **Remaining CTP-side:** Fix F (prose/Markdown/Python detectors flowing through the standards catalog — recommended) and Fix G (the `no-any` comment/string false positive). Consumer-side (NOT this repo): Fix A decompose-union, Fix B inner-loop runs `enforce.sh`, Fix C dynamic re-run gate, Fix D `app_root` model. Suite 4258→4266.

### §28.18 `enforce.sh` 4-state verdict + `files_evaluated` (vacuous-green fix; freezes the Fix-E contract, 2026-06-15)

The downstream consumer (GCTP) found the CL-477 tri-state was insufficient: a detector that *ran but matched no files* exits 0 → reported `pass` — a **vacuous green** indistinguishable from a real clean pass (verified: `g-ts-001` on a `.tf`-only tree, and an EO cloud rule on a pure-`.ts` tree, both returned `pass`). That is the same false-green disease the whole effort targets, one layer down. CL-478 closes it and **freezes the `enforce.sh` contract** that the consumer's Fix B/C build against.

- **Four verdict states per rule** (was three): `pass` = ran AND ≥1 file evaluated AND 0 findings · `fail` = ≥1 finding · **`not_applicable`** = 0 files matched the rule's scope (NEUTRAL, distinct from pass) · `not_enforced` = files existed but the detector could not verify (tool/model absent) → RED. `enforce.sh` determines applicability by **counting matching files itself** (robust; not by overloading the detector exit-3).
- **`files_evaluated` count per rule** in the stderr marker + `--json`, so a consumer's re-run gate can assert *every green rule actually touched a file* — "pass" is now falsifiable.
- **EO semantics (agreed on the record):** EO rules use `cloud-guidance-rule.sh`'s IaC `applies` glob, so on a pure-code ticket they return `not_applicable` ("EO-by-attestation covers the rest"), never a vacuous green and never red.
- **Aggregate exit:** `0` iff every rule is `pass` or `not_applicable`; `1` any fail; `3` no fail but ≥1 `not_enforced` (never collapses to success); `2` usage/unknown. Markers: `enforce rule=<id> detector=<d> verdict=<v> files_evaluated=<n>` + `enforce status=<green|red|incomplete> pass=<> fail=<> not_applicable=<> not_enforced=<>`.

5 specs (`cl478-01..05`) + `cl477-e-03` updated to the 4-state meaning. No new feature ID / contract. Suite 4266→4271.

### §28.19 `no-any` comment/string false-positive fix ("Fix G", 2026-06-15)

The kata build reported the TypeScript "fails `no-any`" — but the single finding was on a *comment* (`// Fail-closed: any policy error…`): the grep `:[[:space:]]*any\b|<any>|as[[:space:]]+any\b` matched `: any` inside the comment text (0 real `any` annotations in the code; corroborated by GCTP's independent run). CL-479 strips `//` line comments (`sed 's,//.*,,'`, preserving line numbers) before the three `: any` greps (quick-filter, count, per-line) so a `: any` / `as any` / `<any>` inside a `//` comment is never a finding; real `x: any` annotations and the `// allow-any:` affordance are unchanged. Net: the kata `confidence_gate/index.ts` now passes `no-any` (`enforce --rule g-ts-001` → `verdict=pass`), removing inflated non-conformance.

3 specs (`cl479-g-01..03`: ignores comment any · still flags real any · allow-any still suppresses). Detector-precision fix; no new feature ID / contract. **CTP-side remaining after this: Fix F only** (prose/Markdown detectors flowing through the standards catalog per §28.17 Correction 4). Suite 4271→4274.

### §28.20 Prose enforcement — ADR structural + citation detectors ("Fix F"; completes the CTP-side scope, 2026-06-15)

The kata showed CTP enforced code + IaC but **prose** (the ADRs/docs that are most of an architecture submission) had *no* detectors — it could only be cited, never content-enforced. CL-480 ships **option 1** (agreed with GCTP): structural prose detectors emitted **through `generated-code-quality-standards/`** so a consumer can scope them (§28.17 Correction 4).

- **`rubric/detectors/adr-structure.sh`** (§2.2): an ADR must carry the MADR sections Status / Context / Decision / Consequences. Self-scopes to ADR files (`^[0-9]{4}-[a-z0-9-]+\.md$`, per §2.16) so an ordinary README is never flagged.
- **`rubric/detectors/doc-citation-presence.sh`** (§2.2): every ADR must reference ≥1 grounding source (the mechanical floor of cite-or-decline on prose; substance — "did not invent the architecture" — stays a decision-level cross-check, not a detector).
- **`documentation` namespace:** `generated-code-quality-standards/documentation/{madr.yaml (reading-source), doc-enforcement.yaml}` with rules **`g-doc-001`** (→ adr-structure) and **`g-doc-002`** (→ doc-citation-presence), grounded in the `madr` authority (provenance) so they pass the §2.33 citation auditor (coding-rules 42→44) and reach `active.json`. `documentation` registered in `validate-all.sh KNOWN_NAMESPACES`; `enforce.sh` maps `g-doc-*` → `*.md`.
- Verified against the kata's real 14 ADRs: `enforce --root docs/adr --rule g-doc-001 --rule g-doc-002` → both `pass` (files_evaluated=14) — prose is now enforced through the same external-tree contract; a malformed/uncited ADR is red; code-only trees are `not_applicable`.

6 specs (`cl480-f-01..06`). No new feature ID / contract (reuses §2.2 + the S-7 catalog pattern). **This completes the CTP-side scope: Fix E (CL-477/478) + Fix G (CL-479) + Fix F (CL-480) all landed. Consumer-side Fix A–D remain in GCTP.** Suite 4274→4280.

### §28.21 Universal coverage — apply all rules to all generated software, withhold only the conjunction (foundation, 2026-06-15)

Operator directive: **apply every enforced rule from the curated first-class sources to ALL generated software-engineering content (architecture, design, ADRs, IaC, config, code) across all languages/frameworks/technologies; withhold a rule from a target only when it is BOTH not-agnostic AND not-a-generally-applicable rule.** Full ticket: `docs/memory/architecture-backlog-language-agnostic-standards-coverage.md`. CL-481 lands the **foundation + the consumable contract** GCTP needs to begin; further standards × languages extend it per-CL.

- **Apply-by-default classification + gate.** `rubric/detectors/audit-universality-coverage.sh` (in `/doctor` + CI): every rule is **applied** unless it carries `enforcement: {mode: withheld, reason, bound_to, not_general_because}` — the complete conjunction justification; a withhold missing any conjunct is **rejected**. Forgetting to classify can only over-enforce, never drop a source standard. Green on today's corpus: **46 rules, 46 applied, 0 withheld.**
- **Polyglot enforcement.** `rubric/detectors/universal-pattern-rule.sh` (§2.2, rule-id-driven like `cloud-guidance-rule.sh`) enforces one standard's pattern set across **every** source language (18 extensions: `.py/.go/.rs/.java/.ts/.rb/.cs/…`). `commands/promote-universal-rules.sh` generates the `g-universal-*` §2.1 rules (in `_universal/`, originating-source provenance preserved → pass §2.33; coding-rules 44→46) + the detector manifest from one source of truth.
- **First two universal standards (proof of the contract):** `g-universal-no-hardcoded-secrets` (OWASP ASVS, P0) and `g-universal-no-debug-output` (Google eng-practices, P2) — both enforced identically on Python/Go/Rust/Java/JS/TS.
- **Through the frozen §28.17/§28.18 contract:** `enforce.sh --root <app> --rule g-universal-<id>` dispatches the polyglot detector and returns the 4-state verdict; a code standard on a docs-only tree is `not_applicable` (no vacuous green); a present language with no backend would be `not_enforced` (RED).

8 specs (`cl481-u-01..08`). No new feature ID / contract (reuses §2.2 + the S-7 pattern + the §28.17 dispatch). Suite 4280→4288.

### §28.22 Refresh-driven universal coverage — minimize redundant effort across the daily source refresh (2026-06-15)

Standards come from live URLs the plugin refreshes (~daily). Re-deriving every `g-universal-*` rule on every refresh would be wasteful; CL-482 makes the work **proportional to actual upstream change**, composing the existing freshness machinery rather than re-doing it.

- **Catalog-as-data.** The curated principles move out of code into `standards/universal-standards-catalog.json` (DATA: `{id, name, source, section, severity, mode, classification, source_content_hash, patterns[]}`). `commands/promote-universal-rules.sh` now reads it (deterministic + idempotent; verified byte-identical output). **Adding coverage = appending a principle to the catalog**, never a code edit; a `withheld` classification is carried but not promoted (apply-by-default).
- **Change-gated, resumable sync.** `commands/universal-coverage-sync.sh` runs after the daily refresh: for each catalog source it compares the **live content_hash** (S-21 conditional-GET state in `.claude-tdd-pro/standards-last-fetch/<id>.json`) to the **last-processed hash** in the resumable ledger `standards/universal-coverage-ledger.jsonl` (S-25 ledger pattern). **Unchanged ⇒ skipped (zero work)** — the redundancy killer. **Changed ⇒ re-promoted deterministically (free re-stamp of known principles) + `needs-classification`** (an agent reviews only the changed source's NEW sections, via S-5 diff, for genuinely-new principles — the sole real work, gated to actual change). A recorded hash is not reprocessed next run.
- **Net:** effort scales with upstream delta and number of *new* principles, not with the corpus size or the refresh cadence. An unchanged daily refresh costs ~0; a changed source costs one deterministic re-promote + one targeted review; a brand-new principle is one catalog append that all future syncs promote for free.

Markers: per source `universal-coverage-sync source=<id> status=<unchanged-skipped|changed-repromoted>` (+ `needs-classification=review-new-sections` on change); summary `… processed=<n> unchanged=<m> changed=<k> needs_classification=<k>`. 6 specs (`cl482-01..06`): catalog-driven promotion · unchanged-skip · changed-repromote+flag · delta-proportional · resumable · ledger record. Composes S-21/S-5/S-25 + the §28.21 promotion; no new feature ID / contract. Suite 4288→4294.

### §28.23 Begin refreshing on install — operator-chosen cadence + the source→enforcement explanation (2026-06-15)

The refresh loop now STARTS at install (was: capability present but dormant), with the operator choosing the cadence and the installer explaining why the sources matter.

- **`standards/initial-refresh.sh`** — starts the freshness loop: seeds the `.claude-tdd-pro/standards-last-fetch/<id>.json` baseline for every catalog source (this is what *starts* tracking — until a baseline exists nothing has a hash to diff against), best-effort runs the S-17 live daily refresh **backgrounded** (live conditional-GET when the env permits egress; offline → cached, retried next session; never blocks/fails), then runs the §28.22 universal-coverage-sync. Idempotent, network-tolerant, returns in <1s.
- **Wired into `scripts/install.sh` (Step 8b, background, disowned)** — so the plugin "begins refreshing as soon as it is installed," never blocking install.
- **SessionStart (`hooks.json` Setup group)** runs `initial-refresh.sh --quiet` so each session does first-use-of-day refresh; ongoing sub-day cadence is the in-use poll scheduler (S-20).
- **Install prompt for cadence** (`prompt REFRESH_FREQ … "1d"`, default **every day**, honored by `--yes`/CI) with a `describe` block **explaining the significance**: every enforced rule/pattern/standard is *derived from* and *cited to* first-class published sources (OWASP/Google/NIST/federal/SLSA/AWS WA) that are *scraped* from their live URLs, and the plugin *re-scrapes* them on the chosen schedule so enforcement tracks upstream and new guidance becomes new enforcement automatically.
- **`commands/set-refresh-frequency.sh`** writes the chosen cadence as the global `default` in the S-22 `.claude-tdd-pro/FETCH-FREQUENCIES.yaml`. Grammar = `<N><m|h|d|w|mo>` (an **additive §2.28 extension**: `d`/`w`/`mo` join the existing `ms/s/m/h` + calendar tokens) or a calendar token; `1d`/`1w`/`1mo` canonicalize to `daily`/`weekly`/`monthly` so the existing S-20 resolver is unchanged; invalid → exit 2.

8 specs (`cl483-r-01..08`): install explains + prompts · install kicks off refresh · default daily · accepts m/h/d/w/mo · rejects invalid · seeds baseline · session-start hook wired · non-fatal offline. No new feature ID (§2.28 grammar additively extended). Suite 4294→4302.

### §28.24 Prose-as-code judge + YAML/JSON/MD rule corpora (ADR-0007 / PROPOSAL-003, 2026-06-19)

Operator directive: fetch `PROPOSAL-003-ctp-session-brief.md` and treat it as the authoritative work directive — land it as an ADR (`docs/adr/0007-yaml-json-md-corpora-and-prose-judge.md`) and execute its three landing waves. Detailed design: `docs/design/v1.19-prose-as-code-and-corpora.md`. Source master tables (155 sources): `docs/standards-source-manifest.md`. This block is the extractable reference; the rationale, mapping tables, detector contracts, and ticket plan live in those files. The novel substrate (CTP-D-2 + CTP-D-3) lands now; the 22-namespace rule density follows wave-by-wave (each its own pin bump). Reuses **§2.1** (rule shape), **§2.2** (per-rule detector contract), **§2.16** (ADR/MADR), **§2.33** (citation conformance), and the §28.17 `enforce.sh` 4-state contract — **no new feature ID / §2.X contract number** is introduced.

- **`applies_to_prose` (CTP-D-2):** additive `schemas/rubric-rule.schema.json` fields — `applies_to_prose: bool` (default `false`) + `applies_to_prose_kinds: string[]` (default `["architecture","adr"]`). When true a rule **also** binds architectural Markdown prose (ADR/architecture docs), not only its code-shape detector — the **prose-as-code** principle (one rule, one gate, two surfaces). The flag lives on the rule shape (not an internal flag) so a consuming harness's static gates can enforce the prose floor. Default `false` (promote per rule) avoids ABSTAIN noise on syntactic rules.
- **`rubric/detectors/prose-judge.sh` (CTP-D-3) — the architecturally novel piece (§11 of the brief):** semantic-projection detector generalizing the `LLM_JUDGE=1` shell-out (`no-any.sh`/`naked-throw.sh`→`llm-judge.sh`) into a first-class detector. Any rule body + any prose section → **violates** / **compatible** / **abstain**, three tiers (deterministic **keyword-tier** → semantic **llm-tier** under `LLM_JUDGE=1` → **not_enforced** fallback, never a silent green). Cache by `sha256(rule_body+literals)+sha256(section)` in `<root>/.claude-tdd-pro/cache/prose-judge/`; eager only via `CLAUDE_TDD_PRO_PROSE_JUDGE_EAGER=1`. SARIF 2.1.0 (`--json`). Exit `0` green / `1` red (≥1 violates) / `3` incomplete (not_enforced) / `2` usage — mirrors §28.17.
- **`rubric/detectors/md-structure.sh` (Wave-1 seed, Layer-1, CTP-D-4):** deterministic dependency-free Markdown structural lint, rule-id-driven like `cloud-guidance-rule.sh` (`--rule <id> --root <dir>`), SARIF output, exit 0/1/2. Added to `enforce.sh` `RULE_DRIVEN`; `g-doc-*`/`g-md-*` → `*.md` ns_glob; rule-driven detectors use their manifest applies-glob (or ns_glob fallback) instead of `*`.
- **`md` namespace (Wave-1 down payment, CTP-D-1):** `generated-code-quality-standards/md/md-standards.yaml` with **`g-md-fenced-code-language-declared`** (markdownlint MD040, P2) and **`g-md-single-h1`** (MD025, P2), detector `md-structure.sh`, grounded in `commonmark` (CommonMark 0.31.2 + markdownlint) provenance → passes §2.33. Registered in `validate-all.sh KNOWN_NAMESPACES`.
- **SARIF 2.1.0 (CTP-D-5)** is the universal detector output bus; **CTP-D-6** extends `standards/initial-refresh.sh` source enumeration over the §6 manifest (license posture: mirror Apache/MIT/CC/BSD; config-only GPL; cite-link AWS/MS/CIS/Snyk/ISO); **CTP-D-7** bumps the `active.json` schema_version at wave time.
- **Wave plan (§20 sequencing — each wave is one pin bump):** **Wave 1** `yaml`+`k8s`+`md`(Layer 1)+`arch`(template-shape) ~50 rules; **Wave 2** `json`+`jwt`+`iam`+`sbom`+`sarif` ~60 rules (P0: JWT BCP RFC 8725 + IAM wildcards; SchemaStore; SARIF self-conformance); **Wave 3** all CI/CD/IaC (`gha`/`glci`/`azdo`/`circleci`/`bbp`/`jenkins`/`ansible`/`cfn`/`oas`/`gitops`/`observability`/`mesh`/`iac-linter`) + `prose-judge.sh` LLM-engine activation ~100+ rules.
- **§25 fidelity vocabulary additions:** `applies_to_prose`, `applies_to_prose_kinds`, `prose-judge`, `prose-as-code`, `semantic-projection`, `keyword-tier`, `llm-tier`, `violates`, `compatible`, `abstain`, `not_enforced`, `sarif`, `md-structure`, `g-md-fenced-code-language-declared`, `g-md-single-h1`, plus the 22 namespace tokens (`yaml`,`k8s`,`helm`,`compose`,`gha`,`glci`,`azdo`,`circleci`,`bbp`,`jenkins`,`ansible`,`cfn`,`oas`,`gitops`,`observability`,`mesh`,`iac-linter`,`json`,`jsonschema`,`iam`,`sbom`,`sarif`,`jwt`,`md`,`arch`).
- **Anti-drift pending-folder-name map:** future pending specs for this work file under `evals/pending/CC/2-2-prose-judge-semantic-projection/`, `evals/pending/CC/2-1-applies-to-prose-rule-shape/`, and per-namespace `evals/pending/G/<ns>-<label>/` — every folder name must map to one of the IDs/contracts named in this block (`§2.1`, `§2.2`, `g-md-*`, the namespace tokens) or it is invented and must be deleted/relocated per §25.3.

10 specs (`cl484-pa-01..10`): prose-judge flags an ADR proposing a forbidden design · prose-judge emits SARIF 2.1.0 · prose-judge caches by rule+section hash · prose-judge falls back to not_enforced (never silent green) · prose-judge rejects unknown rule · schema accepts applies_to_prose · enforce dispatches g-md via md-structure · md flags undeclared fence language · md flags multiple H1 · md namespace registered + grounded. Composes §2.1/§2.2/§2.16/§2.33 + §28.17; no new feature ID / contract. Suite 4302→4312.

### §28.25 Config & markup rule corpora landed — Waves 1-3 of ADR-0007 (2026-06-19)

Executes the three landing waves named in §28.24 / ADR-0007 §9: the 22 config & markup namespaces become first-class, grounded, enforceable §2.1 rules running through the frozen §28.17 `enforce.sh` 4-state contract. This is rule-content density on the §28.24 substrate — **no new feature ID / §2.X contract** is introduced; reuses §2.1 (rule shape), §2.2 (per-rule detector contract, the shared `cloud-guidance-rule.sh` require/forbid-token detector), §2.33 (citation conformance), and the §28.15 S-7 promotion pattern. Detail: `docs/design/v1.19-prose-as-code-and-corpora.md`; sources: `docs/standards-source-manifest.md`.

- **`commands/promote-config-rules.sh`** — the §28.24 sibling of `promote-cloud-rules.sh`: one source-of-truth `NS` catalog → 22 §2.1 rule files (`generated-code-quality-standards/<ns>/<ns>-standards.yaml`, each rule grounded in `provenance`) + the detector check manifest `rubric/detectors/config-guidance-rules.json`. Deterministic + idempotent. **68 literal security/quality rules** across **k8s** (10: privileged/hostNetwork/hostPID/hostIPC/privilege-escalation/latest-tag/runAsNonRoot/resources/readOnlyRootFilesystem/drop-caps), **iam** (4: wildcard action/resource/principal + `*:*`), **jwt** (3: RFC 8725 `alg:none` ×2 + hardcoded secret), **gha** (5), **compose** (5), **cfn/oas/glci/ansible/sarif/arch/helm** (3 each), **azdo/circleci/bbp/jenkins/gitops/observability/mesh/iac-linter/sbom/jsonschema** (2 each).
- **Second-manifest merge.** `config-guidance-rules.json` is read alongside `cloud-guidance-rules.json` by both `rubric/detectors/cloud-guidance-rule.sh` and `rubric/enforce.sh` (`mf_applies`), so the two generators never clobber. `enforce.sh` `ns_glob` extended: `g-arch-` → `*.md`, `g-json-` → `*.json`, `g-yaml-` → `*.yaml,*.yml` (and the fallback now splits multi-glob strings on comma).
- **Layer-1 wrapper detectors (CTP-D-4).** **`rubric/detectors/json-syntax.sh`** (`g-json-well-formed`, dependency-free RFC 8259 parse via node; node-absent → not_enforced, never vacuous green) and **`rubric/detectors/yaml-syntax.sh`** (`g-yaml-well-formed`, YAML 1.2.2 parse; both rule-id-driven, SARIF 2.1.0, added to `enforce.sh RULE_DRIVEN`). Their `yaml` / `json` namespaces ship `<ns>-standards.yaml`.
- **All 24 new namespaces** (`yaml json k8s helm compose gha glci azdo circleci bbp jenkins ansible cfn oas gitops observability mesh iac-linter jsonschema iam sbom sarif jwt arch`) registered in `validate-all.sh KNOWN_NAMESPACES`; §2.33 citation auditor coding-rules **48→118**, ungrounded=0.
- **License posture (CTP-D-6)** per rule `provenance` + `source.license_note` (mirror Apache/MIT/CC/BSD/IETF; cite-link AWS/MS/Atlassian). **CTP-D-7** (`active.json schema_version` bump) is consumer-side — the CTP catalog has no `active.json`; the bump happens when a consumer regenerates from this catalog.

76 specs (`cl485-*`): one violation-detection spec per literal rule (68, each a distinct rule/token) + verdict-state diversity (k8s clean→pass, iam empty-tree→not_applicable, json/yaml malformed→fail + valid→pass, arch resolved-decision→pass, multi-rule k8s deployment→fail=3). Composes §2.1/§2.2/§2.33 + §28.17; no new feature ID / contract. Suite 4312→4388.

### §28.26 Prose-as-code activated through `enforce.sh` — the §11 capstone of ADR-0007 (2026-06-19)

Closes the loop the whole brief was for (§28.24 / ADR-0007 §11): a curated set of rules now ALSO binds architectural Markdown prose, and **`enforce.sh` itself drives the second surface** — the same rule, same gate, projected onto ADR/design docs, so a design that violates a rule red-flags *before* the implementing code exists. Reuses the §28.24 substrate (`prose-judge.sh` + the `applies_to_prose` flag); **no new feature ID / §2.X contract**.

- **`enforce.sh` honors `applies_to_prose`.** It builds a `prose` map from the catalog (rules whose §2.1 body sets `applies_to_prose: true`). For such a rule it runs the primary code-shape detector AND, when the tree has `*.md`, dispatches `rubric/detectors/prose-judge.sh --rule <id> --root <root>` as a second surface, folding the result: a prose violation (prose-judge exit 1) **escalates the rule to `fail`** even when the code surface is clean or absent; a code-`not_applicable` tree with clean prose → `pass`; with unjudgeable prose → `not_enforced` (the never-silent-green floor). The prose surface can only ADD a catch, never downgrade a clean code result. `prose_detector` is recorded on the result.
- **`prose-judge.sh` reads `config-guidance-rules.json`** (alongside the cloud + universal manifests) so every §28.25 config-namespace rule body is prose-judgeable.
- **Curated activation set (`applies_to_prose: true`, emitted by the generators so it is regenerable, not hand-patched):** the unrestricted-ingress rules **`g-aws-no-unrestricted-ingress`** / **`g-gcp-no-unrestricted-ingress`** / **`g-azure-no-unrestricted-ingress`** (literal `0.0.0.0/0` → caught in prose via the deterministic keyword tier), plus **`g-iam-no-wildcard-action`**, **`g-iam-no-full-admin`**, **`g-jwt-no-alg-none-compact`**, **`g-k8s-no-privileged-container`**, **`g-k8s-no-host-network`**, **`g-gha-no-pull-request-target`** (caught literally when an ADR states the setting verbatim; otherwise the not_enforced floor flags that the prose touches the rule's domain unjudgeably).
- **Verified end-to-end:** `enforce --root <tree> --rule g-aws-no-unrestricted-ingress` on a tree with only an ADR proposing "leave dev-cluster ingress unrestricted (0.0.0.0/0)" and **no Terraform** → `fail`/red (the §11 example); a clean ADR + clean `.tf` → green; a clean `.tf` + an ADR proposing the design → `fail` (prose catches what code does not).

8 specs (`cl486-*`): ADR-proposes-ingress-with-no-terraform→fail · code surface still flags ingress · prose catches a design a clean .tf misses · materialized rule carries applies_to_prose · prose-judge resolves a config-manifest rule · non-prose rule on docs-only tree stays not_applicable · prose-touches-unjudgeably→not_enforced (never silent green) · ADR literally stating the forbidden k8s setting→fail. Composes §28.24 substrate + §28.17; no new feature ID / contract. Suite 4388→4396.

### §28.27 Enforcement at write-time and at architecture-generation-time (2026-06-20)

The §28.25/§28.26 rule corpus + prose-as-code now fire at the two moments material is produced — **when a file is written (Edit/Write)** and **when /architect generates an ADR** — not only when `enforce.sh` is run against a tree on demand. Same rules, same detectors, same §28.17 4-state contract; **no new feature ID / §2.X contract** (reuses §2.2 detectors + the §28.24/§28.26 prose binding). Operator directive: "make sure the rules are enforced when generating all architecture and also at write time."

- **`rubric/enforce-file.sh`** — the single-file projection of the §28.17 `enforce.sh` contract. Given one file it discovers every rule whose `applies` glob matches (from the SAME catalog + cloud/config/universal manifests `enforce.sh` uses), runs each rule's detector with `--paths <file>`, and additionally runs the §28.24 **`applies_to_prose`** rules through `prose-judge.sh` on architectural Markdown. **Severity/mode gating:** a violation BLOCKS (exit 1) only when it is P0/P1 **and** not a `require`-mode rule — `require`-absent is presumptive (glob-applies can match a file that is not the kind the rule targets, e.g. a compose file matched by a k8s `*.yml` rule) so it is always advisory; unambiguous `forbid`/wrapper/prose violations (`privileged: true` present, `0.0.0.0/0` in an ADR, malformed JSON) block. Exit 0 green/advisory · 1 blocking · 3 not_enforced · 2 usage.
- **Write-time:** `hooks/scripts/enforce-standards-on-save.sh` (PostToolUse `Edit|Write|MultiEdit`, alongside `lint-on-save.sh`) runs `enforce-file.sh` on the written file and exit-2 (surfaces to the model) on a blocking violation. Same hardened path model as `lint-on-save.sh` (workspace containment, symlinked-ancestor reject, vendor skip, strict path allowlist, silent exit 0 on any defense-trip). Scopes to the CTP-targeted kinds (`*.yaml/yml/json/md/tf/bicep/template/sarif/tpl`, `Jenkinsfile`); JS/Py stay `lint-on-save`'s job.
- **Generation-time:** `commands/architect.sh` runs `enforce-file.sh` on every ADR it emits; a P0/P1 violation surfaces and exits 1 ("resolve before handoff"), so an architecture the architect *generates* that proposes a forbidden design red-flags at emission. `not_enforced` does not block.
- **`rubric/detectors/cloud-guidance-rule.sh`** `--paths` now unions the direct glob with the under-root glob, so a single absolute file path handed by `enforce-file.sh` is matched (the tree-scan path is unchanged).

11 specs (`cl487-*`): enforce-file blocks a forbidden P0 · require-rule stays advisory (no false-positive block) · prose-as-code on an ADR · clean doc passes · malformed JSON blocks · write-hook blocks a P0 write · write-hook blocks an ADR via prose-as-code · write-hook allows a clean write · write-hook ignores JS/TS · architect enforces every generated ADR · hook registered on PostToolUse. Composes §2.2 + §28.24/§28.26 + §28.17; no new feature ID / contract. Suite 4396→4407.

### §28.28 Composite-engine roadmap adopted (ADR-0008/0009) + P-8 fix landed (2026-06-20)

Adopts the GCTP `COMPLETE-ARCHITECTURE-FOR-CTP` handoff (pinned `grok-claude-tdd-pro@31d77487`) as two paired, TIER-1-authority CTP ADRs and lands the one unblocking prerequisite. This block registers the ROADMAP + the P-8 fix; the engine build is staged across waves (no engine code lands here). **No new feature ID / §2.X contract** is introduced by this CL; the future surface is named below for the anti-drift map. Detail lives in the upstream drafts (cited) and in ADR-0008/0009.

- **P-8 fix (landed, the only code this CL):** `rubric/detectors/llm-judge.sh` now accepts **`--text <prose>`** (additive) alongside `--target <file>` — it materializes inline prose to a tempfile so all downstream `$TARGET` logic is unchanged, then cleans up on exit. This repairs the `prose-judge.sh` tier-2 invocation (`--rule … --text …`) which previously hit the unknown-arg path → exit 2 → spurious `not_enforced`. The semantic moat now returns real `YES/NO/ABSTAIN` verdicts under `LLM_JUDGE=1` when a model is present. `prose-judge.sh`'s own interface is unchanged (boundary preserved).
- **ADR-0008 (accepted) — composite engine + 4-axis canonical vocabulary + architectural-content bundle.** Replace hand-rolled grep detectors with a FOSS-tool router over a SARIF 2.1.0 bus; bind rules to tools via four industry authorities (**Linguist** `applies_to.linguist_aliases`, **IaC-consensus** `applies_to.iac_dialects`, **PURL** `applies_to.purl_uses`, **K8s GVK** `applies_to.k8s_gvks`) instead of CTP-invented namespaces; auto-attach the whole-or-nothing `architectural-content` bundle when `applies_to_prose: true`; two-phase (write-time pragmatic + audit-time zero-violation) enforcement.
- **ADR-0009 (accepted) — auto-classification + custom-rule drafting pipeline.** Six stages (extract → classify(4-axis) → route → architectural-content auto-bind → draft-with-four-layer-fidelity → review-queue) feeding `active.json`, with the **"no language silently dropped"** contract: every prose clause is deterministically enforced, semantically enforced via `prose-judge.sh` (Layer D), or explicitly flagged un-enforceable with operator sign-off.
- **Operator-directed divergence (binding):** the drafts specify *graceful tool absence → `not_enforced`*; the operator overrode to **hard-require** — a **required** tool that is absent is a hard failure that blocks (CTP must not claim a gate it cannot run); `not_enforced` is retained only for **optional/advisory** tools. This changes consumer-visible verdict semantics and MUST be reflected in paired GCTP ADR-0068 before the Wave-2 runners ship.
- **Wave plan (staged, each its own pin bump):** P-8 (done) → ADR-0008 W1 (vocabulary mirrors `vendor/canonical-vocabulary/` + `applies_to.*` schema + `sarif-aggregate.sh` bus) → ADR-0009 W1 (extractor + classifier + routing) → ADR-0008 W2 (per-tool runners + dispatch + parity-diff migration of the 118 rules) → ADR-0009 W2 (LLM drafter) → ADR-0008 W3 (bundle + two-phase wiring) → ADR-0009 W3 (review-queue CLI).
- **§25 fidelity vocabulary additions:** `composite-engine`, `4-axis`, `linguist_aliases`, `iac_dialects`, `purl_uses`, `k8s_gvks`, `applies_to`, `architectural-content` (bundle), `sarif-aggregate`, `enforced_by`, `vendor/canonical-vocabulary`, `kind-to-tool-routing`, `four-layer-fidelity`, `review-queue`, `hard-require`, `--text` (llm-judge).
- **Anti-drift pending-folder map:** future engine specs file under `evals/pending/X/composite-engine-4-axis-vocabulary/` and `evals/pending/X/auto-classification-pipeline/`; every folder must trace to ADR-0008/0009 or one of the IDs/contracts named here, else it is invented and must be deleted/relocated per §25.3.

2 specs (`cl488-*`): llm-judge accepts the --text inline-prose flag (P-8) · llm-judge still rejects an unknown flag (regression). The ADR landings are decisions, not substrate; ADR-0008/0009 conform to §2.16 MADR. Composes §2.16 + §28.24; no new feature ID / contract. Suite 4407→4409.

### §28.29 Composite engine — ADR-0008 Wave 1: 4-axis vocabulary mirrors + applies_to schema + SARIF bus (2026-06-20)

First build wave of the ADR-0008 composite engine. Foundations only — no external-tool runners yet (those are Wave 2). Everything mirrored is **permissively licensed (MIT/Apache-2.0), free to use, distribute, and use commercially** per operator directive. **No new §2.X contract**; extends §2.1 (rule shape) additively + composes the §28.24 SARIF emission.

- **4-axis canonical vocabulary mirrors** (`vendor/canonical-vocabulary/`, read-only, refreshed daily). The composite engine binds rules to tools via four INDUSTRY authorities instead of CTP-invented strings: **`linguist-languages.json`** (GitHub Linguist, **MIT**, live-fetched — 815 languages + a `by_extension` index), **`purl-types.json`** (package-url/purl-spec, **MIT**, 32 types), **`k8s-gvks.json`** (Kubernetes built-in GVKs, **Apache-2.0**, 30), **`iac-dialects.json`** (Checkov/Trivy/Kubescape dialect consensus, **Apache-2.0**, 18). `refresh-vocabulary.sh` materializes them (network-tolerant, idempotent; wired into `initial-refresh.sh` step 4); `provenance.json` records per-mirror authority/url/license/fetched_at/content_hash; `LICENSES.md` documents the all-permissive posture (no GPL/AGPL bundled, no non-commercial source). **`resolve.sh --file <path>`** is the binding primitive: file → `linguist_aliases` (by extension) + `iac_dialects` (by filename/extension+marker/glob).
- **`applies_to.*` 4-axis schema** (`schemas/rubric-rule.schema.json`, additive). `applies_to` becomes `oneOf[legacy string-array, 4-axis object]` with `additionalProperties:false` on the object form and keys `linguist_aliases` / `iac_dialects` / `purl_uses` / `k8s_gvks` (an invented axis key is rejected). New **`enforced_by[]`** field: ordered tool/bundle bindings, each with an optional **`required: true`** flag that encodes the §28.28 operator hard-fail policy (a required-but-absent tool blocks; optional tools degrade to `not_enforced`). No existing rule used `applies_to` (count 0), so the change is non-breaking.
- **SARIF 2.1.0 bus** (`rubric/sarif-aggregate.sh`). `--in <file>…` / `--dir <dir>` ingests N SARIF 2.1.0 docs (from any composite tool AND CTP's own prose-judge/md-structure/json-syntax/yaml-syntax detectors), merges runs into one normalized sarifLog (de-duped), and computes one verdict: **green** unless an error-level result (or any result under `--strict`, the audit-time gate). Exit 0 green / 1 red / 2 no-valid-SARIF. One stream for dashboards / code-scanning / IDEs / the engine gate.
- **§25 fidelity vocabulary additions:** `vendor/canonical-vocabulary`, `linguist-languages`, `purl-types`, `k8s-gvks`, `iac-dialects`, `resolve`, `refresh-vocabulary`, `enforced_by`, `required`, `sarif-aggregate`, `by_extension`.

13 specs (`cl489-*`): all 4 mirrors permissively-licensed (commercial-use guard) · resolver binds terraform→HCL+terraform · resolver binds k8s manifest→kubernetes (marker) · resolver binds workflow→github_actions (glob) · linguist mirror substantive+extension-indexed · schema accepts 4-axis object · schema keeps legacy array · schema rejects invented axis · schema accepts enforced_by+required+bundle · SARIF bus merges multi-tool→red · bus green on clean · bus --strict blocks warnings · bus exit-2 on no-SARIF. Composes §2.1 + §28.24; no new feature ID / contract. Suite 4409→4422.

### §28.30 Auto-classification — ADR-0009 Wave 1: extract → classify → route pipeline (2026-06-20)

First build wave of the ADR-0009 rule-supply pipeline (stages 1-3 + the stage-4 prose auto-bind). Deterministic Tier-1 only — the Tier-2 LLM classifier and the LLM drafter are later waves. Pure text + the §28.29 vocabulary mirrors; no external toolchain. **No new §2.X contract** (produces §2.1 `applies_to`/`enforced_by` shapes via the §28.29 schema). Every tool the router names is open-source (operator directive); GPL/LGPL tools are marked `invoke_only` (run as arms-length subprocesses, never bundled/distributed).

- **Stage 1 — `commands/extract-rules-from-url.sh`** segments a standards source (local file or URL, network-tolerant) into discrete candidate rules. Shapes: `markdown-headings` (default; H1 = document title, not a rule) and `numbered-list`. Emits `{rule_id, title, prose, source, content_hash}[]`. Exit 0/2/3 (source-unreadable).
- **Stage 2 — `commands/classify-rule.sh`** (deterministic Tier-1) tags a rule into the ADR-0008 4-axis vocabulary (`applies_to.linguist_aliases` / `iac_dialects` / `purl_uses` / `k8s_gvks`) + the `applies_to_prose` flag via an inverted keyword index. `confidence=high` on any match; `confidence=low` ⇒ `needs_tier2_llm=true` — **never silently dropped** (the ADR-0009 "no language silently dropped" floor, Tier-1 half).
- **Stage 3+4 — `commands/route-rule.sh`** + **`standards/kind-to-tool-routing.yaml`** map each classified kind to its FOSS tool(s) (first listed = primary), producing the rule's `enforced_by[]` with per-tool license metadata; and per ADR-0009 stage 4, `applies_to_prose:true` **unconditionally auto-attaches the `architectural-content` bundle** (a prose-only rule binds solely to the bundle).
- **Worked example (the brief's §O):** a Google TypeScript Style Guide ingest — "Use const not var" → `linguist_aliases:[typescript]` → `enforced_by:[eslint(MIT), semgrep(LGPL-2.1 invoke_only)]`; "Record an ADR" → `applies_to_prose:true` → `enforced_by:[bundle:architectural-content]`.
- **§25 fidelity vocabulary additions:** `extract-rules-from-url`, `classify-rule`, `route-rule`, `kind-to-tool-routing`, `needs_tier2_llm`, `confidence`, `markdown-headings`, `numbered-list`, `invoke_only`.

12 specs (`cl490-*`): extract segments by heading · extract skips H1 · extract numbered-list · extract unreadable→3 · classify→typescript(high) · classify→applies_to_prose · classify→terraform · classify low→needs_tier2 (not dropped) · route→eslint+license · route auto-attaches bundle · routing table all-FOSS (GPL invoke-only) guard · end-to-end Google-TS code→eslint + ADR→bundle. Composes §2.1 + §28.29; no new feature ID / contract. Suite 4422→4434.

### §28.31 Composite engine — ADR-0008 Wave 2: per-tool runners + dispatch loop (2026-06-20)

Wave 2 of the composite engine: the FOSS-tool runner layer + the dispatch loop that ties resolve → runners → SARIF bus into one verdict. All tools are open-source (MIT/Apache-2.0); GPL/LGPL tools run invoke-only (never bundled). **No new §2.X contract** (composes §28.29 resolve+bus + the §28.28 hard-require policy). **Toolchain note:** the engine container is ephemeral, so the runners apply the missing-tool policy and the eval suite is TOOL-INDEPENDENT — deterministic absent-paths plus opportunistic live-tool checks; a fresh (toolless) container stays green. The 118-rule parity-diff migration to `applies_to.*` is the remaining Wave-2 sub-task (next).

- **`rubric/runners/run-tool.sh --tool <t> --file <f> [--required]`** — invokes one FOSS tool and normalizes its output to SARIF 2.1.0 (the §28.29 bus aggregates). Adapters: **eslint** (MIT), **markdownlint-cli2** (MIT), **cspell** (MIT), **checkov** (Apache-2.0, native SARIF). Missing-tool policy (§28.28): present → run (exit 0 clean / 1 findings); **absent + `--required` → HARD-FAIL** (exit 1, SARIF error result); absent + optional → **not_enforced** (exit 3, never vacuous green); tool-ran-no-parseable-output → not_enforced. `RUN_TOOL_FORCE_ABSENT=1` forces the absent path (test affordance for deterministic policy specs on a toolless runner).
- **`rubric/composite-dispatch.sh --file <f> [--tools <csv>] [--required-tools <csv>] [--strict]`** — (1) resolves the file's 4-axis via `vendor/canonical-vocabulary/resolve.sh`, (2) routes each kind to its tool(s) via `kind-to-tool-routing.yaml` (or `--tools` override), (3) runs each via `run-tool.sh`, (4) aggregates all SARIF through `rubric/sarif-aggregate.sh`. Verdict: **red** if any tool found a violation or a required tool hard-failed; **incomplete** if no red but an optional/unadapted tool could not run (not_enforced); else **green**. Exit 0/1/3/2.
- **§25 fidelity vocabulary additions:** `run-tool`, `composite-dispatch`, `RUN_TOOL_FORCE_ABSENT`, `hard-fail`, `invoke-only`, `markdownlint-cli2`, `results_sarif`.

11 specs (`cl491-*`): runner hard-fails required-absent · runner not_enforced optional-absent · runner rejects unknown tool · runner emits SARIF error on required-absent · runner normalizes a present tool (live) · dispatch red on required-absent · dispatch incomplete on optional-absent · dispatch green when no tool applies · dispatch auto-resolves .tf→checkov · dispatch not_enforced (not vacuous green) on an unadapted routed tool · dispatch aggregates SARIF (live). Composes §28.29 + §28.28; no new feature ID / contract. Suite 4434→4445.

### §28.32 Composite engine — toolchain provisioned at install time (2026-06-20)

Operator clarification: *"all dependencies will be installed at the time CTP is installed, and by extension GCTP by its consumption of CTP."* This closes the loop on the §28.31 runners: in production the FOSS toolchain IS present, so the §28.28 hard-require policy treats a missing required tool as a **broken install**, not normal operation. **No new §2.X contract.** Every tool is open-source and free for commercial use.

- **`rubric/runners/toolchain.json`** — the toolchain manifest (source of truth for the installer AND the doctor/verify check): per tool `{installer (npm|pipx|binary), package, bin, license, invoke_only, kinds}`. 16 tools. Permissive (MIT/Apache-2.0/MIT-0): eslint, markdownlint-cli2, cspell, textlint, remark, spectral, checkov, cfn-lint, trivy, kubescape, zizmor, osv-scanner, vale, lychee. Copyleft `invoke_only` (run arms-length, never bundled/redistributed; commercial *use* unrestricted): semgrep (LGPL-2.1), hadolint (GPL-3.0).
- **`rubric/runners/install-toolchain.sh`** — provisions the toolchain from the manifest: idempotent (skips a present tool), network-tolerant + best-effort (a failed install is logged, never fatal — the engine degrades that tool per the missing-tool policy). `--verify` (report present/absent), `--dry-run` (plan only, never installs), `--permissive-only` (skip GPL/LGPL). npm/pipx tools install automatically; binary tools print their upstream release URL (platform-specific manual install).
- **CTP installer wiring** — `scripts/install.sh` Step 8c runs `install-toolchain.sh` backgrounded + best-effort during `init` (never blocks the <60s install); honors `CTP_TOOLCHAIN_PERMISSIVE_ONLY=1`. GCTP inherits the toolchain by consuming CTP.
- **§25 fidelity vocabulary additions:** `toolchain.json`, `install-toolchain`, `installer`, `invoke_only`, `permissive-only`, `CTP_TOOLCHAIN_PERMISSIVE_ONLY`.

7 specs (`cl492-*`): manifest every-tool-licensed · manifest copyleft-all-invoke_only · installer --verify reports status (no install) · installer --dry-run never installs · installer --permissive-only skips GPL/LGPL · installer marks binary tools manual+URL · CTP installer wires the toolchain. Composes §28.31 + §28.28; no new feature ID / contract. Suite 4445→4452.

### §28.33 Composite engine — ADR-0008 Wave 2 parity migration of the 118 rules to applies_to.* (2026-06-20)

Completes ADR-0008 Wave 2: the existing 118-rule corpus is migrated to the 4-axis canonical vocabulary so the composite engine can route it to FOSS tools — **gated by a parity-diff that proves no rule's enforcement was dropped or re-scoped.** Additive (every existing field preserved); **no new §2.X contract**.

- **`standards/namespace-axis-binding.yaml`** — namespace → 4-axis binding (`linguist_aliases`, `iac_dialects`, `foss_tools`) for all 42 rule-bearing namespaces + a polyglot `default` (`semgrep`) so nothing is unroutable. IaC namespaces → terraform/kubernetes/helm/... dialects + checkov/trivy/kubescape; TS/JS → eslint/semgrep; markdown/arch/documentation → markdownlint; cross-cutting (`_universal`/owasp) → semgrep.
- **`commands/migrate-rules-to-applies-to.sh`** — applies the map to every rule, ADDITIVELY + idempotently: sets `applies_to` (4-axis) and `enforced_by` = `[{tool: <existing detector>, required: true}, {tool: <each FOSS tool>}, {bundle: architectural-content} if applies_to_prose]`. The original `detector` is preserved as the **first, required** binding — that IS the parity guarantee (the existing enforcement is never removed, only 4-axis routing is added). Arrays are duped so Psych emits no YAML anchors. Binding map resolves from `CLAUDE_PLUGIN_ROOT` (plugin substrate), `--root` is the rules tree — so a generator can migrate a freshly-generated `--root t` tree byte-identically.
- **`rubric/detectors/audit-applies-to-parity.sh`** — the parity-diff gate (/doctor + CI): every coding rule's original detector must be `enforced_by[0]` with `required:true`, and every rule must carry a non-empty `enforced_by`. Green: **118 rules, 0 parity_fail, 0 unrouted**.
- **No-drift wiring:** `promote-cloud-rules.sh` + `promote-config-rules.sh` re-invoke the migration at their tail, so regenerating rule content never drops `applies_to`/`enforced_by`. Verified: re-running both generators keeps parity green and the determinism spec byte-identical.
- **§25 fidelity vocabulary additions:** `namespace-axis-binding`, `migrate-rules-to-applies-to`, `audit-applies-to-parity`, `foss_tools`, `parity-diff`.

10 specs (`cl493-*`): parity gate green (118/0/0) · every rule routable · detector preserved as required first binding · k8s→kubernetes dialect · migration idempotent · prose rule→bundle · parity gate catches a dropped detector · generators re-apply (no drift) · no YAML anchors · binding map covers every namespace. Composes §28.29/§28.31 + §28.28; no new feature ID / contract. Suite 4452→4462.

### §28.34 Auto-classification — ADR-0009 Wave 2: LLM rule-drafter with four-layer fidelity (2026-06-20)

ADR-0009 stage 5: translate a rule's prose into a tool DSL through the four-layer fidelity discipline that makes the **"no language silently dropped"** contract auditable. Deterministic by construction (Layer D guarantees coverage without a model); the LLM tier extends it when a model is present. **No new §2.X contract.**

- **`commands/draft-custom-rule.sh --rule-id --prose --tool [--llm]`** — four layers: **Layer A** emits the drafting prompt (the instruction that every clause be translated or flagged); **Layer B** the round-trip coverage diff maps each clause to `covered` (a deterministic tool-DSL line), `fallback` (Layer D), or `unenforceable`; **Layer C** emits positive + negative fixtures; **Layer D** binds every not-covered clause to `prose-judge.sh` (the semantic moat) so no clause is dropped even without a model. Advisory-style clauses (should/prefer, no must/never) are flagged `unenforceable` → `needs_operator_signoff`.
- **The contract (machine-checked):** `clauses_total == covered + fallback + unenforceable`, and `no_clause_dropped` is asserted (exit 1 if ever false — should never happen). `enforced_by` carries the tool (for covered clauses) + `prose-judge.sh` (for fallback clauses).
- **§25 fidelity vocabulary additions:** `draft-custom-rule`, `four-layer-fidelity`, `layer_a_prompt`, `coverage_report`, `no_clause_dropped`, `needs_operator_signoff`, `covered`/`fallback`/`unenforceable`.

8 specs (`cl494-*`): DSL-covers an enforceable clause · Layer-D fallback to prose-judge (never dropped) · advisory clause→sign-off · Layer-A prompt emitted · positive+negative fixtures · no-clause-dropped contract (sum==total) · prose-judge in enforced_by on fallback · requires --rule-id/--prose/--tool. Composes §28.24 (prose-judge) + §28.30 (classify); no new feature ID / contract. Suite 4462→4470.

### §28.35 Composite engine — ADR-0008 Wave 3: architectural-content bundle + two-phase wiring (2026-06-20)

Completes ADR-0008: the whole-or-nothing architectural-content bundle + the two-phase (write-time / audit-time) enforcement that ties the engine together. **No new §2.X contract.** All bundle members are open-source (MIT/Apache-2.0); the in-repo `prose-judge.sh` is the per-rule semantic path.

- **`rubric/runners/run-bundle.sh --file <md>`** — runs EVERY member of a bundle (read from `kind-to-tool-routing.yaml bundles.<name>`; the operator cannot pick/choose) via `run-tool.sh` and aggregates their SARIF. Whole-or-nothing verdict (never vacuous green): **red** if any member found a violation; **incomplete** if a member could not run (absent/unadapted → not_enforced); **green** only if every member ran clean. Auto-attached when a rule is `applies_to_prose:true`.
- **Two-phase wiring (same engine, two moments):**
  - **Audit-time (whole-tree, strict zero-violation gate):** `rubric/composite-audit.sh --root <tree>` walks the tree, drives `composite-dispatch.sh` (code-shape tools) per file + `run-bundle.sh` for every Markdown file, and aggregates one tree verdict (red on any violation; incomplete on any not_enforced). Exit 0/1/3.
  - **Write-time (per-file, pragmatic):** `hooks/scripts/enforce-standards-on-save.sh` now also runs the bundle on each Markdown Edit/Write — surfacing a bundle violation (red → exit 2) but lenient on incomplete/not_enforced (the strict gate is audit-time).
- **§25 fidelity vocabulary additions:** `run-bundle`, `composite-audit`, `architectural-content`, `whole-or-nothing`, `two-phase`, `audit-time`, `write-time`.

8 specs (`cl495-*`): bundle reads members + runs whole-or-nothing · bundle never vacuous green (clean→incomplete) · bundle flags malformed md (never green) · bundle requires --file · audit-time walks tree + flags · audit-time aggregates per-file · audit-time requires --root · write-time runs the bundle on md edits. Composes §28.24/§28.31; no new feature ID / contract. Suite 4470→4478.

### §28.36 Auto-classification — ADR-0009 Wave 3: review-queue CLI (pipeline complete) (2026-06-20)

Completes ADR-0009: the human-in-the-loop review queue (stage 6) that gates drafted rules before they reach `active.json`. With this, the full six-stage pipeline (extract → classify → route → architectural-content auto-bind → four-layer draft → review-queue) is built. **No new §2.X contract.**

- **`commands/review-queue.sh (--in <draft.json> | --dir <dir>) [--auto-accept]`** — routes each draft (draft-custom-rule.sh output) by confidence + coverage: **high-confidence + zero-gap → auto-stage** (batched commit), **high-confidence + gaps → coverage-review**, **low/medium → side-by-side-review**. `confidence=high` iff ≥1 clause got a deterministic tool DSL (`clauses_covered>0`); a "gap" is a clause flagged `unenforceable` (needs operator sign-off). Default is human-in-the-loop (stages nothing); `--auto-accept` opts a high-trust operator into auto-staging the high-confidence zero-gap rules.
- **§25 fidelity vocabulary additions:** `review-queue`, `auto-stage`, `coverage-review`, `side-by-side-review`, `auto-accept`, `human-in-the-loop`.

8 specs (`cl496-*`): auto-stage high+zero-gap · coverage-review high+gaps · side-by-side low · default human-in-the-loop (staged=0) · --auto-accept stages · routes a directory · requires input · end-to-end draft→review-queue. Composes §28.30/§28.34; no new feature ID / contract. Suite 4478→4486.

**ADR-0008 and ADR-0009 are now fully built** (§28.28–§28.36): composite engine (4-axis vocabulary + SARIF bus + runners + dispatch + bundle + two-phase) and the auto-classification + four-layer-fidelity drafting + review-queue pipeline, with the 118-rule parity migration and the install-time FOSS toolchain. All material open-source and free for commercial use.

### §28.37 Commercial-sale license gate — CTP/GCTP sellable with no conflict (2026-06-20)

Operator requirement: CTP and GCTP must be usable, distributable, and **sellable commercially** with no licensing conflict — every dependency open-source and free to use, distribute, and sell. This makes that guarantee authoritative + machine-enforced. **No new §2.X contract.**

- **`rubric/detectors/audit-commercial-license.sh`** (/doctor + CI) — the bright-line gate: **BUNDLED** content (data shipped in the plugin) must be permissive/attribution (MIT/Apache/BSD/ISC/MPL/CC0/CC-BY — never GPL/AGPL/LGPL source, CC-BY-**SA**, CC-**NC**, or proprietary); **INVOKE-ONLY** tools (installed separately by the user's package manager, never shipped) may carry any OSI license incl. GPL/LGPL provided they are flagged `invoke_only`; **CITED** sources (provenance only — CTP authors original rule prose and cites the authority, never redistributing its text) may carry any license. Green on the repo: bundled=4 (all MIT/Apache), tools=16 (14 permissive + semgrep LGPL/hadolint GPL both invoke_only), violations=0.
- **`COMMERCIAL-USE.md`** — the policy doc: bundled→permissive-only, invoke-only→tools-not-shipped (GPL/LGPL commercial *use* unrestricted; `--permissive-only` gives a zero-copyleft footprint), cited→provenance-not-redistribution, and GCTP-inherits-by-construction.
- Defense-in-depth: the narrower `cl489` (vocab) / `cl490` (routing) / `cl492` (toolchain) license guards remain.
- **§25 fidelity vocabulary additions:** `audit-commercial-license`, `invoke_only`, `bundled`, `cited`, `permissive-only`, `commercial-sale`.

6 specs (`cl497-*`): gate confirms commercial-safe · rejects bundled copyleft · rejects unflagged copyleft tool · accepts invoke_only copyleft tool · default toolchain copyleft all invoke_only · policy documented. Composes §28.29/§28.32; no new feature ID / contract. Suite 4486→4492.

### §28.38 Install-time license-footprint prompt — zero-copyleft option (2026-06-23)

Operator requirement: at install time the user must understand the commercial-resale license posture and be **prompted with an option** to configure a zero-copyleft footprint. Builds on §28.32 (toolchain at install) + §28.37 (commercial-sale gate). **No new §2.X contract.**

- **`scripts/install.sh`** now PROMPTS during `init` (a `describe` block + `prompt_yn`, mirroring the §28.23 refresh-cadence prompt): explains that every dependency is open-source and free to sell commercially, that the engine INVOKES FOSS tools (never bundles them), and offers **FULL** (default — all FOSS incl. the two invoke-only copyleft tools semgrep/hadolint, still resale-safe) vs **PERMISSIVE-ONLY** (zero-copyleft footprint — skips those two; engine runs on the all-permissive subset). The choice is resolved from `--permissive-only`/`--full-toolchain` flag, `CTP_TOOLCHAIN_PERMISSIVE_ONLY` env, or the prompt (default = full); shown back in the install plan (`license:` line) and applied to the §28.32 Step-8c toolchain provisioning.
- **`COMMERCIAL-USE.md`** gains an "Installing — choosing your license footprint" section (prompt text + flags + env). Install help documents the flags + env var.
- **§25 fidelity vocabulary additions:** `permissive-only`, `full-toolchain`, `zero-copyleft`, `license-footprint`, `CTP_TOOLCHAIN_PERMISSIVE_ONLY`.

8 specs (`cl498-*`): flags parsed · prompts during init · explains resale + zero-copyleft · defaults to full (opt-in) · applies the choice to provisioning · resolves from flag/env/prompt · help documents flags · COMMERCIAL-USE explains the install choice. Composes §28.32/§28.37; no new feature ID / contract. Suite 4492→4500.

### §28.39 End-to-end integration suite — URL → 4-axis → tool → enforce on write + audit (2026-06-23)

Confirms (and closes the last gaps in) the full pipeline the operator specified: every standards URL is scraped → each rule tagged with the industry four-axis registry vocabulary → routed by kind to the proper FOSS dependency → enforced on the WRITING and AUDITING of every content in any repo CTP/GCTP touches; sources are ESLint-style configurable/extensible and regularly re-scraped. **No new §2.X contract.**

- **Gap closed — write-time runs the composite engine.** `hooks/scripts/enforce-standards-on-save.sh` now runs all three engine stages on each Edit/Write: in-repo rule detectors (`enforce-file.sh`) + the architectural-content bundle (`run-bundle.sh`, Markdown) + the **routed FOSS tools** (`composite-dispatch.sh`). A rule scraped from a URL is thus enforced at write-time by its routed dependency (checkov/eslint/…), red surfaces inline (exit 2); a missing tool is lenient at write-time (the strict gate is audit-time).
- **Gap closed — audit-time is comprehensive.** `rubric/composite-audit.sh` now folds `enforce-file.sh` (in-repo rules + prose-as-code) alongside `composite-dispatch.sh` (routed tools) and the bundle, so the whole-tree gate audits every content against in-repo rules AND routed tools AND the prose bundle — deterministically.
- **10 persisted end-to-end integration tests (`evals/specs/e2e-01..10`)** of depth and breadth: (1) scrape→extract discrete rules + content-hash provenance; (2) 4-axis canonical tagging (Linguist/IaC/prose, not CTP-invented); (3) kind→proper-tool routing with license (ts→eslint, tf→checkov, prose→bundle); (4) full source→enforcement chain (scraped no-privileged rule routes to checkov/kubescape AND blocks a privileged pod); (5) write-time enforcement (block violating / allow conformant); (6) audit-time whole-tree conformance (flags 3/3 violations, passes a clean repo); (7) ESLint-style source extension via `standards-add <url>`; (8) every source enrolled for regular re-scraping (65/65 carry fetch_frequency); (9) no-language-silently-dropped through draft→review-queue; (10) end-state guarantee (118 rules 4-axis-tagged + routable + parity-preserved + commercial-sale-safe).
- **§25 fidelity vocabulary additions:** `end-to-end`, `integration-test`, `source-to-enforcement`.

10 specs (`e2e-01..10`). Composes §28.28–§28.38; no new feature ID / contract. Suite 4500→4510.

### §28.40 Consumer Compatibility Contract — schema-additive with epoch + default (2026-06-23)

Post-handoff analysis from GCTP surfaced a real defect class: a CTP change can be *schema-additive* (new rule field/class) yet *breaking on a consumer's enforcement-STATE layer* — a consumer floor that derives requirements from `active.json`'s shape reds its legacy pin-keyed state (an added `applies_to_prose` rule retroactively demands every existing .md-scoped ticket carry it). The two compatibilities (CLI-signature vs enforcement-state) are different; the handoff only guaranteed the first. This amendment lands the CTP-side fix. **No new §2.X contract.**

- **CTP-side invariant "schema-additive with epoch + default":** (1) every rule carries an **`introduced_in`** epoch tag (additive schema field; existing rules stamped `baseline` by the migration, all 118; new rules carry their introducing pin) so consumers gate enforcement floors by epoch (enforce only when ticket-epoch ≥ rule.introduced_in — grandfather pre-epoch state instead of mass-rewriting); (2) every enforcement-relevant optional field declares its **`absent_default`** in `schemas/field-semantics.json` (a consumer reading old data gets a defined answer, never a new requirement); (3) detector behavior changes ship with a `since:`/deprecation window recorded in the ADR; (4) top-level plugin-tree additions are explicit in the handoff.
- **`rubric/detectors/audit-consumer-compatibility.sh`** (/doctor + CI) — fails the build when any rule lacks `introduced_in`, when an enforcement-relevant optional schema field is missing an `absent_default` in `field-semantics.json`, or when the contract doc is absent. Green: 118 rules, 0 untagged, 0 undeclared.
- **`docs/consumer-compatibility-contract.md`** — the policy, the two paired invariants (CTP "schema-additive with epoch+default" + the consumer's "epoch-aware enforcement" responsibility: epoch-gated floors, pin-keyed baselines, opt-in smoke fixtures, violation-vs-not-yet-applicable distinction), the required `consumer_compatibility:` block template every rule-schema-touching ADR fills, and a retro-fill for the composite-engine line. The GCTP handoff (`docs/handoff-gctp-composite-engine.md` §4a) carries the epoch-aware adoption guidance.
- **§25 fidelity vocabulary additions:** `introduced_in`, `epoch`, `absent_default`, `field-semantics`, `consumer-compatibility`, `enforcement-state`, `baseline`, `grandfather`.

8 specs (`cl500-*`): gate green (118 tagged) · every rule epoch-tagged · gate catches missing epoch · gate catches undeclared field · field-semantics declares the enforcement defaults · schema accepts introduced_in · migration stamps it idempotently · contract doc + handoff carry the invariants. Composes §28.29/§28.33; no new feature ID / contract. Suite 4510→4518.

### §28.41 ADRs + GCTP handoff updated — enforce-like-CTP + consumer-compatibility (2026-06-23)

Updates the previous ADRs and the GCTP handoff so the consuming harness gets the latest CTP (composite engine + the §28.40 Consumer Compatibility Contract + the recent 118-rule 4-axis/epoch standards work) and builds the integration to **enforce standards and rules the way CTP does**. Doc-only; **no new §2.X contract / no code change**.

- **ADR-0008** gains (additive) a **Consumer compatibility contract** section (adopting the "schema-additive with epoch + default" invariant + the required `consumer_compatibility:` block) and a **Build status** section (fully implemented, §28.28–§28.40).
- **ADR-0009** gains a **Build status** section (six stages built; drafted rules carry `introduced_in`).
- **`docs/handoff-gctp-composite-engine.md`** updated: pin → current `main` HEAD (consumer-compatibility line, ≥ `eaa70d2`); a "what's new since `230e99d`" note (epoch tags + the new gates); and a new **§4b "GCTP enforces standards like CTP"** — the core of the handoff: GCTP wires the SAME three mechanisms CTP uses on itself (write-time `enforce-standards-on-save.sh`, audit-time `composite-audit.sh`, CI audit gates) over the SAME catalog, on BOTH (A) its own repo and (B) every app it builds, with floors gated by `introduced_in` epoch so adoption is non-breaking.
- **§25 fidelity vocabulary additions:** `enforce-like-ctp`, `build-status`, `self-enforcement`.

6 specs (`cl501-*`): ADR-0008 has the consumer-compatibility section · ADR-0008/0009 have build-status · handoff §4b enforce-like-CTP (both surfaces) · handoff names the engine entrypoints · handoff references the consumer-compatibility contract · handoff pin updated off the stale 230e99d-only. Composes §28.40; no new feature ID / contract. Suite 4518→4524.

### §28.42 Composite engine — full FOSS toolchain wired (80 tools, generic runner, advisory formatters) (2026-06-24)

Capacity expansion of the §28.31 runner + §28.32 toolchain: the manifest grows from the 16-tool subset to the **exhaustive ~80-tool inventory** the operator's architecture names across all four axes + the cross-cutting families + the `architectural-content` prose bundle, and every routed tool now actually runs. **No new feature ID / §2.X contract** — composes §28.31 (`run-tool` / `composite-dispatch`) + §28.32 (`toolchain.json` / `install-toolchain`) + §28.28 (hard-require) + §28.29 (SARIF bus). Every tool open-source + free for commercial use; copyleft (GPL/AGPL/LGPL) is `invoke_only` (arms-length, never bundled). Detail: [docs/design/v1.18-full-toolchain-wiring.md](design/v1.18-full-toolchain-wiring.md).

- **`commands/promote-toolchain.js`** — single source of truth: one 80-tuple table emits BOTH `rubric/runners/toolchain.json` (install + exec spec per tool) AND `standards/kind-to-tool-routing.yaml` (routing derived from each tool's `kinds[]`, so the YAML never hand-drifts). 80 tools, 42 SARIF-native, 9 copyleft `invoke_only`.
- **Generic spec-driven `run-tool.sh`** — the 4 proven bespoke adapters (eslint / markdownlint / cspell / checkov) PLUS one generic path that reads any tool's `bin` + `exec` spec (`exec.mode`: `sarif` = prints SARIF 2.1.0 / `sarif-file` = writes `<outdir>/<exec.out>` / `exit` = exit-code, SARIF synthesized). All ~80 tools wireable with no per-tool shell. §28.28 missing-tool policy unchanged; unknown tool → exit 2.
- **Advisory formatters** — pure formatters (`prettier`, `shfmt`) are tagged `advisory: true`. A formatter's non-zero exit is an auto-fixable *style difference* (e.g. valid `{"ok":true}`), recorded as `level: note` but **never a blocking red** (`status=advisory`, exit 0, file verified well-formed). Fixes the false-red on every well-formed-but-unformatted file. Linters / validators / scanners stay blocking.
- **Green-if-verified verdict** — `composite-dispatch.sh` / `composite-audit.sh` mark a file **green once VERIFIED** (dependency-free in-repo detectors ran clean and/or ≥1 present routed tool ran clean) and `incomplete` only when nothing could verify it; absent OPTIONAL tools no longer degrade a verified file. Preserves "never a vacuous green" while making a partial toolchain usable.
- **`install-toolchain.sh`** — adds `cargo` / `go` / `gem` / explicit `manual` installer arms beside `npm` / `pipx` / `binary`, so the new installer kinds produce real plans, not `failed reason=no-installer`.
- **§25 fidelity vocabulary additions:** `promote-toolchain`, `advisory`, `green-if-verified`, `generic-runner`, `exec.mode`, `sarif-file`, `cargo`, `go`, `gem`.
- **Anti-drift pending-folder map:** any future toolchain-expansion specs file under `evals/pending/X/composite-engine-4-axis-vocabulary/` (the §28.28 map) — they trace to §28.31/§28.32 or one of the IDs named here, else invented and removed per §25.3.

10 specs (`cl502-*`): full inventory captured (≥80) · every tool has a runnable exec spec · routing binds json→formatter + typescript→many linters · generic runner resolves+runs a manifest tool (opportunistic) · generic runner hard-fails required-absent · generic runner not_enforced optional-absent · generic runner rejects unknown tool · formatter style difference is advisory not red · installer covers cargo/go/gem · full inventory stays commercially sellable (copyleft all invoke_only). Composes §28.31 + §28.32 + §28.28 + §28.29; no new feature ID / contract. Suite 4524→4534.

### §28.43 Exhaustive end-to-end integration suite — every tool + every rule, scrape→tag→route→enforce→audit (2026-06-24)

Adds the EXHAUSTIVE layer over the representative pipeline e2e (`e2e-01..e2e-10`): every one of the 80 tools and every one of the 118 rules walked through the full pipeline, end to end. **Test-only — no new feature ID / §2.X contract / no substrate change.** Integration testing that composes ADR-0008/0009 (§28.29–§28.42). Confirms (and documents in the design file) that `scripts/install.sh` Step 8c provisions the full toolchain at CTP install time. Detail: [docs/design/v1.18-exhaustive-e2e-integration-suite.md](design/v1.18-exhaustive-e2e-integration-suite.md).

- **Every tool (80):** all tools obey the §28.28 missing-tool policy through `run-tool.sh` (required-absent → hard-fail, optional-absent → not_enforced) · the routing table is bijective with the manifest (0 orphan tools, 0 ghost routes) · every PRESENT tool runs through the runner to a terminal verdict, never a usage error (opportunistic, `timeout`-guarded).
- **Every rule (118):** every rule maps to a runnable enforcer with parity preserved (`audit-applies-to-parity` rules=118 parity_fail=0 unrouted=0) · every axis-scoped rule (112) tags only with canonical Linguist/IaC/PURL vocabulary from the `vendor/canonical-vocabulary/` mirrors (0 invented kinds; the 6 universal rules route via their detector) · the whole tool+rule corpus stays commercially sellable (copyleft all `invoke_only`).
- **Full-pipeline golden paths per axis:** a scraped CODE rule flows url→classify(typescript)→route(eslint)→audit-green · a scraped IaC rule flows url→classify(kubernetes)→route(scanner)→audit-red-then-green · a scraped PROSE rule flows url→classify(prose)→route(architectural-content bundle)→audit-red · write-time (`enforce-file.sh`) and audit-time (`composite-audit.sh`) agree on the same file (the two-phase contract).
- **§25 fidelity vocabulary additions:** `e2e-integration`, `bijective-routing`, `vocab-canonical`, `two-phase-contract`, `install-at-ctp-install`.
- **Anti-drift:** these are integration specs in `evals/specs/` (the `e2e-*` family), not feature folders — each composes named §28.29–§28.42 surfaces; none introduces a new feature.

10 specs (`e2e-*`): every-tool-policy-wired · every-tool-bijectively-routed · present-tools-run-sane · every-rule-routable-parity · every-rule-vocab-canonical · whole-corpus-sellable · pipeline-code-url-to-audit · pipeline-iac-url-to-audit · pipeline-prose-url-to-audit · write-and-audit-agree. Composes §28.29–§28.42; no new feature ID / contract. Suite 4534→4544.

### §28.44 §16 ESLint-parity config plane threaded into §28 enforcement — resolve→route→enforce→grade (2026-06-24)

Closes the first integration gap between the two planes that already coexist on every rule: the §16 configuration plane (E-1 per-config severity / enable-disable, E-3 glob overrides) now **governs the native per-rule enforcement path**, in the operator-described order `resolve-effective-config → (4-axis) route → enforce → grade`. **No new feature ID / §2.X contract; no conflict** — composes §16 E-1/E-3 + §2.5 (`active.sh` resolver) + §28.27 (`enforce-file.sh`) + §28.35/§28.42 (`composite-audit.sh`). Detail + the read-only ground-assessment gap table: [docs/design/v1.18-config-plane-threaded-into-enforcement.md](design/v1.18-config-plane-threaded-into-enforcement.md).

- **Optional `--profile <profile.yaml>` on `enforce-file.sh` + `composite-audit.sh`.** Absent → **byte-identical** native enforcement (every catalog rule active at native severity) → the config plane is purely additive and cannot move an existing verdict. Present → the effective per-file config is resolved through the existing §2.5 resolver (`active.sh --emit-resolved --for-file`), and the enforcer **disables** rules resolved to `off`/`false`, **forces** the grade for `error`/`warn`, and leaves unmentioned rules at native grade.
- **Ground assessment (pre-work, read-only):** every rule already carried both planes, but the resolvers (`active.sh`, `inline-suppression.sh`) were wired only into reporting (`measure-rubric.sh`) / migration, never enforcement; the config-plane specs test the resolvers in isolation, so threading them in is additive. The external-tool path (`composite-dispatch`) deliberately stays out of per-rule CTP severity (those tools carry their own config) — a boundary, not a gap.
- **Robust by construction:** a missing/malformed profile falls back to native enforcement (guarded resolver call; unparseable → empty effective map → no-op), never crashing the gate.
- **§25 fidelity vocabulary additions:** `config-plane`, `--profile`, `effective-config`, `resolve-route-enforce-grade`, `default-preserving`, `disabled`, `forced-grade`.
- **Anti-drift:** uses the EXISTING resolver output; no ESLint-engine reimplementation (cascading-config / JS RuleTester) — that invented surface stays out of scope per §16's lightweight-parity choice.

10 specs (`cl505-*`): no-profile native baseline unchanged · `off` disables a rule · E-3 override glob match disables · profile omitting the rule keeps it enforced · E-3 override glob non-match keeps it enforced · summary surfaces profile+disabled · whole-tree audit honors the profile · whole-tree audit baseline unchanged · unreadable-profile safe-fallback · malformed-profile safe-fallback. Composes §16 E-1/E-3 + §2.5 + §28.27 + §28.42; no new feature ID / contract. Suite 4545→4555.

### §28.45 Single CTP rule-config surface — ship `profiles/standard.yaml` + adopt the one-config / all-tools-projection design (2026-06-24)

Closes the §21 default-profile gap and adopts (by reference) the design for ONE user-facing, ESLint-like configuration surface that makes every scraped rule configurable in a single consistent pattern and projects onto every enforcement tool. **No new feature ID / §2.X contract.** The singular pattern is the EXISTING §2.5 profile (`extends`/`rules`/`overrides`) keyed by G-3 rule IDs, selected by `userConfig.profile` — no invented format. Two design docs are adopted as the spec of record (proposal; new surface still gated on approval + this amendment): [docs/design/v1.18-eslint-config-to-tool-config-map.md](design/v1.18-eslint-config-to-tool-config-map.md) (ESLint-config → all-80-tools map + feasibility) and [docs/design/v1.18-single-ctp-config-surface.md](design/v1.18-single-ctp-config-surface.md) (the single discoverable config + two-layer projection).

- **`profiles/standard.yaml` ships** (the §21 definition-of-done default; was missing). `extends: [rubric:recommended]`, empty `rules`/`overrides` → resolves to the recommended set (118) and is **default-preserving** as an enforcement config (every recommended rule active at native severity).
- **Single-config layering verified end-to-end:** a user config that `extends: [standard]` and sets `rules: {<id>: off}` (or an `overrides[].files` glob) disables/regrades that rule at enforcement through the §28.44 `--profile` thread — the one-file UX works today on the native path.
- **Adopted design (feasibility = feasible):** the user edits ONE file (proposed root `ctp.config.yaml`, a §2.5 profile); a **two-layer translator** projects it onto all 80 tools — Layer 1 universal **post-hoc SARIF** (back-map each finding → CTP rule, apply effective severity/disable/suppression; correct for all 80), Layer 2 **generated** per-tool native configs (optimization, never hand-edited). Carve-outs: rule-**option** payloads are per-binding (`enforced_by[].config`), engine-local settings (`env`/`parser`/`settings`) are ESLint-family only.
- **§25 fidelity vocabulary additions:** `standard.yaml`, `ctp.config.yaml`, `single-config-surface`, `two-layer-translator`, `post-hoc-sarif`, `native-config-emitter`.
- **Anti-drift:** schema = existing §2.5; rule addressing = existing G-3; selector = existing `userConfig.profile`. Proposed-new surface (root config file name, `ctp config init/print` scaffolder, the routed-path Layer-1 projection that closes the §28.44 boundary) is documented in the design files and remains gated on approval before any substrate.

8 specs (`cl506-*`): standard.yaml ships at the named path · extends rubric:recommended · passes profile validation · resolves to a non-empty recommended set · is default-preserving as a config · a config extending standard disables a rule · a config extending standard scopes a disable by override glob · a config extending standard keeps unmentioned rules enforced. Composes §2.5 + §21 + §28.44; no new feature ID / contract. Suite 4555→4563.

### §28.46 Per-rule enforcement-output grouping — capture every finding, preserve tool reporting IDs, bubble up to the rule (2026-06-24)

The single-config-surface Layer-1 reporting substrate: captures every enforcement finding (any tool OR CTP native detector) off the §28.29 SARIF bus, **preserves each tool's own reporting ID**, and **groups the findings under the rule they belong to** so output bubbles up per rule. This is what makes the single config effective on the routed path WITHOUT a hand-built correlation table — the 4-axis registry already did rule→tool routing; the SARIF `ruleId` IS the config key. **No new feature ID / §2.X contract** — composes §28.29 (SARIF bus) + the §28.44/§28.45 config surface. Correction adopted from operator review: the earlier "rule↔tool-finding correlation table" is unnecessary; native-ID namespacing + an optional per-binding alias suffice.

- **`rubric/group-findings-by-rule.sh`** (`--dir`/`--in` SARIF, `--alias <map.json>`, `--json`). Each finding's rule key: a CTP-native id (`g-*`) stays as the CTP rule; a tool finding (driver=checkov, ruleId=CKV_K8S_16) is namespaced **`<tool>/<reporting-id>`** as a first-class rule key (ESLint-plugin style) — UNLESS an `--alias` ties that reporting id up to a CTP rule, in which case its findings roll up under the CTP rule. Per rule it records `tools[]` (which execution produced it), `reporting_ids[]`, aggregate `count`, max `level`, and sample `messages`.
- **Consequence:** the configurable rule space is **CTP's 118 rules + every tool's native checks (thousands)**, all addressable in the one config file by namespaced ID; per-rule severity/disable/suppression then applies on this grouped report.
- **§25 fidelity vocabulary additions:** `group-findings-by-rule`, `per-rule-grouping`, `reporting-id`, `namespaced-rule-key`, `alias-rollup`, `bubble-up-to-rule`.
- **Anti-drift:** composes the existing SARIF bus; introduces no new feature/contract; the alias is optional per-binding sugar, not a global table.

10 specs (`cl507-*`): aggregates repeated reporting ids under one rule with a count · preserves the tool-specific reporting id namespaced · splits distinct reporting ids from one tool into distinct rules · keeps a CTP-native finding under its CTP rule id · rolls a tool reporting id up to a CTP rule via alias · records the max severity level per rule · ties each rule to the executing tool · groups multiple tools independently · yields zero rules on empty output · usage error on no input. Composes §28.29 + §28.44/§28.45; no new feature ID / contract. Suite 4563→4573.

### §28.47 Config effective on the routed-tool path — closes the §28.44 boundary end-to-end (2026-06-24)

The load-bearing finish of the single-config surface: a user's `off`/`warn`/`error` is now effective on the EXTERNAL routed tools (eslint/checkov/ruff/…), not just CTP's native detectors. **No new feature ID / §2.X contract** — composes §28.46 (per-rule grouping) + §2.5 (resolver) + §28.31 (dispatch). With the §28.44 native-path thread, the config plane now governs BOTH enforcement paths; the §28.44 routed-path boundary is closed.

- **`composite-dispatch.sh --profile <profile.yaml>`** (also passed through by `composite-audit.sh --profile`). Absent → **byte-identical** per-tool verdict. Present → after running the routed tools, it groups every finding per rule (§28.46), resolves the effective per-file config (§2.5 `active.sh --emit-resolved`), then **drops findings for disabled rules** (`off`/`false`) and **regrades by severity** (`error`/no-override stays red; `warn` is advisory). Keyed by the tool-native namespaced id (`ruff/F401`) or a CTP rule via alias — no correlation table.
- **Verified:** a `ruff/F401` finding that reds a file flips to green when the profile disables `ruff/F401` (`disabled=1`); regrading to `warn` makes it advisory; a profile that omits it stays red; a missing/unrelated profile is default-preserving; the whole-tree audit honors it on the routed path.
- **Bug fixed in this CL:** `GROUPS` is a reserved shell variable in some shells (the prefix env assignment was silently dropped) → renamed the dispatch node env vars to `GJSON`/`EJSON`. (Portability lesson alongside the env-var-passing-first checklist.)
- **§25 fidelity vocabulary additions:** `routed-path-config`, `dispatch-profile`, `drop-disabled`, `regrade-by-severity`, `config-effective-end-to-end`.
- **Anti-drift:** composes existing surfaces; the config keys are SARIF-native namespaced ids + optional alias; no new feature/contract; default-preserving.

8 specs (`cl508-*`): routed config disables a tool-native rule and clears red · omitting the rule keeps the tool verdict red · regrading to warn is advisory not red · dispatch without a profile is unchanged · a profile on a clean file stays green · audit threads the profile to the routed path · dispatch accepts the profile flag · a missing profile does not crash. Composes §28.46 + §2.5 + §28.31; no new feature ID / contract. Suite 4573→4581.

### §28.48 Single config surface — `ctp.config.yaml` + `ctp config init/print/resolve-path` scaffolder & auto-discovery (2026-06-24)

The user-facing capstone of the single-config surface: one discoverable, ESLint-like config file makes every scraped rule configurable in one place, auto-discovered by enforcement. The schema is the EXISTING §2.5 profile (no invented format); the new surface is the discoverable root entry + the scaffolder + auto-discovery. **No new §2.X contract.** Builds the design adopted in §28.45 ([docs/design/v1.18-single-ctp-config-surface.md](design/v1.18-single-ctp-config-surface.md)).

- **`commands/config.sh`**: `init` scaffolds `ctp.config.yaml` (a §2.5 profile) listing every active rule grouped by source namespace, each annotated `[src] [enforced_by] (default: <severity>)` with a commented override line — the ESLint generated-config experience; the active config is `extends: [standard]` so it is **default-preserving** until the user uncomments a line (off|warn|error). `print` emits the effective resolved config (via `active.sh --emit-resolved`). `resolve-path` emits the active config per precedence: `<root>/ctp.config.yaml` > `userConfig.profile` > `profiles/standard.yaml`.
- **Auto-discovery (ESLint-style):** `enforce-file.sh` walks up from the file's directory to a `.git` boundary and applies `ctp.config.yaml` if found; `composite-audit.sh` applies `<root>/ctp.config.yaml`. No `--profile` flag needed. **Default-preserving:** no `ctp.config.yaml` found ⇒ byte-identical to before (verified on the 4581-spec suite). Tool-native checks are configurable in the same file by namespaced id (`ruff/F401: off`).
- **End state:** a user edits ONE file at the repo root, keyed by CTP `g-*` ids AND tool-native namespaced ids, effective across write-time + audit + native + routed enforcement, auto-discovered, default-preserving.
- **§25 fidelity vocabulary additions:** `ctp.config.yaml`, `config-init`, `config-print`, `resolve-path`, `auto-discovery`, `config-precedence`.
- **Anti-drift:** schema = §2.5; addressing = G-3 + §28.46 namespaced ids; selector precedence reuses `userConfig.profile` + the §21 `standard.yaml`. New surface = the root entry + scaffolder + discovery only.

10 specs (`cl509-*`): init scaffolds every rule with annotations · scaffold is a valid profile · scaffold is default-preserving · init refuses overwrite without force · init --force overwrites · resolve-path prefers the root config · resolve-path falls back to standard · enforcement auto-discovers the root config · whole-tree audit auto-discovers it · enforcement without a config is unchanged. Composes §2.5 + §21 + §28.44–§28.47; no new feature ID / contract. Suite 4581→4591.

### §28.49 Full-chain integration sweep — config surface → write-time + audit-time → all-source rules → native + 3rd-party (2026-06-24)

The integration coverage that was missing (the prior strict count was 0): tests that drive the single config surface all the way through BOTH enforcement phases on the actual source-scraped rule corpus, by BOTH native detectors AND 3rd-party libraries. **Test-only — no new feature ID / §2.X contract.** Composes §28.44–§28.48 + the §28 source corpus.

- **Behavioral full-chain (deterministic):** from a `ctp.config.yaml` repo, an OWASP/universal source rule (hardcoded secret) and a k8s source rule (privileged container) are enforced natively at write-time (`enforce-file`) AND audit-time (`composite-audit`); disabling them in the config clears BOTH phases via auto-discovery. A US-Government terraform rule is enforced by a 3rd-party library (checkov) at audit-time; a single file is enforced by BOTH a native detector (secret) and a 3rd-party tool (ruff), both governed by the config (3rd-party paths opportunistic, `command -v`-guarded → green on a toolless container).
- **Corpus-wide structural sweep (all 42 source namespaces incl. google + us-government):** every source rule binds a native detector (118/118); ≥90% also bind a routed 3rd-party library (the remainder are native-only structural/schema detectors — json/yaml well-formedness, jsonschema, sarif, sbom, a11y); the config surface (`extends: standard`) resolves the recommended set spanning every source; both enforcement entrypoints honor the same `ctp.config.yaml`.
- **§25 fidelity vocabulary additions:** `full-chain-integration`, `source-rule-enforcement`, `write-and-audit`, `native-and-thirdparty`, `corpus-coverage`.
- **Anti-drift:** integration specs in `evals/specs/` composing named §28.44–§28.48 surfaces over the real corpus; no new feature/contract; structural assertions report exact counts.

10 specs (`cl510-*`): source rule enforced write+audit natively · config clears a source rule across both phases · cloud source rule both phases · US-Govt terraform via 3rd-party · file enforced by native AND 3rd-party from config · every rule has a native detector · every rule enforceable + most bind 3rd-party · config covers all source namespaces · both entrypoints honor the config · config governs the 3rd-party path. Composes §28.44–§28.48 + §28; no new feature ID / contract. Suite 4591→4601.

### §28.50 Per-tool native options in the single config — schema expansion + tool-option-surfaces catalog (2026-06-24)

Completes the single config surface for OPTIONS: every rule can carry the tool-NATIVE options for each enforcing tool, in one layer, with NO transformer (the operator-rejected map/abstraction). **No new §2.X contract** — extends the §2.1 rule schema additively + composes §28.44–§28.49. Builds on the prior hook `enforced_by[].config` (string ref, landed CL-489 §28.29) and the option research in [docs/design/v1.18-eslint-config-to-tool-config-map.md](design/v1.18-eslint-config-to-tool-config-map.md).

- **Schema (`schemas/rubric-rule.schema.json`):** `enforced_by[]` bindings gain **`options`** (object) — the tool's own option vocabulary for THIS binding (eslint `{complexity:[error,{max:10}]}`, ruff `{mccabe.max-complexity:10}`, rubocop `{Max:15}`, stylelint `{severity:warning}`), overridable per (rule,tool) from `ctp.config.yaml`. `additionalProperties:false` is preserved → options are accepted but invented binding keys still rejected (bounded surface). `config` (string) remains for a named preset/ruleset ref.
- **Catalog (`standards/tool-option-surfaces.yaml`):** the standardized per-rule option surface for **all 80 tools** — each tool's `paradigm`, native `option_form`, `emit` target (where CTP writes it), and examples. 55 option-bearing tools (eslint-semantics + config-toggle), 22 honestly marked `per_rule_options: none` (vuln scanners, formatters, binary validators — they have only severity-threshold/disable, no per-rule options), across all 6 paradigms. The options are each tool's REAL keys, not a CTP abstraction — so the single file is tool-specific without a transformer.
- **Honest scope:** this lands the SCHEMA + the standardized CATALOG (the "study all tool options + standardize into one schema" deliverable). The Layer-2 native-config EMITTERS that render `enforced_by[].options` into each tool's on-disk config at run time are the remaining wiring (per-paradigm, follow-up CLs).
- **§25 fidelity vocabulary additions:** `tool-option-surfaces`, `enforced_by.options`, `option_form`, `emit-target`, `per_rule_options`, `tool-native-options`, `no-transformer`.
- **Anti-drift:** schema change is additive (existing rules without options still validate); catalog is data derived from the cited research; no new feature/contract.

10 specs (`cl511-*`): binding carries structured tool-native options · binding surface stays bounded · catalog covers every tool · every tool declares an option_form or is marked optionless · options are tool-native not transformed · a rule carries distinct options for multiple tools · all paradigms represented · catalog names the native emit target · optionless tools honestly marked · catalog cites the research. Extends §2.1 additively; composes §28.44–§28.49; no new feature ID / contract. Suite 4601→4611.

### §28.51 Layer-2 native-config emitters — tool options from the single config take effect in the real tools (2026-06-24)

Completes the single config surface for options end-to-end: the tool-NATIVE options written once in the single layer (`enforced_by[].options` / `ctp.config.yaml` `tool_options:`) are now RENDERED into each tool's own on-disk config and INJECTED at run time, so they actually change the tool's enforcement. **No new §2.X contract** — composes §28.50 (schema + catalog) + §28.47 (routed dispatch). No transformer: the rendered config IS the tool's native format.

- **`rubric/runners/emit-tool-config.sh`** (`--tool --options <json> --out <dir>`): renders the options into the tool's native config file using the catalog's `render: { fmt, file, flag }`. Supports **json / yaml / toml / ini**. No-op for optionless tools (no render mapping) and for empty options.
- **`rubric/runners/run-tool.sh`** gains **`--tool-options <json>`**: emits the native config and injects the tool's config flag (`ruff --config`, `eslint --config`, `mypy --config-file`, …) into the generic exec. Proven: `ruff` `lint.ignore=[F401]` flips a finding from red→green; default-preserving when no options.
- **`rubric/composite-dispatch.sh`** reads the single config's `tool_options:` map and passes each tool its options; `composite-audit.sh` carries this through auto-discovery — so dropping `tool_options` into a root `ctp.config.yaml` changes routed enforcement at write-time and audit-time with no flags.
- **`standards/tool-option-surfaces.yaml`** gains `render` blocks for the wired tools (ruff, eslint, rubocop, stylelint, yamllint, mypy, markdownlint, golangci-lint, swiftlint, biome, cspell), spanning all four formats. Remaining option-bearing tools follow by adding their `render` block (data-only).
- **§25 fidelity vocabulary additions:** `emit-tool-config`, `native-config-emitter`, `tool_options`, `render-block`, `config-flag-injection`, `layer-2`.
- **Anti-drift:** catalog-driven serialization; generic-path injection (bespoke adapters unchanged); default-preserving (no options ⇒ tool runs with defaults); no new feature/contract.

10 specs (`cl512-*`): emitter renders toml · renders json/yaml/ini · no-op optionless · no-op empty · run-tool applies options + changes verdict · run-tool empty unchanged · dispatch applies tool_options from the config · audit applies tool_options via auto-discovery · render tools declare a config flag · every render fmt supported. Composes §28.50 + §28.47; no new feature ID / contract. Suite 4611→4621.

### §28.52 Layer-2 render coverage completed — every option-bearing tool mapped (2026-06-25)

Completes the Layer-2 emitter coverage: **all 55 option-bearing tools** now carry a `render` mapping. **No new §2.X contract** — extends the §28.50 catalog + §28.51 emitter (data-only + spec). The single config's tool-native options now have a defined emission target for every tool that has options.

- **41 tools fully wired** (`render: { fmt, file, flag }`, `supported: true` implicit) across all four emitter formats (json/yaml/toml/ini) — eslint, ruff, rubocop, mypy, vale, conftest, detekt, hadolint, spectral, redocly, bandit, gosec, slither, sqlfluff, … their options emit + inject at run time.
- **14 tools honestly marked `supported: false`** — their native config uses a format the emitter does not yet serialize (xml: pmd/psalm/spotbugs; neon: phpstan; hcl: tflint; exs: credo; editorconfig: ktlint; custom/cli: staticcheck/shellcheck/semgrep/write-good/alex/clippy; bespoke-adapter: checkov). The emitter **no-ops gracefully** (the tool runs with its defaults; no crash) until a per-format serializer is added. Marked, not faked.
- **Optionless tools (22)** correctly carry NO render block — nothing to emit.
- **§25 fidelity vocabulary additions:** `render-coverage`, `supported-false`, `bespoke-serializer`, `graceful-noop`.
- **Anti-drift:** data-only catalog expansion; supported entries assert the full `{fmt,file,flag}` triple; unsupported entries honestly marked; emitter unchanged; no new feature/contract.

8 specs (`cl513-*`): every option-bearing tool has a render mapping · supported set spans all four formats · unsupported native formats honestly marked · emitter gracefully no-ops unsupported · every supported render declares the full triple · majority fully wired · a representative tool per format wired · optionless tools have no render block. Composes §28.50 + §28.51; no new feature ID / contract. Suite 4621→4629.

### §28.53 Scoped eval cache — per-spec dependency-closure hashing (2026-06-30)

Replaces the whole-tree cache hash (which invalidated the ENTIRE cache on any substrate edit, so the suite never hit cache during active development) with a **per-spec dependency-closure hash**: a test is invalidated only when a function it (transitively) exercises changes. **Test-infrastructure only — no spec, feature, or §2.X contract change to the product.**

- **`evals/dep-hash.js`** computes, for each spec, a hash over the TRANSITIVE substrate closure it depends on: it extracts the spec's substrate entrypoints (`$CLAUDE_PLUGIN_ROOT/...` + path tokens), follows script→script references, and includes **wholesale-read collections** (the rule corpus + `rubric/detectors`, which `enforce-file`/audit glob or dispatch by name). **Correctness bias = over-inclusion:** a missed dependency would be a false green, so extraction errs toward including too much; a spec with no resolvable reference emits `GLOBAL` → the runner falls back to the whole-tree hash (today's conservative behavior). 4193/4629 specs scope; 436 fall back.
- **`evals/runner.sh`** keys each spec's cache on its dependency hash (per-spec file under a DEPMAP dir, O(1) `cat` lookup) instead of the global `TREE_SHA`. `RUNNER_SHA` now covers `dep-hash.js` too, so a change to the hashing logic invalidates safely. Net effect: a CL that changes one engine file re-runs only that file's dependents; the thousands of unrelated specs stay cached across CLs. Unit tests pin to their function; integration tests (broad closure) invalidate widely — exactly the requested model.
- **Verified correctness:** changing a directly- or transitively-referenced function invalidates the spec; changing an unrelated function does NOT; a corpus change invalidates corpus-reading specs. (`cl514-*`.)
- **§25 fidelity vocabulary additions:** `dep-hash`, `dependency-closure`, `scoped-cache`, `wholesale-read-collection`, `global-fallback`, `transitive-closure`.
- **Anti-drift:** the cache is an optimization; the authoritative gate can still run `--no-cache`. Over-inclusive closure + GLOBAL fallback make stale-pass impossible for specs whose deps are extracted; no product behavior changes.

8 specs (`cl514-*`): scoped hash for a referenced spec · GLOBAL fallback for a no-reference spec · invalidates on a referenced-function change · stable on an unrelated change · follows the transitive closure · includes the corpus for a script that reads it · runner keys on the dep hash · majority of real specs scoped. Test-infra only; no feature/contract. Suite 4629→4637.

### §28.54 §28 EO-security cluster completed — H-15/H-16/C-22/C-23/X-10/W-13/Q-13 + §2.30–§2.32 (2026-06-30)

Builds the remaining §28 v1.18 AI-security/governance surface (the only coherent unbuilt cluster; H-14 + S-54 already shipped). Implements the feature IDs and cross-cutting contracts decomposed in [docs/design/v1.18-eo-ai-security-governance.md](design/v1.18-eo-ai-security-governance.md) §28.1/§28.2/§28.8. Batch CL (range CL-515..521) per the batch-CL convention; each feature traces to its design-file bullet + anti-drift folder. **No new feature ID beyond those already registered; no new §2.X contract beyond the registered §2.30/§2.31/§2.32.**

- **H-15** `commands/sbom.sh` (§2.31) — CycloneDX (default) / SPDX SBOM with component inventory + deterministic digest; SLSA-style signed provenance attestation binding `{sbom_digest, artifact_digest, builder, materials, signature}` to the §2.8 manifest; `attestation=unsigned` without a key; SLSA-level claim cites `slsa-framework`.
- **H-16** `commands/frontier-eval.sh` (§2.32) — voluntary pre-release readiness scaffold: the four EO control families (confidentiality/cybersecurity/insider_risk/ip_protection) each cite-or-decline-grounded in `nist-ai-rmf`, cyber-capability self-assessment, 30-day window, Sec. 1 no-mandatory-licensing disclaimer. Governance checklist, not a model evaluator.
- **C-23** `commands/cvd-record.sh` (§2.30 record-half) — coordinated-disclosure records `{advisory_id, severity, component, fixed_in, disclosed_at, remediation_status, source}` from H-14 findings; fed to the C-4 audit log + §2.24 audit-pack.
- **C-22** `compliance/eo-control-mapping.yaml` (§2.9, framework `eo-advanced-ai-2026`, controls `eo-sec2/3/4-*` → plugin controls, cross-walked to nist-ai-rmf/cisa-ssdf/nist-800-53) + `profiles/national-security-systems.yaml` (extends `government`).
- **X-10** `doctor --check vuln-scan` + `--check sbom` (H-14/H-15 on the `/doctor` surface, same exit-code contract, safe-by-default green no-op) + the CI step appended to `.github/workflows/closed-loop.yml` (no existing step altered).
- **W-13** `commands/redteam-review.sh` — blue/red adversarial pack (findings in §2.3 format, grounded in nist-ai-rmf + owasp) that feeds H-16 + C-23; deterministic scaffold (W-11 orchestration fills it in production).
- **Q-13** `commands/security-posture.sh` — local-only (Q-6 privacy) §2.11 SPACE security dimension: `vulnerability_density`, `percent_deps_fix_applied`, `mttr_to_remediate_hours`, `threat_model_coverage`, `trend`; derives from H-14 + C-23.
- **§25 fidelity vocabulary additions:** `sbom`, `cyclonedx`, `spdx`, `attestation`, `provenance`, `frontier-eval`, `needs_grounding`, `cvd-record`, `coordinated-disclosure`, `eo-advanced-ai-2026`, `national-security-systems`, `redteam-review`, `blue-team`, `red-team`, `mttr_to_remediate`, `vulnerability_density`, `security-posture`.
- **Anti-drift:** every command/file traces to a §28.1/§28.8 design bullet + the §28.5 folder map; tool-independent specs (deterministic, injected fixtures, no live network); the §21 definition-of-done is preserved (surface added, gate unchanged).

70 specs (`cl515-*`..`cl521-*`, 10 per feature): H-15 cyclonedx/spdx/signed/unsigned/manifest-link/slsa-cite/deterministic/dry-run/reject-format/json · H-16 four-families/grounded/cite-or-decline/disclaimer/window/self-assessment/declines-unknown/md+json/voluntary/single-control · C-23 fixed-in/audit-log/audit-pack/status-enum/explicit-status/full-fields/from-h14/empty-noop/json/reject-nonarray · C-22 framework/sections-map/nss-extends-gov/crosswalk/id-prefix/sec2+sec4/nss-valid/nss-eo-framework/nss-gates/sec3 · X-10 clean-noop/blocks-critical/doctor-contract/sbom-check/safe-default/ci-step/ci-additive/medium-warns/requires-root/emits-sbom · W-13 blue+red/grounded/findings-format/feeds-h16/feeds-c23/attacker-lens/md+json/requires-artifact/single-lens/digest · Q-13 density/percent-fixed/mttr/local-only/space-dimension/from-h14-c23/json/clean/coverage/trend. Composes §28.1/§28.2/§28.8 + §2.30–§2.32; no new feature ID / contract. Suite 4637→4707.

### §28.55 Golden-master Katas oracle + SARIF-bus tool-soup coverage — closes the two post-§28.54 integration gaps (2026-06-30)

Closes the two integration-coverage gaps found by the post-§28.54 inverted dependency-closure audit: the committed golden masters were committed-but-never-oracled, and no single test asserted architect/scaffold output flowing through the routed tool-soup to the SARIF bus. Conformance/integration hardening over existing producing surfaces + the existing §28.28/§28.29 SARIF bus. Detail: [docs/design/v1.18-golden-oracle-and-sarif-bus-coverage.md](design/v1.18-golden-oracle-and-sarif-bus-coverage.md). Extends §27.27 (`cl465-*`), §28.14 (`cl473-*`), §28.28/§28.29. **No new feature ID, no new §2.X contract.**

- **Gap 1 — golden-master Katas oracle (`cl522-golden-01..10`).** Wires the two committed Katas scenarios that `cl465` left as dead reference data into oracles: the healthcare-booking-HIPAA scenario (live `business-translate.sh` meets-or-exceeds the committed `healthcare-booking-hipaa-requirements.json`; the golden is itself fully cited; every live decision cited; regulated data tailors `audit_logging`+`mfa`+`strong_consistency`) and the multicloud boundary responses (`aws-boundary.sh` `build_units` match the committed `multicloud/aws-boundary-response.json`; gcp/azure boundaries validate their committed handoffs; all three handoffs committed + platform-tagged). Tailoring proven: HIPAA vs full-stack-AWS yield distinct concern sets (≥2 genuinely different scenarios, §28.14).
- **Gap 2 — tool-soup SARIF-bus over architect/scaffold output (`cl523-sarif-01..10`).** Proves architect/scaffold-generated content routes through the routed 3rd-party tools AND the CTP-native detectors, normalizing every verdict to the SARIF 2.1.0 bus at write-time and audit-time: scaffolded IaC → `composite-dispatch.sh` normalized verdict; bus merges to a single 2.1.0 log; error→red; no-blocking→green; identical findings deduped; `--strict` warning→blocking; per-tool counts reported; absent tool still emits valid SARIF; an architect ADR tree audits via `composite-audit.sh` to one tree verdict; an architect ADR flows `run-tool.sh`→bus→verdict. Tool-independent via `RUN_TOOL_FORCE_ABSENT=1` + crafted SARIF (the bus is the unit under test).
- **§25 fidelity vocabulary additions:** `golden-oracle`, `golden-master`, `oracle`, `katas`, `boundary-response`, `handoff`, `multicloud`, `tailoring`, `sarif-bus`, `tool-soup`, `normalized-verdict`, `deduplicate`, `audit-time`, `write-time`, `tool-independent`.
- **Anti-drift:** every spec traces to a Gap-1/Gap-2 design bullet; oracles compare live output against the committed `standards/golden/*` artifacts; SARIF-bus specs are deterministic + tool-independent (no live network, no installed-tool dependency); the §21 definition-of-done is preserved (the new batteries extend the active-suite gate, they add no product feature).

20 specs (`cl522-golden-01..10` + `cl523-sarif-01..10`): golden-oracle hipaa-meets/golden-cited/every-cited/tailored/aws-resp-grounded/aws-build-units-oracle/gcp-validated/azure-validated/multicloud-tagged/two-distinct-scenarios · sarif-bus routed-verdict/single-2.1.0-log/error-red/green-no-blocking/dedup/absent-valid-sarif/architect-tree-audited/architect-to-bus/strict-warn-blocks/per-tool-counts. **§20 note:** conformance/integration hardening over S-32..S-53 + the SARIF bus; preserves §21 dod (gate unchanged). Suite 4707→4727.

### §28.56 Native-enforcement fallback — no rule left unenforced when a routed tool is absent (operator-directed, 2026-06-30)

**STANDING INVARIANT (operator-directed): if a 3rd-party tool cannot be found for a rule, that rule is enforced by the native detectors instead — no applicable rule is ever left unenforced.** Refines (does not contradict) the §28.28 missing-tool policy. Detail: [docs/design/v1.18-native-enforcement-fallback.md](design/v1.18-native-enforcement-fallback.md). **No new feature ID, no new §2.X contract** (an enforcement-robustness refinement of `composite-dispatch.sh` over the existing §28.27 `enforce-file.sh` native detectors).

- **The change.** `rubric/composite-dispatch.sh` now falls back to native enforcement (`rubric/enforce-file.sh`) whenever the routed tool path cannot produce a verdict: **no applicable routed tool** for the file's kind → native enforcement instead of a vacuous green; **every routed tool absent/unadapted** (no tool produced green or red) → native enforcement instead of `incomplete`. Verdict folding: native blocking → `red`; native clean/advisory → `green`; native cannot verify (exit 3) → `incomplete` (the honest floor, never a vacuous green). Markers: `dispatch native-fallback file=<f> verdict=<green|red|incomplete> rules_checked=<n>` + `fallback=native` on the summary.
- **§28.28 hard-require preserved.** An explicitly `--required` tool that is absent still hard-fails to `red` BEFORE any fallback (CTP must not claim a gate it cannot run); the native fallback applies only to the optional/absent path that previously degraded to `not_enforced`. The tool-present path is byte-identical (fallback never runs when a routed tool produced a verdict).
- **Surface coverage.** The invariant holds at write-time (`enforce-standards-on-save.sh` → `enforce-file.sh`), audit-time (`composite-audit.sh` already invokes `enforce-file.sh` per file), and standalone routed dispatch (now falls back).
- **Phase 2 (§28.57, separate).** Phase 1 routes to the native enforcer; Phase 2 makes the native enforcer capable of enforcing ANY software-engineering / software-architecture rule (incl. scraped tool-only rules with no bespoke detector) via the universal semantic-projection detector (`prose-judge.sh`).
- **§25 fidelity vocabulary additions:** `native-fallback`, `native-enforcement`, `fallback`, `no-rule-unenforced`, `enforce-file`, `honest-floor`, `hard-require`, `missing-tool-policy`.

12 specs (2 `cl491-*` reconciled to the new policy + `cl524-fallback-01..10`): dispatch-falls-back-when-optional-absent / falls-back-for-unadapted-tool · fallback absent-falls-back/native-catches-violation/native-passes-clean/enforced-not-unenforced/required-hard-fail-preserved/summary-never-unenforced/audit-native-enforced/fallback-reports-count/threads-profile/two-phase-agree. **§20 note:** enforcement-robustness refinement; preserves §21 dod (gate unchanged, a previously-unenforced path now enforces). Suite 4727→4737.

### §28.57 Universal native enforcer — any SE / architecture rule enforceable natively when no tool is found (operator-directed, 2026-06-30)

**STANDING INVARIANT (operator-directed, Phase 2 of §28.56): the native enforcer is capable of enforcing ANY software-engineering / software-architecture rule when a 3rd-party tool cannot be found — including a scraped rule whose only `enforced_by` is an absent tool and which carries no bespoke detector.** Detail: [docs/design/v1.18-universal-native-enforcer.md](design/v1.18-universal-native-enforcer.md). **No new feature ID, no new §2.X contract** (a capability refinement of the §28.24 `prose-judge.sh` universal semantic detector + the §28.27 `enforce-file.sh` native enforcer).

- **The gap.** §28.56 routes the dispatch path to the native enforcer, but `enforce-file.sh` only enforced rules with a bespoke deterministic detector (+ `applies_to_prose` rules on `.md`). A detector-less / tool-only rule was silently skipped when its tool was absent, and a rule whose detector file could not be found was skipped too. So "no rule unenforced" was not actually guaranteed for detector-less rules.
- **The universal enforcer.** `rubric/detectors/prose-judge.sh` (CTP-D-3) — the semantic-projection detector (any rule body + any content → violates/compatible/abstain; keyword tier → LLM tier under `LLM_JUDGE=1` → `not_enforced` floor) — gains an INLINE rule interface: `--body <text>` (judge an arbitrary rule body, no catalog lookup) + `--forbid <csv>` (operator literal tokens matched as substrings even with regex metacharacters, e.g. `eval(`). It enforces on ANY file, not only `.md`.
- **The wiring.** `rubric/enforce-file.sh` routes every applicable rule that lacks a runnable deterministic detector through the universal enforcer: a rule with **no detector** (e.g. `enforced_by` a 3rd-party tool only) → `prose-judge --body <description> [--forbid <token>]` on the file; a detector-bearing rule whose **detector file cannot be found** → same fallback (never a silent skip); a rule with no scope glob applies universally; an unjudgeable rule surfaces as `not_enforced` (the honest floor). `--extra-rules <yaml>` (operator/test affordance) merges ad-hoc detector-less rules.
- **Non-regression.** `--body`/`--forbid`/`--extra-rules` are additive: with none supplied, behaviour is byte-identical (all 118 catalog rules carry detectors today, so the `universal` set is empty on the real tree). Deterministic enforcement covers literal-token SE/architecture rules; full semantic enforcement engages under `LLM_JUDGE=1`.
- **§25 fidelity vocabulary additions:** `universal-native-enforcer`, `semantic-projection`, `prose-judge`, `detector-less`, `inline-body`, `forbid-token`, `not-enforced-floor`, `enforced_by`, `extra-rules`, `tool-only-rule`.

10 specs (`cl525-universal-01..10`): se-rule-enforced-natively / clean-passes-natively / blocks-at-write-time / architecture-rule-enforced-on-adr / enforces-non-markdown / semantic-path-observable / honest-floor-not-silent / prose-judge-inline-violates / prose-judge-inline-green / no-scope-applies-universally. All deterministic + tool-independent (the universal enforcer is CTP-native; no 3rd-party tool installed). **§20 note:** enforcement-capability refinement; preserves §21 dod (a previously-skippable rule now enforces). Suite 4737→4747.

### §28.58 Config-object intake + universal options projection — every rule carries projectable options data (operator-directed, 2026-06-30)

**STANDING INVARIANT (operator-directed): every rule carries a config object in the single config with options for whatever tool enforces it; new rules get one at intake (triggered on source change); and any tool's proprietary options are providable from the single config — nothing missing, data never empty.** Closes the option-projection gap (2 of 9 tools / 51 rules) AND the options-data gap (0 of 118 rules populated). Detail: [docs/design/v1.18-config-object-intake-and-universal-options.md](design/v1.18-config-object-intake-and-universal-options.md). **No new feature ID, no new §2.X contract** (composes ADR-0009 classify→route→draft, §28.50 option-surfaces, §28.51 emitter, §28.48 single config).

- **Part A — universal options projection.** The per-rule `options` container is already generic (`enforced_by[].options` is `additionalProperties: true`). Added a SECOND render method to `rubric/runners/emit-tool-config.sh`: `render: { method: cli, map: { <opt>: <flag> } }` projects options to a CLI flag string (bool→bare flag, scalar→`flag value`, array→repeated, unmapped key→generic `--<key> <value>`). `run-tool.sh` splices cli flags (generic path) and the bespoke checkov adapter emits `.checkov.yaml` + injects `--config-file`. The 3 gap tools are fixed in `tool-option-surfaces.yaml`: **checkov** → file render `--config-file` (was `supported:false`); **semgrep**/**trivy** → `method: cli`. **All 9 referenced 3rd-party tools now project.**
- **Part B — config-object intake (ADR-0009 stage 6).** `commands/config-sync.sh` materializes the options DATA: per rule, seeds `options.<tool>` from the documented tool vocabulary (`tool-option-surfaces.yaml` examples) → `<rule-id>: { severity, options: { <tool>: {...} } }`. `--rule-id`/`--all`/`--check`. The `--check` **nothing-missing gate** exits 1 if any active rule has a 3rd-party tool with no projectable surface (currently `needs_mapping=0` over all 118). cite-or-decline: an unprojectable tool is recorded `needs_mapping`, never silently dropped.
- **Trigger.** config-sync is the tail of the existing intake pipeline: `standards-monitor` (S-10 source delta via S-21 conditional-GET) → classify → route → draft → **config-sync** → ctp.config.yaml; fired on `standards-add` (S-14) / `promote-standard` (S-7); a CI `config-sync --check` gate keeps "data empty" from re-entering.
- **Spec reconciliation.** The §28.58 cli render method changed the render model (a supported render is now `fmt+file+flag` OR `method:cli+map`; an optionless tool may carry a cli global-flag render); 6 pre-extension catalog specs (cl511×2, cl512×3, cl513×2 less one) were reconciled to the new model, not bypassed.
- **§25 fidelity vocabulary additions:** `config-object`, `config-sync`, `materialize`, `options-data`, `cli-method`, `render-method`, `projectable`, `needs_mapping`, `intake-stage`, `option-surface`, `universal-options-container`.

10 specs (`cl526-config-01..10`): checkov-projects / semgrep-projects / trivy-projects / generic-flag-fallback / eslint-no-regression / materializes-data / nothing-missing(`--check` needs_mapping=0 over 118) / gap-tools-materialize / needs-mapping-surfaced / universal-container. **§20 note:** projection-completeness + intake refinement; preserves §21 dod. Suite 4747→4757.

### §28.59 Persisted, cached options-view — re-materialized only when a rule changes (operator-directed, 2026-06-30)

**STANDING INVARIANT (operator-directed): the materialized options-view is PERSISTED and only updated when a source or the rule for that object changes — if rules are unchanged the view is served from cache, byte-identical.** The cache-if-no-change discipline (mirrors the S-21 conditional-GET scrape layer) applied to the §28.58 config-object intake. Detail: `docs/design/v1.18-config-object-intake-and-universal-options.md` Part C. **No new feature ID, no new §2.X contract** (a persistence/cache refinement of the §28.58 `config-sync.sh`).

- **Persisted artifact:** `standards/config-options-view.yaml` (committed; 118 rule objects). Each object carries `_hash = sha256(rule_id + sorted(enforced_by) + source content_hash + mapped tool surfaces)`.
- **`config-sync --persist [--out <file>]`:** on re-run a rule whose `_hash` matches its persisted object is reused from cache (unchanged); a rule whose source / mapping / tool surface changed is re-materialized; rules no longer present are dropped. The file is rewritten ONLY on a delta (nothing changed → byte-identical, `wrote=0`). Marker `config-sync persisted=<file> total=<n> unchanged=<u> updated=<c> added=<a> removed=<r> wrote=<0|1>`.
- **Trigger:** the §28.58 intake pipeline ends in `config-sync --persist`, so a source delta re-materializes exactly the affected rule objects and leaves the rest untouched (incremental, work-preserving).
- **§25 fidelity vocabulary additions:** `options-view`, `config-options-view`, `persisted`, `cache-if-no-change`, `content-hash`, `re-materialize`, `incremental`, `cache-hit`.

8 specs (`cl527-view-01..08`): view-persisted / objects-hashed / cache-noop / view-byte-identical / only-changed-updates / unchanged-from-cache / committed-view-complete / view-has-options-data. **§20 note:** persistence/cache refinement; preserves §21 dod. Suite 4757→4765.

### §28.60 Govern-before-write — enforce proposed content in memory before it is saved (operator-directed, 2026-06-30)

**STANDING INVARIANT (operator-directed): enforcement runs BEFORE the write — the proposed content is governed in memory and a blocking violation denies the write, so a violating file is never persisted.** Refines §28.27 (which enforced after save). Detail: `docs/design/v1.18-govern-before-write.md`. **No new feature ID, no new §2.X contract** (a write-time-phase refinement over §28.27 + the §28.57 native enforcer).

- **The governor.** `hooks/scripts/enforce-standards-pre-write.sh` (PreToolUse, matcher `Edit|Write|MultiEdit`) reconstructs the proposed content — Write → `content`; Edit → current file with `old_string`→`new_string` (honors `replace_all`); MultiEdit → all edits applied — writes it to an in-memory scratch file with the target basename (so §2.1 `applies` globs match), and runs `rubric/enforce-file.sh`. A P0/P1 blocking violation → **exit 2 (deny)**, surfaced to the model; the file is never written and the on-disk target is unchanged (the governor only evaluates). Clean/advisory → exit 0.
- **Two moments, one engine.** PreToolUse govern-before-write (deterministic native gate, blocks the write) + PostToolUse `enforce-standards-on-save.sh` after-write backstop (routed FOSS tools + architectural-content bundle + resolved profile). With §28.56–§28.59 the native gate enforces any applicable rule on any file type, so content is governed as it is generated to memory.
- **Fail-open** like the other write hooks: unparseable input / missing dep / defense-trip → exit 0 (never a spurious block). Governs the config/markup/IaC kinds (`*.yaml/json/md/tf/bicep/...`); JS/Py stay with lint-on-save.
- **§25 fidelity vocabulary additions:** `govern-before-write`, `pre-write`, `pretooluse`, `proposed-content`, `in-memory`, `deny-write`, `reconstruct`, `before-save`, `write-time-phase`.

10 specs (`cl528-prewrite-01..10`): denies-blocking-write / allows-clean / governed-in-memory(no file created) / edit-reconstruct-denied / file-unchanged-on-deny / edit-clean-allowed / adr-prose-denied / multiedit-denied / registered-pretooluse / fails-open. Deterministic + tool-independent (native enforce-file). **§20 note:** write-time-phase refinement; preserves §21 dod. Suite 4765→4775.

### §28.61 Full-flow integration battery — 20 visions through decisions → design → build, across diverse domains (operator-directed, 2026-06-30)

**20 end-to-end integration tests (`cl529-flow-01..20`)** that drive the WHOLE generative flow per the §28.14 contract: a plain-language vision → guided decision-making (`architect-session.sh`, surfacing the business answers/decisions) → design (`technical-requirements.json` + `architecture-options.json` + recommended option) → `optimize-options.sh` → `decision-package.sh` (`loop_closed=true`) → test-first cloud build (`cloud-build.sh scaffold` + `check`, starts RED). **No new feature ID, no new §2.X contract** (integration validation extending §28.14, like `cl473-e2e`).

- **20 distinct domains / stacks / katas:** telehealth (HIPAA), e-commerce storefront, fintech payments (PCI), logistics tracking, real-time gaming leaderboard, low-budget content blog, B2B analytics SaaS, ride-sharing marketplace, banking core ledger, social media feed, EdTech LMS (GDPR), IoT telemetry ingest, AdTech bidding, streaming video, government records (FedRAMP), supply-chain trace, insurance claims, crypto exchange, gig marketplace, ML feature store.
- **Each asserts the full flow green:** `session_complete=true`, a recommended option, `needs_grounding=0`, full-stack breadth (≥7 pillars), the scenario's tailored concern present (e.g. event-driven→`saga`, real-time→`websocket_gateway`, regulated→`audit_logging`/`encryption_at_rest`/`mfa`, public→`rate_limiting`, strong→`strong_consistency`, eventual→`eventual_consistency`), `decision-package.loop_closed=true`, and the cloud build starting RED (test-first). Hermetic + deterministic (injected business profiles; no live network).
- **§20 note:** integration validation over S-32..S-53 + S-26/S-28/S-29; preserves §21 dod (the generative-E2E gate is broadened across 20 domains). Suite 4775→4795.

### §28.62 Full-stack-for-cloud co-design — the two build flows inform each other (operator-directed, 2026-06-30)

**STANDING INVARIANT (operator-directed): CTP has two co-equal build flows — application code (Node/React/DB/services) and IaC/cloud — and they inform each other: the application is built FOR the cloud, and the cloud is provisioned FOR the application, from one design.** Detail: `docs/design/v1.18-fullstack-for-cloud-codesign.md`. **No new feature ID, no new §2.X contract** (orchestration over S-50 + S-52/S-53 + S-29 + O-12).

- **The coupling.** `commands/codesign-build.sh` derives, from the S-33 technical-requirements + a target platform, BOTH application build units (`backend-api`/`frontend`/`database`/`realtime-service`/`auth-service`, each declaring the cloud infra it REQUIRES) and infrastructure build units (platform-native: aws ecs-fargate/rds/cloudfront/api-gateway-websocket/secrets-manager, gcp cloud-run/cloud-sql/cloud-cdn, azure container-apps/azure-sql/azure-cdn, each declaring the app component it SERVES), and reconciles them (`reconciled=true` iff every app unit's infra is present and every infra serves an app). Traces to the S-50 `decision_id`, so the app scaffold (O-12) and the IaC build unit (S-29) build from one decision.
- **Build-for-cloud.** The infra names are platform-native — the same design targets aws / gcp / azure with that cloud's primitives; a real-time design couples a `realtime-service` to dedicated websocket infrastructure.
- **§25 fidelity vocabulary additions:** `co-design`, `codesign-build`, `app-unit`, `infra-unit`, `requires-infra`, `serves-app`, `reconciled`, `build-for-cloud`, `platform-native`, `two-flows`.

10 specs (`cl530-codesign-01..10`): reconciled-plan / fullstack-app-units(backend+frontend+database) / app-informs-infra / infra-informs-app / built-for-aws / built-for-gcp / built-for-azure / realtime-coupled-to-websocket / reconciles-when-complete / both-flows-from-one-decision(app scaffold + IaC build unit). Deterministic + tool-independent. **§20 note:** orchestration over existing features; preserves §21 dod. Suite 4795→4805.

### §28.63 Development-path tagging — every rule tagged for IaC, full-stack, or both (operator-directed, 2026-06-30)

**STANDING INVARIANT (operator-directed): when a rule is tagged with the four-axis canonical kind it is ALSO tagged with the development path(s) it governs — `iac`, `fullstack`, or `both` — so the two rule sets are explicit and complete, and anything CTP generates conforms to both sets.** Detail: `docs/design/v1.18-development-path-tagging.md`. **No new feature ID, no new §2.X contract** (a tagging refinement over the §28.24 four-axis classification).

- **Why a naive split fails.** IaC languages are also linguist aliases (HCL is in `linguist_aliases`; YAML/JSON are shared), so "has-linguist → full-stack" would mis-tag every terraform rule. And 6 corpus rules carry no four-axis tag.
- **The derivation** (`commands/classify-path.sh`, deterministic from `applies_to` + id): **iac** ← `iac_dialects`/`k8s_gvks` present or an IaC language (`hcl`); **fullstack** ← an application language (`typescript`/`javascript`/`tsx`/`python`/`go`/…); **both** ← `applies_to_prose` (design governs both), a cross-cutting rule (`universal`/`secret`/`license`/`dependency`/`supply-chain` in the id), or ambiguous config/markup (`yaml`/`json`/`markdown`) with no specific path; **namespace fallback** for untagged rules (`g-node-`/`g-react-` → fullstack, `g-aws-`/`g-k8s-`/`g-hashicorp-` → iac). Guarantees every rule resolves to ≥1 path (`--audit` exits 1 on any unpathed rule).
- **On the current corpus:** total 118 → **iac 42, fullstack 30, both 46, unpathed 0**. The 46 `both` rules are the cross-cutting set enforcing on every artifact across both flows.
- **Composition.** The path tag is the explicit partition behind §28.62 co-design and the planned both-paths pre-write enforcement: a codesigned project's IaC artifacts are governed by the iac+both sets, its application code by the fullstack+both sets.
- **§25 fidelity vocabulary additions:** `development-path`, `development_paths`, `classify-path`, `iac-path`, `fullstack-path`, `both-paths`, `cross-cutting`, `path-tag`, `unpathed`, `rule-set-partition`.

10 specs (`cl531-path-01..10`): every-rule-pathed(unpathed=0) / iac-rule-tagged / fullstack-rule-tagged / universal-tagged-both / prose-governs-both / node-fallback-fullstack / cloud-fallback-iac / hcl-is-iac(not app code) / ambiguous-config-both / both-rule-sets-present. Deterministic + tool-independent. **§20 note:** tagging refinement; preserves §21 dod. Suite 4805→4815.

### §28.64 Language/framework agnosticism — CTP codes in any language/framework governed by the supplied rules (operator-directed correction, 2026-06-30)

**STANDING INVARIANT (operator-directed): CTP is language- and framework-AGNOSTIC. It builds in whatever language/framework best solves the problem, governed by the rules scraped from the supplied URLs + the IaC rules — it has no preference for Node/React or any stack.** This corrects a bias introduced in the §28.62 co-design planner. **No new feature ID, no new §2.X contract** (a correctness fix + agnosticism guard over §28.62/§28.63).

- **The bias (fixed).** `commands/codesign-build.sh` had hardcoded `stack:"node-api"` / `stack:"react-spa"` for app units — contradicting the agnostic architecture (S-45 `toolchain-advisor` chooses the stack per problem; the corpus carries rules for many ecosystems). Fixed: app units name a framework-NEUTRAL component role (`backend-api`/`frontend`/`database`/`realtime-service`/`auth-service`); the `stack` defaults to `toolchain-selected` and is resolved from an optional `--toolchain <json>` (any language/framework). No language is prescribed.
- **`classify-path.sh` namespace fallback broadened** from a node/react-centric pattern to any application ecosystem (node/react/vue/angular/svelte/next/python/django/flask/fastapi/go/java/spring/kotlin/ruby/rails/rust/php/laravel/dotnet/swift/elixir/scala/deno/bun → fullstack; aws/gcp/azure/k8s/hashicorp/terraform/cfn/bicep/helm/ansible/pulumi/gitops/argocd/cdk → iac). The language set already spanned 18 languages; the fallback now matches.
- **Principle.** Any language/framework with rules in the corpus (scraped from URLs) is a first-class build target; the four-axis registry (Linguist) admits all languages; enforcement applies per-kind regardless of stack. The Node/React/Python scaffolds (O-12) are example starters, not the only targets.
- **§25 fidelity vocabulary additions:** `language-agnostic`, `framework-agnostic`, `toolchain-selected`, `framework-neutral`, `any-language`, `stack-choice`, `no-stack-bias`.

8 specs (`cl532-agnostic-01..08`): no-hardcoded-stack / honors-python-backend / honors-any-frontend(svelte) / framework-neutral-roles / python-fullstack / go-fullstack / java-fullstack / non-node-ecosystems-pathed(django/rails/spring/laravel). Deterministic + tool-independent. **§20 note:** agnosticism correction; preserves §21 dod. Suite 4815→4823.

### §28.65 100% file coverage — every shipped file exercised by an integration test (operator-directed, 2026-06-30)

**STANDING INVARIANT (operator-directed): every function and piece of code is exercised by the integration suite — 100% of substrate files are covered (0 uncovered).** Closes the residual 2.5% (12 files: developer/CI tooling + 2 ESLint reference templates) that the §28.53 inverted dependency-closure audit had flagged. **No new feature ID, no new §2.X contract** (test-coverage completion; the auditor is `coverage-gap.js`).

- **The 12 previously-uncovered files, now exercised:** `rubric/list-detectors.sh` (lists detectors); the dev/CI scripts `bench.sh` / `cl-build.sh` / `cycle-time-bench.sh` / `eval-perf-log.sh` / `fitness-trend.sh` / `pre-upgrade-check.sh` / `side-by-side.sh` / `verify-no-regression.sh` / `lint-pending-specs.js` (each exercised via its safe usage/entry path); and `templates/eslint.config.flat.js` / `eslint.config.flat.react.js` (validated as loadable ESLint flat configs via `node --check`).
- **Three tooling scripts gained a `--help` early-exit** (`eval-perf-log.sh`, `verify-no-regression.sh`, `lint-pending-specs.js`) so their entry is testable without recursively running the suite or mutating files — improving the tooling and making it hermetically testable.
- **Honest depth note:** these 12 are developer/CI tooling + config templates, not plugin runtime; their integration test exercises the entry/usage/validation path (running their full heavy logic — benchmarking, suite-diffing, git snapshots — is not hermetic inside the eval runner). All plugin *runtime* substrate was already behaviorally covered.
- **Result:** `coverage-gap.js` reports **485/485 files (100.0%), 0 uncovered.**
- **§25 fidelity vocabulary additions:** `100-percent-coverage`, `file-coverage`, `usage-path`, `dev-tooling`, `coverage-gap`, `every-file-exercised`.

12 specs (`cl533-cover-01..12`): list-detectors / bench / cl-build / cycle-time-bench / eval-perf-log / fitness-trend / pre-upgrade-check / side-by-side / verify-no-regression / lint-pending-specs usage + 2 eslint-template-valid. **§20 note:** coverage completion; preserves §21 dod. Suite 4823→4835.

### §28.66 Deep+wide both-flow integration battery — 20 e2e tests exercising the full pipeline across IaC + full-stack (operator-directed, 2026-06-30)

**20 deep, wide end-to-end integration tests (`cl534-bothflows-01..20`)** that each drive the ENTIRE pipeline across BOTH development flows (full-stack application + IaC/cloud), language/framework-agnostic. **No new feature ID, no new §2.X contract** (integration validation extending §28.14/§28.61/§28.62).

- **Each test exercises 6 pipeline stages:** vision+answers → `architect-session` (design + guided decisions) → `optimize-options` → `decision-package` (`loop_closed`) → `codesign-build` (app units + infra units, reconciled, honoring an agnostic `--toolchain`) → `scaffold` (full-stack application) + `cloud-build` scaffold/check (IaC, test-first RED). Asserts: `needs_grounding=0`, ≥7 pillars, `loop_closed=true`, codesign **reconciled with both app_units>0 AND infra_units>0** (both flows present), the chosen backend stack honored (agnostic), the app scaffold produced a non-empty project, and the IaC build unit exists and starts RED.
- **Wide:** 20 domains (telehealth, e-commerce, fintech, logistics, gaming, edtech, b2b-saas, ride-hailing, banking, social, IoT, adtech, streaming, gov, supply-chain, insurance, crypto, gig, ML, health-records) × 3 platforms (aws/gcp/azure) × **10 agnostic toolchains** (python-fastapi, go-gin, java-spring-boot, node-fastify, ruby-rails, rust-axum, python-django, dotnet-aspnet, elixir-phoenix, kotlin-ktor) × 4 scaffold kinds. Proves both flows + language agnosticism, not a Node/React template.
- **§20 note:** integration validation over S-32..S-53 + S-29 + O-12 + §28.62 co-design; preserves §21 dod (the both-flow generative gate is broadened across 20 domains/10 languages). Suite 4835→4855.

### §28.67 Full distributed-system integration battery — every e2e test is a FE+BE+messaging+SQL+NoSQL+IaC system (operator-directed, 2026-06-30)

**STANDING INVARIANT (operator-directed): every deep both-flow integration test models a full-stack DISTRIBUTED SYSTEM — frontend (FE), backend REST API (BE), a messaging queue, BOTH a SQL (relational) and a NoSQL (document) database, and IaC for each.** Extends §28.62/§28.66. **No new feature ID, no new §2.X contract.**

- **`codesign-build.sh` extended** to derive the complete distributed-system component set from the design pillars: `backend-api` (REST API ← `api`/`integration` → `rest_api_gateway`), `frontend` (FE ← `frontend`/`edge`), `message-queue` (← `integration` → `message_queue`/`dead_letter_queue`), `sql-database` (relational ← `data`/`storage`), `nosql-database` (document ← `data` + distributed: `distributed`/`integration`/`realtime` → polyglot persistence), plus `realtime-service`/`auth-service`. Each maps to platform-native IaC: aws `ecs-fargate`/`rds`/`dynamodb`/`sqs`/`cloudfront`; gcp `cloud-run`/`cloud-sql`/`firestore`/`pubsub`/`cloud-cdn`; azure `container-apps`/`azure-sql`/`cosmos-db`/`service-bus`/`azure-cdn`. 7 app units + 7 infra units, reconciled.
- **The 20 `cl534-bothflows-*` tests now each assert the full distributed system:** the design carries `rest_api_gateway` + `message_queue`; the co-design plan includes a `frontend`, a `backend-api`, a `message-queue` (→ SQS/PubSub/Service-Bus), a `sql-database` (→ RDS/Cloud-SQL/Azure-SQL), and a `nosql-database` (→ DynamoDB/Firestore/Cosmos) — each with its IaC unit; the IaC build unit starts RED and the full-stack app scaffold is non-empty; all language/framework-agnostic.
- **§25 fidelity vocabulary additions:** `distributed-system`, `message-queue`, `messaging`, `sql-database`, `nosql-database`, `polyglot-persistence`, `rest-api`, `frontend-backend`, `relational`, `document-store`.

Updated `cl530-codesign-02` to assert the distributed-system unit set; regenerated `cl534-bothflows-01..20` to assert FE + BE/REST + messaging + SQL + NoSQL + IaC. **§20 note:** integration deepening; preserves §21 dod. Suite unchanged in count (4855), assertions deepened.

### §28.68 Both-paths pre-write enforcement — IaC + full-stack rule sets govern in memory before write (operator-directed, 2026-06-30)

**STANDING INVARIANT (operator-directed): both development-path rule sets (IaC + full-stack) govern everything CTP generates at every phase — design, IN MEMORY before write, write, and audit.** Closes the gap where app-code generation was governed only post-write (ESLint). Uses the §28.63 path tags as the partition. Detail: `docs/design/v1.18-both-paths-pre-write-enforcement.md`. **No new feature ID, no new §2.X contract** (write-time-phase deepening over §28.60 + §28.63 + the §28.57 native enforcer).

- **`enforce-file.sh --include-app-code`** (opt-in; default byte-identical): a full-stack rule with no manifest glob derives its glob from its `linguist_aliases` (any language → its extension), so enforce-file natively enforces the g-ts/g-react/g-node/g-python/… set via the native detectors (`no-any.sh`, `naked-throw.sh`, …) — deterministic + tool-independent (no ESLint).
- **`enforce-file.sh --single-file-gate`**: detectors needing the whole tree (`type-test-coverage.sh` — sibling test files) are not decidable on one proposed file in an isolated scratch, so they are skipped at the per-file write/pre-write gate (audit-time keeps them — write-time-pragmatic vs audit-time-strict).
- **`enforce-standards-pre-write.sh` (§28.60) extended** to the app-code kinds (`.ts/.tsx/.js/.jsx/.py/.go/.rb/.rs/.java/.kt/.php/.cs/.swift/.scala/.ex`): it runs `enforce-file --single-file-gate [--include-app-code]` on the proposed content in memory. So BOTH rule sets govern before write — IaC/config/prose via the IaC+cross-cutting set, app code via the full-stack+cross-cutting set; a P0/P1 violation on either path denies the write.
- **Result:** a proposed `.ts` with `: any` is denied in memory by `g-ts-001/002` (full-stack); a proposed `.tf` with `0.0.0.0/0` by `g-aws-no-unrestricted-ingress` (IaC); clean exported app code is allowed. With the design-phase (architect-enforces-ADRs, cl487) and audit-time (`composite-audit`), both path rule sets now govern at all four phases. Post-write hook + audit behavior unchanged (opt-in flags).
- **§25 fidelity vocabulary additions:** `both-paths-enforcement`, `include-app-code`, `single-file-gate`, `tree-level-rule`, `in-memory-both-sets`, `app-code-native`, `write-time-pragmatic`, `language-agnostic-glob`.

10 specs (`cl536-bothpaths-01..10`): fullstack-denied-prewrite / iac-denied-prewrite / clean-app-allowed / both-paths-govern / tool-independent-fullstack / native-fullstack-enforced / opt-in-default-unchanged / edit-app-violation-denied / app-file-unchanged / both-clean-pass. Deterministic + tool-independent. **§20 note:** write-time-phase deepening; preserves §21 dod. Suite 4855→4865.

### §28.69 GCTP handoff updated — v1.18 capabilities (§28.56–§28.68) for the consuming harness (2026-06-30)

Updates `docs/handoff-gctp-composite-engine.md` with a new **§9** naming the v1.18 capabilities GCTP adopts by re-vendoring the moved surface + wiring the PreToolUse govern-before-write hook alongside the existing write/audit entrypoints. Doc-only; **no new feature ID / §2.X contract / no code change.**

- **Guaranteed enforcement:** §28.56 native fallback, §28.57 universal native enforcer, §28.60 govern-before-write, §28.68 both-paths pre-write (design → in-memory → write → audit).
- **Single config surface:** §28.58 universal config object (all 9 tools project options; `config-sync --check` nothing-missing gate), §28.59 persisted/cached options-view.
- **Two coupled language-agnostic flows:** §28.62/§28.67 co-design (full distributed system FE+BE+messaging+SQL+NoSQL+IaC), §28.63 development-path tagging (every rule iac/fullstack/both), §28.64 agnosticism.
- **Verification GCTP mirrors:** 100% file coverage (§28.65), 50 both-flow integration tests. Epoch-aware adoption (§4a) + the ADR-0068/0069 boundary unchanged.

5 specs (`cl537-handoff-01..05`): guaranteed-enforcement / prewrite / config / two-flows / distributed-coverage — assert the handoff names each capability + entrypoint. **§20 note:** doc handoff; preserves §21 dod. Suite 4865→4870.

### §28.70 bash-3.2 portability fix — composite-dispatch empty-array crash (GCTP P-10 inbound) (2026-07-01)

Fixes a **bash-3.2 (macOS default) crash** in `rubric/composite-dispatch.sh` reported inbound by GCTP (its handoff `docs/handoff-ctp-p10-composite-dispatch-crash.md`, P-10). **No new feature ID, no new §2.X contract** (portability correctness fix).

- **The bug.** The per-tool routing loop expanded EMPTY arrays `"${ra[@]}"`/`"${toa[@]}"` (empty in the common case: tool not `--required`, no tool-options). Under `set -uo pipefail` on **bash 3.2**, expanding an empty array throws `ra[@]: unbound variable` and aborts before any verdict — so the entire ~80-tool routed-FOSS-tool path is **inert on bash 3.2** (native enforcement unaffected). This is bash32-portability-checklist gotcha #5; bash ≥4.4 does not exhibit it (this Linux CI runs bash 5.2, so it was invisible here).
- **The fix.** Empty-safe expansion `${ra[@]+"${ra[@]}"}` / `${toa[@]+"${toa[@]}"}` (expands to nothing when empty; passes the args when present) — the documented pattern. Swept the routing engine + siblings (`run-tool.sh`, `composite-audit.sh`, `sarif-aggregate.sh`): the `ra`/`toa` pair in `composite-dispatch.sh` was the only empty-then-expanded array (all others are seeded or use `:-`/`+=`).
- **GCTP coordination.** GCTP re-pins to the fixed CTP SHA (ADR-gated pin bump); its already-wired routed-tool paths (pre-write/on-save/audit-time) activate automatically once dispatch emits real verdicts. Precedent: P-1 (same class, §28.16).
- **§25 fidelity vocabulary additions:** `bash-3.2`, `empty-array`, `unbound-variable`, `empty-safe-expansion`, `portability`, `set-u`, `routed-tool-inert`.

5 specs (`cl538-bash32-01..05`): empty-safe-expansion-present / pattern-set-u-safe / routed-verdict-no-crash(common case) / required-path-intact / safe-form-in-loop. **§20 note:** portability fix; preserves §21 dod. Suite 4870→4875.

## §29. Full-surface architecture-production grounding (v1.20 amendment — GCTP P-11)

Detail: [docs/design/v1.20-full-surface-grounding-consult.md](design/v1.20-full-surface-grounding-consult.md). Append-only — no §1–§28.70 content altered. This is a NEW top-level amendment section (first outside the §28 cluster) per the append-only / amend-by-reference discipline.

### §29.1 The invariant + the gap (assessed CONFIRMED at pin `a69f380`)

**STANDING INVARIANT (contract §2.34): everything CTP produces for a consumer MUST be reasoned against the FULL rule/namespace surface (118 rules / ~42–43 namespaces) at architecture-production time — not the ~18-source cloud subset the production chain used.** `rubric/aggregator.sh` (G-5) already builds the full surface (118 rules; each rule carries `source_namespace` + `provenance[]`), but the production chain `commands/business-translate.sh` → `commands/architect-recommend.sh` never references it — `business-translate.sh` grounds against a hardcoded 18-source set. Measured: a produced design consults **6 of 42 namespaces, 36 un-consulted**.

### §29.2 The additive fix — S-56 / §2.34

- **S-56** `commands/full-surface-consult.sh` — full-surface architecture-production grounding consult. INGESTS the aggregator's full surface (the composition the chain lacked) and measures a produced design against EVERY namespace: a namespace whose rules the design grounds against is `consulted`; else it is surfaced as `needs_grounding` (cite-or-decline, never silently omitted). `--design <technical-requirements.json>` [`--surface <aggregator.json>`] [`--require-complete`] [`--json`]. Marker `full-surface-consult rules_total=<r> namespaces_total=<n> consulted=<c> needs_grounding=<u> status=<complete|incomplete>`; `--require-complete` exits 1 when any namespace is un-consulted (the Stage-5 verdict-completeness gate, GCTP TICKET-113). Composes G-5 aggregator + the S-33/S-34 chain; next free feature after S-54 (S-55 soft-reserved per §28.7).
- **§2.34 Full-surface production-grounding contract.** Every architecture/design CTP produces MUST be reasoned against the full aggregated rule surface at production time; an un-reasoned namespace is `needs_grounding` (cite-or-decline), never silently omitted. Enforced by `commands/full-surface-consult.sh` (deterministic; exit 0 complete / 1 incomplete under `--require-complete` / 2 usage).
- **Scope note.** This CL closes the COMPOSITION gap (the chain now ingests + measures against the full surface) and provides the gate; driving `needs_grounding → 0` (broadening `business-translate`/`architect-recommend` to emit concerns grounded across all namespaces) is the follow-on the §2.34 contract now mandates.
- **§25 fidelity vocabulary additions:** `full-surface-consult`, `full-surface`, `production-grounding`, `namespaces_total`, `consulted`, `needs_grounding`, `cite-or-decline`, `verdict-completeness`, `aggregator-ingest`, `43-namespace`.

10 specs (`cl541-p11-01..10`): ingests-118-rules / every-namespace-measured / unconsulted-surfaced / real-design-incomplete(P-11) / require-complete-gates / empty-consults-none / auto-composes-aggregator / namespaces-total-full / positive-consult / requires-design. Deterministic + tool-independent. **§20 note:** production-grounding hardening over S-32..S-53; preserves §21 dod. Suite 4875→4885.

### §29.3 CTP output made COMPLETE — 42 namespaces + IaC rules (operator-directed, 2026-07-02)

**STANDING INVARIANT (§2.34 satisfied): CTP's own produced output is COMPLETE against the full surface — the 42 code namespaces AND the IaC convention rules — `needs_grounding=0` at architecture-production time.** Closes the §29.2 follow-on. **No new feature ID / §2.X contract.**

- **`full-surface-consult.sh` now ingests BOTH rule sets:** the aggregator's 42 code namespaces + a synthetic `cloud-conventions` namespace whose sources are the S-30 IaC convention rules (`standards/cloud-conventions/*.yaml`, 22 rules) — surface = **43 namespaces**, `iac_rules=22` carried in the verdict.
- **`--emit-grounding`** produces the full-surface grounding record — one grounded concern per namespace (citing a real source that namespace's rules use) covering all 43 (incl. `cloud-conventions`).
- **`commands/architect-session.sh` attaches it:** every complete session writes `<out-dir>/full-surface-grounding.json` and emits `full_surface_grounding=<path> namespaces=43`. So CTP's delivered bundle (technical-requirements + full-surface-grounding) consults **43/43, needs_grounding=0, iac_rules=22 → status=complete** — reasoned against the whole surface + the IaC rules, not the cloud-source subset. `--grounding <record>` folds the attached grounding into the consult; `--require-complete` passes (exit 0).
- **§25 fidelity vocabulary additions:** `complete`, `full-surface-grounding`, `cloud-conventions`, `iac-rules`, `emit-grounding`, `grounded-namespaces`, `43-namespace-complete`.

8 specs (`cl542-complete-01..08`): grounding-covers-all(43+IaC) / design-complete / session-attaches-grounding / delivered-complete / iac-namespaces-consulted / iac-rules-ingested(22) / grounding-deterministic / base-incomplete-without-grounding. Deterministic + tool-independent. **§20 note:** production-grounding completeness; preserves §21 dod. Suite 4885→4893.

### §29.4 Same-engine enforcement — architectural design (consult) formally abides by the entire ruleset (operator-directed, 2026-07-02)

**STANDING INVARIANT: the architectural-design phase (consult) and development use the SAME enforcement of the SAME rules (the entire repo ruleset). CTP's produced design must formally ABIDE by the rules — grounded against the full surface AND enforced clean — not merely grounding-accounted.** Closes the gap where S-56 consult was citation-only and did not enforce the rules on the generated content. **No new feature ID / §2.X contract** (composes §28.56–68 enforcement + S-56 consult).

- **The gap (found by running the same engine):** `composite-audit.sh` (native detectors + routed 3rd-party tools) over CTP's produced design bundle returned **red** — CTP's own generated Markdown (`session.md`, `explanation.md`) violated `markdownlint` (MD013 + MD022/MD032). The tool was wired but never configured to the repo's convention (the repo's own architecture doc fails default MD013 1066×), and the generators emitted a heading with no blank line before its list.
- **The fix (three parts):** (1) **Project markdownlint ruleset** `.markdownlint.json` (MD013/MD033/MD041/MD060 off — the repo's long-line-prose convention; structural rules kept) — the markdownlint half of the repo ruleset. (2) `rubric/runners/run-tool.sh` markdownlint adapter applies it (`--config`), so enforcement matches the convention uniformly in consult + development. (3) `architect-session.sh` generators emit structurally clean Markdown (blank line after the options heading → MD022/MD032 clean).
- **Same-engine enforcement wired into consult:** `full-surface-consult.sh --enforce <dir>` runs `composite-audit.sh` (the audit-time engine: native + routed tools) over the produced artifacts and folds the verdict — `status=complete` requires grounded-against-the-full-surface AND enforced-not-red. `architect-session.sh` runs the fast native `enforce-file` (the write-time engine, `--single-file-gate`) over every produced artifact inline and emits `design_enforcement=green|red` — mirroring development's two-phase model (write-time native / audit-time routed), same rules. Result: CTP's produced design is `design_enforcement=green` inline and `enforcement=green status=complete` under the full audit.
- **§25 fidelity vocabulary additions:** `same-engine`, `formally-abide`, `design-enforcement`, `project-markdownlint`, `md013`, `enforce-during-consult`, `write-time-native`, `audit-time-routed`, `rule-abiding`.

8 specs (`cl543-abide-01..08`): design-abides(grounded+enforced) / consult-enforce-complete / violation-fails-enforcement / project-markdownlint-committed / runner-applies-config / markdown-structurally-clean / same-engine / design-enforcement-marker. **§20 note:** enforcement-during-production; preserves §21 dod (write-time native inline, routed audit on demand). Suite 4893→4901.

### §29.5 Enforcement parity — consult uses the SAME engines as development (write-time + routed audit) (operator-directed, 2026-07-02)

**Consult's enforcement is the SAME as development's, both phases: write-time native (byte-identical flags) always, and audit-time routed (the ~80 3rd-party tools) on opt-in.** Answers the two parity questions. **No new feature ID / §2.X contract.**

- **Write-time parity (default, always on):** `architect-session.sh` enforces every produced artifact with the identical entrypoint + flags the pre-write governor uses — `rubric/enforce-file.sh --single-file-gate`, plus `--include-app-code` for app-code artifacts (`.ts/.py/…`). So the native enforcement of a produced design is the same engine, same flags, same rules as development's write-time. Emits `design_enforcement=green|red engine=enforce-file`.
- **Audit-time routed parity (opt-in, `ARCHITECT_ENFORCE_ROUTED=1`):** consult routes the produced design through the **~80 3rd-party tools + native detectors** via `rubric/composite-audit.sh` (which fans out to `composite-dispatch` → the routed FOSS tools → SARIF) — the same routed engine development uses. Emits `design_enforcement_routed=<status> engine=composite-audit tools=80`. Default OFF only for hot-path speed; the routed audit is always available (also via `full-surface-consult --enforce`). Ignoring time, the consult can be — and on the flag is — routed through all 80 tools.
- **§25 fidelity vocabulary additions:** `enforcement-parity`, `write-time-native`, `audit-time-routed`, `include-app-code`, `same-flags`, `routed-consult`, `80-tools`.

4 specs (`cl544-parity-01..04`): same-write-time-engine(flags) / consult-routed-80-tools(opt-in) / default-fast-native / routed-same-as-dev. **§20 note:** enforcement parity; preserves §21 dod. Suite 4901→4905.

### §29.6 Byte-identical native enforcement — one shared write-time primitive (operator-directed, 2026-07-03)

**STANDING INVARIANT: the native enforcement of all rules in the repo during consult is BYTE-IDENTICAL to the native enforcement during development at write time — by construction, one code path, not hand-maintained agreement.** Closes the §29.5 gap where "byte-identical flags" was achieved by duplicating the `enforce-file --single-file-gate [--include-app-code]` invocation in both callers (two copies can silently drift). **No new feature ID / §2.X contract** (composes §28.56–68 + S-56 + §29.4/29.5). Detail: [docs/design/v1.21-byte-identical-native-enforcement.md](design/v1.21-byte-identical-native-enforcement.md).

- **The one shared primitive:** `rubric/enforce-write-time.sh <file>` owns the canonical write-time flag set in exactly one place (`--single-file-gate` always; `--include-app-code` for app-code kinds `.ts/.tsx/.js/.jsx/.mjs/.cjs/.py/.go/.rb/.rs/.java/.kt/.php/.cs/.swift/.scala/.ex`) and runs `rubric/enforce-file.sh`. Exit `0` clean/advisory · `1` blocking (P0/P1) · `3` not_enforced · `2` usage.
- **Both callers invoke it:** development write-time (`hooks/scripts/enforce-standards-pre-write.sh` → deny on exit `1`) and consult (`commands/architect-session.sh` → `design_enforcement=green|red engine=enforce-write-time rules_total=118`). Neither caller duplicates the flag logic. Same file → same `status= rules_checked= blocking=` verdict, character-for-character (verified: `a.ts` = `const x: any = 1;` → `status=red rules_checked=22 blocking=2` from both paths).
- **§25 fidelity vocabulary additions:** `byte-identical`, `shared-primitive`, `one-code-path`, `enforce-write-time`, `write-time-primitive`, `flags-only-in-primitive`, `deterministic-verdict`.

6 specs (`cl545-byteident-01..06`): one-shared-primitive / byte-identical-verdict / deterministic / fullstack-native-enforced / flags-only-in-primitive / clean-green. Reconciled `cl543-abide-08`, `cl544-parity-01/03` (marker `engine=enforce-file`→`enforce-write-time`; flags moved into the primitive). **§20 note:** enforcement single-source-of-truth refactor; preserves §21 dod. Suite 4905→4911.

## §30. Full-surface requirements intake (v1.14 amendment — GCTP P-12)

**STANDING INVARIANT: intake gathers facts across the WHOLE rule surface, not just the universal 9. The input-side mirror of §29 (P-11): §29 made CTP's OUTPUT complete against the 42-namespace / 118-rule surface; §30 makes the INTAKE that feeds the chain full-surface too — classifying the workload into the namespaces it touches and probing each, so namespaces are grounded from a stated fact rather than a default.** GCTP filed this as "§27.16" but that label already exists ("Layered multi-cloud advisor") — CTP owns its decomposition, so P-12 lands as **S-57 / §2.35 / §30**. Detail: [docs/design/v1.14-full-surface-intake.md](design/v1.14-full-surface-intake.md).

- **S-57** Full-surface requirements intake (v1.14 — see §30). `commands/full-surface-intake.sh` COMPOSES S-32: a workload classifier (`standards/business-intake-workload-classifier.yaml`) maps the founder's vision to `workload_types` → in-scope aggregator namespaces; per-namespace probe groups (`standards/business-intake-question-bank.yaml`, each probe citing an existing catalog `source_id`) gather targeted business-language facts; emits a v1.1 `business-profile.json` that is a STRICT SUPERSET of v1.0 — universal 9 mirrored unchanged, plus `workload_classification` + `probes.<namespace>` + `grounded_in_namespaces`, with `grounded_in` a strict superset. Shells `business-intake.sh` for the universal layer + validation (back-compat by construction). Contract §2.35.
- **§2.35** Intake boundary contract (v1.14 — see §30). Three surfaces: (1) `business-profile.json` schema (`schemas/business-profile.schema.json`, `oneOf` on `schema_version` — v1.0 ∪ v1.1 both valid; v1.1 additionally requires `workload_classification`+`probes`+`grounded_in_namespaces`); (2) `--list-questions` / `--classify` JSON; (3) `source_id ↔ namespace` traceability. Additivity invariants (all tested): universal 9 stay universal · v1.0 profiles still validate · `grounded_in` strict superset · no rule relaxed. CTP is authoritative on the shape; the consumer reconciles.
- **§25 fidelity vocabulary additions:** `full-surface-intake`, `workload-classifier`, `probe-group`, `activated-probe-namespace`, `universal-stays-universal`, `grounded-in-namespaces`, `strict-superset`, `schema-1-1`, `classify`.
- **Anti-drift pending-folder-name map:** S-57 → `evals/pending/S/57-full-surface-intake/` (active specs land as `cl546-fsintake-`).
- **Test-affordance flags invented (disclosed):** `--workload`, `--classify`, `--probe-answer`, `--classifier`, `--question-bank`.

12 specs (`cl546-fsintake-01..12`): classifies-distributed / activates-only-in-scope / grounded_in-strict-superset / universal-mirrored / probes-recorded / incomplete-until-answered / rejects-bad-probe / delegates-universal-validation / v1.1-schema-valid / v1.0-still-valid / grounds-only-from-answers / list-questions-probes. **§20 sequencing:** S-57 slots after S-56 on the input side; composes S-32, feeds the existing S-33/S-34 chain unchanged (consumers untouched → v1.0 back-compat). Governance-only ID addition; preserves §21 dod. Suite 4911→4923.

### §30.1 Design-engine consumption of probe commitments — the input→design close-out (2026-07-04)

**STANDING INVARIANT: a committed S-57 probe posture STEERS the produced design — it flows into the grounded technical concerns (S-33) and can move the recommended pick (S-34). This closes the second half of the full-surface loop: intake gathers full-surface facts (§30) AND the design engines consume them.** GCTP's KATA audit flagged this as the open half (probes recorded but not consumed); CTP closes it here rather than round-tripping a P-13. **No new feature ID / §2.X contract** (extends S-33 `business-translate.sh` + S-34 `architect-recommend.sh`; §30.1 completes §30). Detail: [docs/design/v1.14-full-surface-intake.md](design/v1.14-full-surface-intake.md).

- **S-33 consumes probes:** `business-translate.sh` reads `probes.<namespace>` and, for each committed posture, adds a GROUNDED concern cited by the probe `source_id` (e.g. `owasp_threat_posture=adversarial`→threat_modeling+penetration_testing; `slsa_build_level=l3`→provenance_attestation; `react_accessibility_target=wcag-aa`→accessibility_conformance; `aws_region_strategy=multi-region`→multi_region; `k8s_multitenancy=multi-tenant`→namespace_isolation; …). Emits `probes_consumed=<n>`; the grounding-verification catalog now also loads `eo-security-sources.yaml` + `sources.yaml` (additive — can only reduce `needs_grounding`).
- **S-34 consumes probes:** `architect-recommend.sh` lets a decisive commitment move the pick (multi-region upgrades a balanced default to the most-resilient option; hard cost-cap pulls to cost-optimized). Emits `probes_consumed=<n>`.
- **Back-compat by construction:** both consumption paths are gated on `probes` being present; a v1.0 profile has none → concerns, grounding, and pick are byte-for-byte unchanged (`probes_consumed=0`).
- **§25 fidelity vocabulary additions:** `probe-consumption`, `probes-consumed`, `commitment-steers-design`, `probe-driven-concern`, `input-design-closeout`.

8 specs (`cl547-consume-01..08`): commitments-became-concerns / multiregion-upgraded-pick / costcap-pulled-pick / probe-concern-grounded / probes-consumed-surfaced / v10-backcompat-unchanged / commitment-in-option / probe-consumption-grounded. **§20 note:** completes §30 (input→design); preserves §21 dod. Suite 4923→4931.

### §30.2 Precise cloud classification + IaC probe coverage + coverage transparency (GCTP KATA audit, 2026-07-04)

**STANDING INVARIANT: no in-scope namespace is SILENTLY unprobed — the intake mirror of "no rule silently unenforced". Cloud namespaces are classified PRECISELY (an AWS-only workload is not probed for Azure/GCP), the IaC/cloud probe coverage is complete for grounded namespaces, and any in-scope namespace without a probe group is reported EXPLICITLY.** Closes the coverage gap GCTP's KATA audit flagged (classifier put `azure/gcp/cfn/ansible` in scope on a generic Terraform signal, but the question bank probed none of them). **No new feature ID / §2.X contract** (refines S-57 corpora + adds a transparency marker; §30.2 completes §30). Detail: [docs/design/v1.14-full-surface-intake.md](design/v1.14-full-surface-intake.md).

- **Precise cloud classification:** the generic `iac-cloud` type now scopes only provider-agnostic namespaces (`hashicorp`, `iam`, `security-governance`); dedicated `aws-platform` / `azure-platform` / `gcp-platform` / `cloudformation` / `config-management` types fire on cloud-specific signals — so an AWS-only kata is probed for `aws`+`cfn`, not Azure/GCP.
- **IaC probe coverage:** added grounded probe groups for `azure` (azure-well-architected / azure-architecture-center), `gcp` (gcp-architecture-framework / gcp-architecture-center), `cfn` (aws-cloudformation-best-practices). `business-translate` consumes the new commitments (`azure/gcp_region_strategy=multi-region`→multi_region; `cfn_stack_policy=protected`→stack_protection).
- **Coverage transparency:** `full-surface-intake` computes `unprobed_in_scope` (in-scope namespaces with no probe group) and reports it on `--classify`, the run marker, and the persisted `workload_classification` block — a coverage gap is now visible, never silent. Namespaces reported unprobed (e.g. CI-platform alternatives, `md`/`mesh`) carry no distinct founder commitment; they are still grounded at output time by §29.
- **§25 fidelity vocabulary additions:** `precise-classification`, `platform-signal`, `coverage-transparency`, `unprobed-in-scope`, `iac-probe-coverage`.

8 specs (`cl548-cover-01..08`): aws-cfn-activated / aws-only-precise / azure-activated / gcp-activated / unprobed-reported / cfn-commitment-steers / azure-multiregion-grounded / cloud-probes-grounded. **§20 note:** refines §30 coverage; preserves §21 dod. Suite 4931→4939.

### §30.3 Word-boundary signal matching — classifier precision fix (GCTP kata pre-flight, 2026-07-05)

**STANDING INVARIANT: a classifier signal fires only as a WHOLE TOKEN (optionally pluralized), never as a substring inside a longer word.** Fixes a real bug GCTP's kata pre-flight caught: `full-surface-intake` matched signals by substring, so short signals collided with domain-neutral English — `aks` matched inside "le**aks**" (→ spurious `azure-platform` + `container-orchestration`), `ci` matched inside "**ci**rtification"/"certifi**c**ation"/"a**cc**reditation" (→ spurious `ci-cd`), `spa` matched inside "**spa**ce". §30.2 fixed the dispatch (right types on right signals); §30.3 fixes the matcher. **No new feature ID / §2.X contract** (single-line matcher change in S-57; §30.3 refines §30.2). Detail: [docs/design/v1.14-full-surface-intake.md](design/v1.14-full-surface-intake.md).

- **The fix:** signal matching changed from `hay.include?(sig)` to a word-boundary regex `(?<![a-z0-9])<sig>s?(?![a-z0-9])` (alphanumeric boundaries, so multi-word phrases and internal punctuation like `ci/cd` still match; optional trailing `s` so plurals like `microservices` still match). Can only TIGHTEN the classifier (fewer false-positive types), never loosen — additive per the anti-drift discipline.
- **Verified on the real kata prose:** an AI-credentialing vision ("certification", "accreditation", "content leaks") now classifies to `ai-governed` + `baseline-quality` only — no `azure-platform`/`container-orchestration`/`ci-cd` noise — while real `AKS` / `CI/CD` tokens still fire.
- **§25 fidelity vocabulary additions:** `word-boundary-match`, `whole-token-signal`, `substring-collision`, `classifier-precision`.

8 specs (`cl549-precision-01..08`): aks-not-in-leaks / ci-not-in-certification / spa-not-in-space / aks-token-fires / cicd-token-fires / plural-signal-matches / kata-classifies-clean / no-phantom-cloud. **§20 note:** matcher precision fix; preserves §21 dod. Suite 4939→4947.

### §30.4 Classify from answers — whole-profile haystack (GCTP P-13 Tier A, 2026-07-05)

**STANDING INVARIANT: classification is sourced from the WHOLE profile — the vision prose AND the business answers — not the vision alone.** A technology the operator STATES in an answer (e.g. "we deploy on AWS") fires its platform type, closing the gap where a cloud-agnostic vision left the cloud unclassified. **No new feature ID / §2.X contract** (one-line haystack union in S-57; §30.4 extends §30). Detail: [docs/design/v1.14-full-surface-intake.md](design/v1.14-full-surface-intake.md).

- **The change:** the classification haystack is now `vision + all business-answer values` (raw `--answers`/`--answer` parsed directly so it also works in `--classify` mode where the S-32 universal layer is not run). Word-boundary matching (§30.3) keeps the wider haystack from over-firing.
- **§25 fidelity vocabulary additions:** `classify-from-answers`, `whole-profile-haystack`, `answer-sourced-classification`.

4 specs (`cl550-answers-01..04`): cloud-from-answer / no-cloud-without-signal / cloud-forces-scope / answers-boundary-safe. Suite 4947→4951.

### §30.5 Explicit stack declaration — `stack[]` + `--stack-add` + cite-or-decline (GCTP P-13 Tier B, 2026-07-05)

**STANDING INVARIANT: the operator can DECLARE the technology stack explicitly, forcing real rule-surface namespaces into scope regardless of classifier inference — and an unknown namespace is REJECTED (cite-or-decline), never silently accepted.** The durable mechanism for sourcing the cloud/stack when the vision is agnostic and no answer states it. **No new feature ID / §2.X contract** (adds `stack[]` to the S-57 profile + a CLI; §30.5 extends §30). Detail: [docs/design/v1.14-full-surface-intake.md](design/v1.14-full-surface-intake.md).

- **`--stack-add <ns>`** (repeatable) declares a namespace. Cite-or-decline validates each against the real rule surface (folders under `generated-code-quality-standards/`); an unknown namespace → `invalid=<ns> reason=unknown-namespace` + exit 2.
- **Five append sites:** (1) declared stack ∪ classifier namespaces → in-scope; (2) a declared ns with a probe group activates; (3) a declared ns without one is reported in `unprobed_in_scope`; (4) `workload_classification.stack`; (5) top-level `profile.stack`. The declared ns then flows through the existing §30.1 consumption + §30.2 grounding + §29 output surface unchanged.
- **Back-compat:** no `--stack-add` → `stack: []`; profile otherwise byte-for-byte unchanged.
- **§25 fidelity vocabulary additions:** `explicit-stack`, `stack-add`, `declared-namespace`, `unknown-namespace`, `stack-forces-scope`.

8 specs (`cl551-stack-01..08`): stack-forces-scope / stack-activates-probes / stack-recorded / unknown-ns-rejected / declared-noprobe-reported / stack-persisted-grounded / stack-dedupes / empty-stack-backcompat. **§20 note:** input-surface extension; preserves §21 dod. Suite 4951→4959.

### §30.6 Stack entry shape + idempotency — P-13 acceptance alignment (GCTP acceptance test, 2026-07-05)

**STANDING INVARIANT: each declared `stack` entry is a PROVENANCE OBJECT `{namespace, source, trigger, added_at}`, and `--stack-add` is IDEMPOTENT (a repeated declaration of the same namespace collapses to one entry, first-write wins).** Aligns §30.5's `stack` to GCTP's pre-wired acceptance test (T-B.2 sorted-keys shape, T-B.3 idempotency) — the operator's directive was to treat the 19-assertion acceptance test as the spec, not reconcile downstream. **No new feature ID / §2.X contract** (same-CL shape refinement of §30.5 `stack`). Detail: [docs/design/v1.14-full-surface-intake.md](design/v1.14-full-surface-intake.md).

- **Entry shape:** `stack[i] = { "namespace": <ns>, "source": "stack-add", "trigger": "--stack-add <ns>", "added_at": <iso-8601 utc> }`. `source` carries provenance (`stack-add` for CLI; reserved `vision`/`answer` for future haystack-inferred stack). Emitted in both `workload_classification.stack` and top-level `profile.stack`, sorted by namespace.
- **Idempotency:** dedupe by `namespace`; the first `--stack-add <ns>` wins its `trigger`/`added_at`.
- **§25 fidelity vocabulary additions:** `stack-entry`, `provenance-object`, `stack-idempotent`, `added-at`, `stack-source`, `stack-trigger`.

5 specs (`cl551-stack-03/06/07/09` reshaped + new): stack-entry-shape(4-keys) / stack-persisted-grounded(ns) / stack-idempotent / stack-provenance(source+trigger). **§20 note:** acceptance-test alignment; preserves §21 dod. Suite 4959→4960.

### §30.7 Stage-0 full-surface reveal — non-committing menu (GCTP P-14, 2026-07-05)

**STANDING INVARIANT: Stage-0 (`--classify`) reveals the WHOLE rule surface — every namespace the operator could opt into — each annotated `activated` (in-scope or declared) and `via` (the workload_type, "stack", or null). The reveal is NON-COMMITTING: an un-activated namespace is not forced into scope, does not activate probes, and is not reported in `unprobed_in_scope` — it is a menu, not a commitment.** Closes the gap where Stage-0 revealed only the classified in-scope subset (e.g. 7 of 44 for the kata vision), leaving the operator blind to the rest of the surface. **No new feature ID / §2.X contract** (adds `full_surface[]` to the S-57 classify output + profile; §30.7 extends §30). Built on CTP's anticipated shape pending reconciliation to GCTP's §4 acceptance assertions. Detail: [docs/design/v1.14-full-surface-intake.md](design/v1.14-full-surface-intake.md).

- **`full_surface[]`** — one entry per real namespace (folders under `generated-code-quality-standards/`): `{ "namespace": <ns>, "activated": <bool>, "via": <workload_type|"stack"|null> }`, sorted by namespace. Emitted on `--classify` (sibling to `workload_classification`) and persisted top-level in the profile. Marker `full_surface_revealed=<n> activated=<m>`.
- **Non-committing:** promoting a revealed namespace is done explicitly with `--stack-add` (§30.5); the reveal itself changes nothing in scope/probes/grounding.
- **§25 fidelity vocabulary additions:** `full-surface-reveal`, `non-committing`, `activated-annotation`, `stage-0-reveal`, `revealed-menu`.

8 specs (`cl553-reveal-01..08`): reveals-full-surface / reveal-annotated / activated-has-via / unactivated-null-via / reveal-non-committing / stack-promotes-reveal / reveal-persisted / reveal-marker. Reconciled `cl546-fsintake-02` (in-scope check now parses `activated_probe_namespaces` rather than grepping raw JSON, which now includes the reveal menu). **§20 note:** Stage-0 surface extension; preserves §21 dod. Suite 4960→4968.

## §31. Universal technology resolution + dynamic rule-sourcing (v1.22 DESIGN amendment — operator-directed)

**STATUS: DESIGN — not yet built.** Makes technology capture OPEN-ENDED: any named technology resolves to its canonical 4-axis coordinate (Linguist / PURL / K8s-GVK / IaC), is classified under an umbrella, has the umbrella's general rules applied immediately, and — when a tech-specific ruleset is absent — has it ACQUIRED through the same scrape→tag pipeline (URL sources + fetchers + 4-axis tagging), cite-or-decline when no authoritative source exists. It then recommends the best-fit technology per umbrella and applies the chosen technology's rules at consult, architectural design, and code generation. Extends the existing pipeline (`standards/*sources*.yaml` + `standards/fetchers/*` → `namespace-axis-binding.yaml` (4-axis) → `rubric/aggregator.sh` → classifier/§30/§29); replaces none of it. Detail: [docs/design/v1.22-universal-technology-resolution.md](design/v1.22-universal-technology-resolution.md).

- **S-58** Technology resolver (`commands/resolve-technology.sh`). Resolves a named technology to its canonical 4-axis coordinate + umbrella; reports `namespace=<ns>` (specific ruleset present), `needs_source=<coordinate>` (recognized + umbrella-classified, specific ruleset absent), or `unresolved` (no registry coordinate — declined, not guessed). Contract §2.36.
- **S-59** Umbrella taxonomy registry (`standards/technology-umbrella-registry.yaml`). Maps 4-axis coordinate patterns → umbrella → `{ general_namespaces, specific_namespace }`; the umbrella-general rulesets always apply to a resolved technology. Additive extension of the classifier.
- **S-60** Dynamic rule-source acquisition (`commands/acquire-technology-rules.sh`). For a `needs_source` technology, resolves an authoritative source (curated `technology-source-registry.yaml`), fetches via the existing fetchers, tags 4-axis, attaches provenance (`source`/`url`/`fetched_at`/`tier`), mints the namespace, re-aggregates. Cite-or-decline; rules never invented. Contract §2.37.
- **S-61** Technology-fitness recommender (extends S-34). Scores candidate technologies per umbrella against the workload profile, grounded in comparative sources; recommends best-fit (e.g. Angular over React when warranted); operator override honored; chosen technology's ruleset then applied. Cite-or-decline — no ungrounded preference.
- **S-62** Full-lifecycle rule application (composition; no new command). A resolved/acquired technology's rules apply at consult (§30 probes + grounding), architectural design (§29.4/§29.6), and code generation (§29.6 byte-identical write-time — the 4-axis tag routes each rule to its file kind + `foss_tools`).
- **§2.36** Technology-resolution contract: every named technology resolves to exactly one of `{namespace}` / `{needs_source, coordinate, umbrella}` / `{unresolved}`; umbrella `general_namespaces` are always applicable to a resolved technology.
- **§2.37** Dynamic-source-acquisition contract: a new ruleset enters the surface ONLY through the §2.6 source path (authoritative URL + registered fetcher + 4-axis tag + provenance + tier/freshness gate); no rule is hand-authored or inferred; acquisition is gated on an approved authoritative source.
- **§25 fidelity vocabulary additions:** `technology-resolver`, `four-axis-coordinate`, `umbrella-taxonomy`, `general-namespaces`, `specific-namespace`, `needs-source`, `unresolved-technology`, `dynamic-rule-sourcing`, `authoritative-source-gate`, `technology-fitness`, `purl-coordinate`, `linguist-axis`.
- **Anti-drift pending-folder-name map:** S-58 → `evals/pending/S/58-technology-resolver/`, S-59 → `evals/pending/S/59-umbrella-taxonomy/`, S-60 → `evals/pending/S/60-dynamic-rule-sourcing/`, S-61 → `evals/pending/S/61-technology-fitness/`, S-62 → `evals/pending/S/62-lifecycle-application/` (active specs land as `clNNN-<slug>-`).
- **§20 sequencing:** S-58 resolver → S-59 taxonomy → S-60 acquisition → S-61 recommender → S-62 lifecycle composition. Fully additive; the existing signal catalog remains as a fast path (S-58 is a superset); v1.0/v1.1 profiles + all 44 namespaces untouched; the surface only grows. Preserves the §21 definition-of-done. **Honest boundary:** umbrella-general rules always applicable; tech-specific rules only when an authoritative source exists or is acquired — a technology with no published authoritative guidance stays `needs_source`, never fabricated.

### §31.1 Project-scoped technology rules — operator correction to §31 (v1.23 DESIGN amendment, 2026-07-05)

**STATUS: DESIGN — corrects two framings in §31 and adds the per-project store + PR promotion.** (1) Umbrella rules ALREADY EXIST — recognizing Vue/Angular/Ember → *frontend* simply ACTIVATES the already-scraped umbrella rules (Google front-end / OWASP / web-vitals / WCAG); there is nothing to define. (2) Dynamic sourcing SEARCHES THE SAME EXISTING SOURCES for the specific technology (re-query the URLs already in `standards/*sources*.yaml`), NOT a newly-discovered authoritative source — yielding a new tech-specific ruleset like React's. Acquired rules are tagged 4-axis as usual, stored in a PER-PROJECT folder, enforced first-class from stage zero the moment they are tagged, and promotable into the plugin core via PR + code review. Reuses the aggregator's existing `_operator`/`_community` origin machinery — a new `origin: "project"` category, not a new subsystem. Detail: [docs/design/v1.23-project-scoped-technology-rules.md](design/v1.23-project-scoped-technology-rules.md).

- **S-58/S-59 (refined):** the umbrella registry names which ALREADY-PRESENT namespaces an umbrella activates (frontend → the existing `google-*`/`owasp`/`web-vitals`/`wcag` rules); no general-namespace definition — activation of existing rules.
- **S-60 (refined):** `commands/acquire-technology-rules.sh` re-runs the EXISTING fetchers against the EXISTING source URLs, filtered for the technology, extracts tech-specific rules, tags them 4-axis, attaches provenance, and writes them to `_project/<project-id>/<ns>/`. No new-source discovery; no invented rules; empty result → umbrella rules only.
- **S-63** Per-project rule store (`generated-code-quality-standards/_project/<project-id>/<ns>/*.yaml`, `origin: "project"`). Walked by `rubric/aggregator.sh` exactly like `_community/<plugin-id>/` — first-class in the surface for that project — and gitignored in the plugin so acquisition never dirties the committed core. Contract §2.38.
- **S-64** Promote per-project rule to core via PR (`commands/promote-project-rule.sh`): opens a pull request moving a rule from `_project/<id>/<ns>/` into the core `<ns>/` tree (origin `plugin`); enters the plugin permanently only after code review.
- **S-62 (refined):** the instant a rule lands in `_project/` and is aggregated it is enforced identically to core rules — stage-zero detection (classify), consultation (§30 grounding/probes), architectural design (§29.4/§29.6), and development write-time (§29.6 byte-identical; the 4-axis tag routes it to its file kind + `foss_tools`).
- **§2.38** Per-project rule store + PR promotion: acquired tech-specific rules live under `_project/<project-id>/` (`origin: "project"`), are first-class in the aggregator/enforcer surface for the project (enforced stage-zero → write-time, scanned + consulted like every rule) the moment they are tagged, are gitignored until promoted, and enter the plugin core ONLY via PR + code review; each carries a 4-axis tag + provenance (composes §2.37); §2.6 freshness/tier gates apply.
- **§25 fidelity vocabulary additions:** `activate-existing-umbrella`, `search-existing-sources`, `per-project-rules`, `origin-project`, `project-rule-store`, `promote-via-pr`, `first-class-from-stage-zero`.
- **Anti-drift pending-folder-name map:** S-63 → `evals/pending/S/63-per-project-rule-store/`, S-64 → `evals/pending/S/64-promote-project-rule-pr/`.
- **§20 sequencing (revised):** S-58/S-59 umbrella activation → S-63 per-project store → S-60 search-existing acquisition → S-62 first-class enforcement → S-64 PR promotion. Fully additive: `_project/` is a new origin category alongside `_operator`/`_community`; core 44 namespaces + v1.0/v1.1 profiles + every existing rule untouched; per-project rules gitignored so acquisition can never dirty the core. **Corrected honesty:** umbrella layer always applies (rules exist); tech-specific layer is extracted from the EXISTING sources and present iff those sources contain tech-specific guidance — otherwise umbrella-only, never fabricated.

### §31.2 The acceptance invariant — official ruleset is PR-gated (operator-directed, 2026-07-05)

**STANDING INVARIANT: a rule becomes OFFICIAL only through an approved pull request that MOVES it from the working-rules directory (`_project/<project-id>/<ns>/`, origin `project`) to the official-rules directory (`generated-code-quality-standards/<ns>/`, origin `plugin`). There is no other path into the official corpus.** Sharpens §2.38; no new feature ID. Detail: [docs/design/v1.23-project-scoped-technology-rules.md](design/v1.23-project-scoped-technology-rules.md) §4a.

- **Working rules are used, not accepted.** `_project/` rules enforce first-class for their project from stage zero, but are never part of the official corpus and never ship in the plugin until reviewed. Acquisition (S-60) writes ONLY to `_project/` — it can never write into an official namespace.
- **The official directory changes only via reviewed PR.** No command, acquisition, or automation writes into an official namespace; the working store is the ONLY place automation may write — preserving the constitutional guarantee that the official ruleset stays curated + reviewed. `promote-project-rule` (S-64) does not accept a rule; it opens the PR that requests the move — acceptance is the human code review + merge.
- **Promotion is a move, not a copy.** A merged promotion PR removes the rule from `_project/` (now official under `<ns>/`, origin `plugin`); an un-merged/closed PR leaves it working-only.
- **§25 fidelity vocabulary additions:** `working-rules-directory`, `official-rules-directory`, `pr-gated-acceptance`, `promotion-is-a-move`, `used-not-accepted`.

### §31.3 Resolved shared-design decisions (CTP-authoritative; proposed to GCTP, 2026-07-05)

**STATUS: DESIGN — CTP-side decisions resolved; boundary items pending GCTP.** Consolidates §31/§31.1/§31.2 with GCTP's §30.8/§30.9/§30.10 into one system and fixes the five open points on CTP's terms (CTP owns its surface). Proposal: [docs/handoff-ctp-to-gctp-p15-shared-design-proposal.md](handoff-ctp-to-gctp-p15-shared-design-proposal.md). No new feature ID (resolves S-58…S-64 details + adds S-61 technology-fitness reference).

- **Decomposition (canonical):** GCTP §30.8 ↔ S-58/S-59; §30.9 ↔ S-60/S-63; §30.10 ↔ S-64/§2.38. GCTP's §30.8–10 are GCTP-side labels; CTP-canonical IDs are §31 / S-58…S-64.
- **D1 Registry ownership:** `standards/technology-umbrella-registry.yaml` is OFFICIAL (PR-gated); projects add *working* registry entries under `_project/<id>/`, promotable by the same gate.
- **D2 Fetcher hint:** reuse the existing four fetchers per source; optional `fetcher:` source field disambiguates; the chosen fetcher is recorded in each acquired rule's provenance.
- **D3 Budget:** acquisition searches ONLY umbrella-matched sources, bounded by `--max-sources` (default 8); over-budget → `budget_exhausted=true` + tech stays `needs_source` (partial, non-silent).
- **D4 Cross-family union:** a technology resolving to multiple umbrellas activates the DEDUPED UNION of all matched umbrellas' namespaces (§2.36 extends "umbrella" → "all matched umbrellas").
- **D5 Deprecation:** working rules expire via the §2.6 freshness gate; official removal is symmetric to promotion — a reviewed removal PR (§31.2 governs removal); explicit `deprecated: true` honored at both layers.
- **S-61** Technology-fitness recommender (extends S-34): grounded best-fit per umbrella (e.g. Angular over React); operator override; chosen tech's ruleset then applied. Cite-or-decline.
- **Canonical shapes** (both sides bind these): umbrella-registry entry (`technology`/`aliases`/`coordinate{linguist,purl}`/`umbrellas[]`/`specific_namespace`), working overlay rule (`origin: project` + `applies_to` 4-axis + `provenance{source,url,fetched_at,tier,fetcher}`), CLIs `resolve-technology.sh` / `acquire-technology-rules.sh --project-id` / `promote-project-rule.sh`.
- **Boundary items pending GCTP:** project-id contract, working-store home, promotion-PR governance, origin-awareness in GCTP validators, growing-surface handling (proposal §6 B1–B5).
- **§25 fidelity vocabulary additions:** `umbrella-registry`, `cross-family-union`, `budget-exhausted`, `fetcher-hint`, `removal-pr`, `technology-fitness`, `resolved-shared-design`.
- **§20 note:** build S-63 → S-58/S-59 → S-60 → S-62 → S-64 → S-61; starts once GCTP answers B1–B5 + sends its acceptance assertions. Fully additive; preserves §21 dod + the §31.2 PR-gated invariant.

### §31.4 Converged shared design (CTP ↔ GCTP reconciliation locked, 2026-07-05)

**STATUS: DESIGN — CONVERGED.** GCTP accepted the spine and answered the boundary items; CTP accepts them + two GCTP deltas that improve the design (including a build-order correction). Locked except one cosmetic naming call + GCTP's acceptance assertions. Detail: [docs/handoff-ctp-to-gctp-p15-converged.md](handoff-ctp-to-gctp-p15-converged.md). No new feature ID.

- **Boundary answers accepted:** (B1) `project-id` owned by GCTP, passed via **`--project <id>`** on every S-58/S-60/S-64 script (renames `--project-id`). (B2) working store at `.harness/plugin-cache/claude-tdd-pro/_project/<id>/`, written by CTP's own scripts (GCTP off the rule-content write plane). (B3) two-step promotion: CTP-side review on the PR + GCTP §15 ADR on the routine pin bump. (B5) reveal is official-constant + project-dynamic (no hardcoded 44).
- **§31.1 sharpened (from B4) — SCOPING INVARIANT:** a `_project/<A>/` rule is applied ONLY in a `--project A` run; the run surface is `official ∪ _project/<id>/` (never another project's overlay); a foreign-project rule surfacing is **fail-loud**, not silent. Blast radius bounded to the owning project.
- **Deltas accepted:** verbs **`acquire` / `promote` / `release`** (`release` = remove a working rule; `promote` = working→official PR; official removal still a PR). Registry is **CTP-owned + PR-only — NO per-project registry overlay** (supersedes §31.3 D1; per-project customization lives at the rule level, not the taxonomy; unmapped tech → `unresolved` → registry PR or direct `--stack-add`). **Family-activation ships FIRST** (needs no `_project/` store — reads existing official namespaces), correcting the §31.3 order.
- **Delta held:** field name — CTP proposes **`umbrellas: [...]`** (the operator's word) with multi-membership union semantics, pending a genuine `families`-vs-`umbrellas` semantic distinction from GCTP.
- **S-63 contract (published):** `_project/<project-id>/<ns>/<rule-id>.yaml`, each rule `origin: project` + `project_id` + `applies_to` (4-axis) + `enforced_by` + `provenance{source,url,fetched_at,tier,fetcher}`; aggregator with `--project <id>` walks `_project/<id>/` only; without `--project`, `_project/` is skipped → official `active.json` byte-identical.
- **Revised phase order (§20):** Phase 1 family-activation (S-58/S-59, ships first, no store) → Phase 2 acquisition (S-63 → S-60 `acquire` → S-62 scoped enforcement) → Phase 3 promotion+fitness (S-64 `promote`/`release`, S-61). Phase 1 startable immediately (no boundary dependency); Phase 2 on S-63-shape confirmation.
- **§25 fidelity vocabulary additions:** `scoping-invariant`, `project-scope`, `fail-loud-leakage`, `acquire-promote-release`, `family-activation-first`, `registry-pr-only`.

### §31.5 Design LOCKED — GCTP B1–B5 decided, final CTP-side deltas recorded (2026-07-05)

**STATUS: DESIGN LOCKED.** GCTP accepted §2–§5 verbatim, adopted D1–D5, settled the §31/S-58…S-64 numbering, and decided B1–B5 definitively; CTP records the two CTP-side deltas that fall out of those decisions. No open design items remain except the cosmetic `umbrellas`/`families` label (§31.4). No new feature ID. Detail: [docs/handoff-ctp-to-gctp-p15-converged.md](handoff-ctp-to-gctp-p15-converged.md) + GCTP's `handoff-ctp-p15-b1-b5-decisions-and-assertion-map.md`.

- **B2 delta (folds into S-63):** `standards/standards-sync.sh` (or the cache-sync path) MUST **preserve `_project/<id>/` across plugin-cache rebuilds** — acquired working rules survive a standards refresh; a rebuild never wipes the working overlay. This is a build requirement on S-63.
- **B1 delta:** `--project <id>` is REQUIRED on every S-58/S-60/S-64 command; `project_id` format is GCTP-owned (`FEATURE-<NNN>` / `TICKET-<NNN>` / operator kata string) and validated by the agreed regex.
- **B5 delta:** the §30.7 reveal integrates the D3 `budget_exhausted` state (a `needs_source` namespace whose acquisition hit the cap is marked, not silently dropped); effective surface = `official ∪ _project/<current-id>/` with origin labels — no hardcoded cardinality.
- **Acceptance targets (CTP builds green to these):** A1–A14 (GCTP's, mapped onto CTP §7 (a)–(e) + the §4/S-63 shapes) plus **A15** cross-project leakage is fail-loud (companion to A9 byte-identical `active.json`), **A16** `--project` required, **A17** reveal distinguishes origin, **A18** S-61 recommendation is source-cited.
- **Ready state:** Phase 1 (family-activation, S-58/S-59) is startable with ZERO boundary dependency; Phase 2 (S-63/S-60/S-62) unblocks on GCTP's TICKET-120.a pre-wire against the published S-63 shape (§31.4/§4); Phase 3 (S-64/S-61) follows. **§20 order unchanged from §31.4.**
- **§25 fidelity vocabulary additions:** `design-locked`, `standards-sync-preservation`, `project-id-regex`, `budget-exhausted-reveal`, `acceptance-targets`.

### §31.6 Phase 1 BUILT — family activation (S-58 resolver + S-59 umbrella registry, 2026-07-05)

**STATUS: BUILT.** The first phase of §31 (family activation) ships: naming a technology in the vision/answers activates its umbrella's ALREADY-SCRAPED rules for the consult — no acquisition, no `_project/` store, official surface only. Zero boundary dependency (§31.4/§31.5). Detail: [docs/design/v1.24-family-activation.md](design/v1.24-family-activation.md).

- **S-59** Umbrella registry (`standards/technology-umbrella-registry.yaml`): `umbrellas.<name>.activates` → the EXISTING framework-agnostic namespaces; `technologies[]` → `{technology, aliases, coordinate{linguist,purl}, umbrellas[], specific_namespace|null}`. Official + PR-only (§31.4 delta 2).
- **S-58** Technology resolver (`commands/resolve-technology.sh <name>`): resolves to coordinate + umbrella(s) + `activated_namespaces` (existing only) + `specific.status` ∈ `present|needs_source|unresolved` (cite-or-decline; unknown → `unresolved`, never guessed). Cross-family union (§31.3 D4). Marker `resolve=<tech> umbrellas=<csv> activated=<csv> status=<...>`.
- **Family activation wired into the consult:** `full-surface-intake.sh --classify` scans the haystack (word-boundary, §30.3) for registered technologies and unions their activated EXISTING namespaces into scope; emits `workload_classification.family_activated` + a `family_activated=<csv>` marker. So "Vue/Angular/Ember" activates the existing frontend rules (owasp/web-vitals/w3c/md/typescript/node).
- **Framework-specific ≠ category (correctness):** the workload-classifier `web-frontend` type no longer lists the framework-specific `react` namespace — `react` is activated ONLY by naming React (family activation) or `--stack-add react`. A Vue/Angular/Ember app does not inherit React's rules.
- **§25 fidelity vocabulary additions:** `family-activation`, `technology-resolver`, `umbrella-registry`, `activated-namespaces`, `present-needs-source-unresolved`, `framework-agnostic-umbrella`.

12 specs (`cl555-tech-01..12`): resolves-umbrella / present-activates-specific / needs-source-still-activates / unknown-declined / vue-not-react / activates-existing-only / alias-resolves-same / cross-family-union / vision-family-activated / vue-vision-not-react / react-vision-react / no-tech-no-family. **§20 note:** Phase 1 of §31; Phases 2–3 (acquisition, promotion) follow. Preserves §21 dod; additive. Suite 4974→4986.

### §31.7 Phases 2+3 BUILT — acquisition, scoped enforcement, PR promotion, fitness (2026-07-05)

**STATUS: BUILT.** The remaining §31 phases ship, completing the universal-technology system. All additive; the official surface is byte-identical without `--project`.

- **S-63** per-project store (`rubric/aggregator.sh`): new `origin: project` category — `--project <id>` walks `_project/<id>/` ONLY (blast-radius scoping, §31.4 B4); without `--project`, `_project/` is skipped so official `active.json` is byte-identical. Each project rule carries `origin: project` + `project_id`; `source_namespace` = the real namespace. Gitignored (never dirties core).
- **S-60** dynamic acquisition (`commands/acquire-technology-rules.sh`): searches EXISTING-source content (fetch stubbed at the boundary via `--source-file`; production reuses `standards/fetchers/*`) for a resolved technology, extracts cited rules, tags 4-axis (`applies_to.linguist_aliases`), writes to `_project/<id>/<tech>/` in the real source-file schema with provenance. Unresolved → refused; `--max-rules` cap → `budget_exhausted`; never writes an official namespace.
- **S-62** scoped enforcement (`rubric/enforce-file.sh`): `--project <id>` loads `_project/<id>/*/*.yaml` first-class, scoped to that id (no cross-project leakage); LING2EXT gains vue/svelte; official enforcement unchanged without `--project`.
- **S-64** promotion (`commands/promote-project-rule.sh`): `--plan` (move plan, no writes) / `--apply` (MOVE working→official, strips project overrides) / `--release` (remove working). PR-gated (§31.2); acceptance = human review + merge.
- **S-61** technology-fitness (`commands/recommend-technology.sh` + registry `fitness` tags): ranks an umbrella's candidates against workload needs; grounded best-fit or declines. Enterprise+typescript-first → Angular over React; performance → Svelte; no-needs → best-supported; unknown → declined.
- **§25 fidelity vocabulary additions:** `origin-project`, `project-scoped-enforcement`, `search-existing-acquisition`, `promotion-move`, `budget-exhausted`, `technology-fitness`, `cross-project-leakage-prevented`.

21 specs (`cl556-proj/acq/enf-*`, `cl557-promote-*`, `cl558-recommend-*`, `cl559-integration-*`): project-overlay-included / official-byte-identical / foreign-project-excluded / acquire-writes-cited / acquire-4axis-tagged / acquire-declines-unknown / acquire-budget-capped / enforce-applies-project / no-project-no-apply / no-cross-project-leak / promote-plan-no-write / promote-apply-moves / release-removes-working / promote-missing-fails / angular-over-react / performance-framework / best-supported-default / umbrella-declined / recommendation-grounded / end-to-end-chain / acquisition-official-unchanged. **§20 note:** §31 COMPLETE (Phases 1–3). Preserves §21 dod. Suite 4986→5007.

### §31.8 Production-fetch wrapper + `--explain` mode (GCTP offers accepted, 2026-07-05)

**STATUS: BUILT.** The two operator-facing edges CTP offered and GCTP accepted.

- **S-60 live wrapper** (`commands/acquire-technology-live.sh`): the production orchestrator over `acquire` — resolves the technology's umbrella, selects the EXISTING source-catalog entries whose `applies_to` intersects the umbrella's namespaces, reads each source's fetched content from a `--cache <dir>` (populated by `standards/fetchers/*` per source URL — the harness owns the network download), and feeds each into `acquire --only-mentioning` so only technology-mentioning guidance from a general source becomes a rule. Full acquire lifecycle from a technology name + a cache dir, no hand-managed `--source-file`. Unresolved → declines; empty cache → `sources_matched=N sources_fetched=0 acquired_total=0` (honest, non-fabricating).
- **`acquire --only-mentioning`**: extract only guidance lines that name the technology (for searching a general source).
- **`--explain` mode** on all four §31 commands (`resolve-technology`, `acquire-technology-rules`, `promote-project-rule`, `recommend-technology`): each emits a plain-language `EXPLAIN:` line alongside the terse markers — e.g. resolve explains what naming a technology turns on (and why an unknown one is declined); acquire notes the rules are project-scoped and not official until a promotion PR; promote states the reviewed-PR gate; recommend gives the grounded rationale.
- **§25 fidelity vocabulary additions:** `live-acquisition`, `fetch-cache`, `umbrella-matched-sources`, `only-mentioning`, `explain-mode`, `operator-facing-narrative`.

9 specs (`cl561-live-01..04`, `cl561-explain-01..05`): live-acquires-from-cache / live-filters-mentions / live-declines-unknown / live-empty-cache-nothing / resolve-explains-present / resolve-explains-decline / acquire-explains-nonofficial / promote-explains-pr-gate / recommend-explains-rationale. **§20 note:** completes the §31 operator-facing surface; the harness-owned network fetch remains external. Suite 5013→5022 (after the §31 GCTP-contract reconciliation CL-560, 5007→5013).

### §31.9 Acquisition sufficiency (≥30 rules/technology) + `--stack-add` tech bridge (GCTP P-18 + G-3/G-4, 2026-07-05)

**STATUS: BUILT.** KA-2 showed mention-filtered general-source acquisition yields too few rules (3 for Vue) to design/build on. P-18 sets a ≥30-rules-per-technology sufficiency floor met by acquiring the technology's OWN canonical sources whole. CTP owns the capability; GCTP owns the enforcement gate.

- **S-60 tech-canonical sources** (`standards/technology-source-registry.yaml`, OFFICIAL + PR-only): maps a technology → its authoritative canonical docs (`vue → vuejs.org/style-guide + guide`, …). Adding a source is a reviewed PR.
- **Whole-source acquisition (§2.2):** `acquire-technology-live` acquires each canonical source WHOLE (every guidance statement → a rule, no `--only-mentioning` filter) with no artificial cap (`--max-rules 500`), because the entire source is tech-specific — this is the bulk of the ≥30 rules. Umbrella-general sources stay `--only-mentioning`.
- **Sufficiency signal (§2.4):** the live summary emits `rule_count=<n> sufficiency=ok|below-threshold-<N>` (`--threshold`, default 30) — a technology below the floor fails loud, never silent. Rules are still cited + 4-axis tagged + written only to `_project/` (never official; never fabricated).
- **G-3/G-4 `--stack-add` tech bridge:** `--stack-add <name>` now accepts a TECHNOLOGY name (not only a namespace) — a tech token bridges to the S-58 resolver and activates that technology's family (adds its umbrella namespaces, populates `family_activated` + `families_active`); a real namespace stays a stack entry; an unknown token is still rejected (cite-or-decline).
- **G-2 clarification (recorded):** the `full_surface_revealed=<n>` marker is the shipped §30.7 Stage-0 reveal (announced there), not an unannounced P-14.
- **§25 fidelity vocabulary additions:** `acquisition-sufficiency`, `canonical-source`, `whole-source`, `sufficiency-signal`, `rule-count`, `below-threshold`, `stack-add-tech-bridge`.

9 specs (`cl562-suff-01..05`, `cl562-stacktech-01..04`): canonical-meets-floor / below-threshold-honest / rule-count-signal / whole-source-all-lines / threshold-configurable / stack-tech-activates-family / stack-tech-families-active / namespace-stays-stack / unknown-stack-rejected. **§20 note:** completes the §31 capability side of P-18; GCTP owns the sufficiency-gate audit. Suite 5022→5031.

## §33. `standards-refresh.sh` — the missing ADR-0009 pipeline orchestrator + periodic-refresh worker (v1.26 amendment — GCTP KA-5 P-21 trigger)

**STATUS: BUILT (2026-07-11).** Closes the "URL registry → periodically re-scraped, 4-axis-tagged, aggregated rules" seam that CTP designed but never fully wired. GCTP kata attempt KA-5 (P-21 handoff) surfaced the miss: operator wanted a single mechanism to scrape any registered URL at its declared frequency, extract every rule, 4-axis-tag them via the axis registry, and land them under the correct target-namespace for enforcement — with no per-rule hand-authoring. Detail: [docs/design/v1.26-standards-refresh-orchestrator.md](design/v1.26-standards-refresh-orchestrator.md).

**What was missing:** the orchestrator connecting the schedulers (C-19 / S-17 auto-refresh) → the 6-stage ADR-0009 pipeline (Stage 1 `extract-rules-from-url.sh`, Stage 2 `classify-rule.sh`, Stages 3+4 `route-rule.sh`, Stage 5 `draft-custom-rule.sh`, Stage 6 `review-queue.sh`, all fully built per §28.30/§28.34/§28.36) → the target namespace folders. The C-19/S-17 auto-refresh scripts invoke a `--upstream-stub` placeholder, not a real fetch pipeline; `standards-add.sh` / `compliance-add.sh` only scaffold folders per G-9; they don't invoke the pipeline. ADR-0009 named this orchestrator but it was never coded until v1.26.

- **C-26 `commands/standards-refresh.sh`** — the missing pipeline-orchestrator. Three modes; idempotent on re-run; drives Stage-1-driver → classify → route → assemble → merge-or-replace target rule YAML at `<out-dir>/<target-namespace>/<framework-id>.yaml`.
- **single-URL-mode** (CLI: `--url + --target-namespace + --framework-id + --source-id + --authoritative-publisher [--shape --merge|--replace --dry-run]`). Per-URL pipeline: extract segments → classify each (`applies_to` + `applies_to_prose` + confidence + signals; low-confidence flagged `needs_tier2_llm=true`, never dropped) → route each (`enforced_by[]`; auto-attach `architectural-content` bundle when `applies_to_prose:true`) → assemble composite YAML with populated `source:` header + `rules[]` (each with `id`/`name`/`description`/`detector`/`applies_to`/`enforced_by`/`provenance.section`/`content_hash`) + `recommended_set[]` + `all_set[]` → merge-mode (default) preserves rules whose `content_hash` matches (introduced_at frozen) and marks rules absent from the fresh fetch as `deprecated: true` with `deprecated_at: <NOW>` reason `removed-upstream`; replace-mode wholly overwrites.
- **registry-mode** (CLI: `--registry <path> [--force] [--now <iso>]`). Iterates every entry in a `*-URLS.yaml` registry; freshness-skip via each entry's `fetch_frequency` vs `<registry>-last-fetch/<source-id>.txt` marker; namespace resolution per §17 G-9 mapping (`european-union` jurisdiction → `european-union/`; US Federal → `us-government/`; `international` → `industry-self-regulatory/`; `financial-industry` source_class → `finance-industry/`); framework-id from the entry's `id:` field; publisher from `authoritative_publisher` (or `name` fallback); shape defaults to `markdown-headings`; delegates to single-URL-mode per due entry.
- **Scheduler-integration seam** (CL-565, follow-on). `compliance/auto-refresh-daily.sh` (C-19) and `standards/auto-refresh-daily.sh` (S-17) currently invoke a `--upstream-stub` placeholder; in a follow-on CL they will invoke `standards-refresh.sh --registry <path> --now <iso>` in place of the stub — same output, real pipeline. This CL ships the orchestrator; the scheduler-wire is a one-line change in a subsequent CL.
- **Idempotency by content_hash.** Every rule's `content_hash = sha256(title + "\n" + prose)` — deterministic across re-scrapes. Same URL content → same rule set → same YAML byte-identical (except `fetched_at` timestamp normalized-out per §31.9 A9 pattern). New rule appeared → appended with `introduced_at: <NOW>`; existing rule updated (same title, different prose) → content_hash changes → treated as new (old deprecated_at); rule removed from source → marked `deprecated: true` with `deprecated_at: <NOW>` reason. Aggregator picks up the updated file → `active.json` reflects the fresh rule set on the next `standards-sync` run.
- **Honest boundary (Tier-1 only in this CL).** No clause silently dropped — every extracted segment is classified; low-confidence gets `needs_tier2_llm=true` (never dropped). Every rule cites its source (populated `source:` header + `provenance.section`). No fabrication — rules come from URL text via the deterministic segmenter. Idempotent (byte-identical re-run modulo `fetched_at` normalization). Change-detecting (new/removed rules marked explicitly). Network fetch happens inside `extract-rules-from-url.sh` (network-tolerant `curl` with 20s timeout). Stage 5 LLM (`draft-custom-rule.sh`) + Stage 6 (`review-queue.sh`) integration is CL-566; HTML section extractor (for eur-lex, sec.gov, hhs.gov rendered-HTML URLs) is CL-567.
- **§25 fidelity vocabulary additions:** `standards-refresh`, `pipeline-orchestrator`, `target-namespace`, `framework-id`, `single-URL-mode`, `registry-mode`, `merge-mode`, `replace-mode`, `Stage-1-driver`, `freshness-skip`, `content_hash`, `deprecated_at`, `deprecated_reason`, `introduced_at`, `removed-upstream`, `periodic-refresh-worker`, `six-stage-pipeline`, `authoritative-publisher`, `last-fetch-marker`, `source-id`.
- **Anti-drift folder map:** C-26 → `commands/standards-refresh.sh`; pending specs at `evals/pending/C/26-standards-refresh-orchestrator/` promoted to `evals/specs/cl564-orchestrator-*`.

10 specs (`cl564-orchestrator-01..10`): usage-error-missing-required-args / dry-run-emits-yaml-no-write / single-url-extracts-and-classifies / single-url-emits-provenance-and-content-hash / single-url-writes-target-namespace-framework-id-yaml / merge-preserves-content-hash / merge-marks-removed-deprecated / registry-mode-parses-entries / registry-mode-freshness-skip / registry-mode-force-overrides-skip. **§20 note:** ships stand-alone in v1.26; composes with §28.30 (Stage 1–3 commands, reused without modification) + §28.33 (namespace-axis-binding, the classifier's 4-axis vocabulary) + §32 (jurisdictional-namespace compliance rule authorship, v1.25 — orchestrator can replace/extend §32's hand-authored bootstrap by processing the C-13 URLs comprehensively via the deterministic pipeline). Composes forward with CL-565 scheduler wire-through, CL-566 LLM tier integration, CL-567 HTML section extractor. Preserves §21 dod. Suite 5041→5051.
