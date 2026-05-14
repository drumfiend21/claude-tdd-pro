---
name: Claude TDD Pro v1.9 — canonical architecture text
description: The literal v1.9 architecture as provided by the user. This is the source of truth for every feature ID, contract numbering, and CL plan. Cite by §/feature ID.
type: project
originSessionId: 6d636ecc-f923-462a-943c-a116be00d582
---
The full v1.9 architecture text was provided by the user on 2026-05-12 and
must be kept on file as the source of truth. Stored in companion file:
`project-v19-architecture-text.md` (separate file because of length).

**Why this exists:** Prior CLs (CL-07, CL-08, CL-09, CL-10) deviated from
the architecture by inventing feature decompositions and contract numbering
that do not match this text. Specifically:
- Phase E was numbered E-1..E-17 around invented topics (rule registry,
  AST walker, parallel runner, etc.) instead of the architecture's
  E-1..E-17 (severity overrides, options, glob overrides, auto-fix,
  inline suppression, recommended sets, plugin protocol, metadata,
  formatters, deprecation, RuleTester, cache, messageIds, ESLint config
  import, ESLint-as-detector wraps, plugin discovery, closed loop).
- Phase H was numbered H-1..H-11 around adversarial security topics
  (yaml bombs, path traversal, sandboxing) instead of the architecture's
  H-1..H-11 (token-cost transparency, profile system, sectioned advisory
  locks, SECURITY.md threat model, multi-language honesty, command
  reconciliation, /doctor --watch, license attribution, progressive
  disclosure docs, community catalog, plugin self-test).
- Cross-cutting contracts §2.7..§2.22 were labelled with wrong topics
  (e.g. my "§2.7 audit log" should be §2.7 lock file; my "§2.8
  telemetry" should be §2.8 AI provenance manifest; etc.).

**How to apply:** When writing pending specs for any phase or cross-cutting
contract, ALWAYS reference this architecture text by feature ID (e.g.
"E-5 inline suppression with justification") and use the exact contract
number from §2.X. If unsure, re-read the relevant section in
`project-v19-architecture-text.md` before naming a feature or assigning
a §2.X label.

**Structure summary (for quick lookup; refer to full text for detail):**

- Phase F (Foundation, F-0..F-6): contract locking, /postmortem,
  /measure-rubric, /agent-verify, drift-detection skill, /incident,
  codebase-impact preview helper.
- Phase E (Rule Engine ESLint-parity, E-1..E-17): the 17 features named
  above.
- Phase G (Generated Quality-Standards Directory, G-1..G-14): directory
  layout, source-organized file format, namespacing, migration,
  aggregator, schema validation, granular extends, operator namespace,
  registry sync, INDEX, plugin protocol, validate-all, ESLint compliance,
  closed loop.
- Phase S (Standards, S-1..S-19): catalog, fetcher, coverage matrix,
  audit, diff, provenance enforcement, promote-standard, comparator,
  conformance report, monitor, closed loop, registry, daily-fresh,
  add/remove, freshness gate, auto-refresh, consumption trace,
  closed-loop validation.
- Phase C (Compliance, C-1..C-21): 25+ frameworks, control mapping,
  AI provenance manifest, Merkle-chained audit log + signed
  checkpoints, SoD gate, PII guard, AIBOM, /risk-classify,
  evidence collection, /audit-pack, compliance-specialist subagent,
  closed loop, registry, sync, daily-fresh, add/remove, freshness gate,
  auto-refresh, consumption trace, closed-loop validation.
- Phase P (Prompt Lifecycle, P-1..P-10): registry, eval datasets,
  /prompt-eval, model selection rationale, /prompt-ab, /prompt-promote,
  fine-tunes, skill performance metrics, closed loop, PLUS v1.10
  amendment per §24: P-10 runtime model router (task-class → tier:
  haiku/sonnet/opus consulted at subagent invocation; H-1/H-12 by tier).
- Phase R/N/T (Coverage): React 10 rules, Node 10 rules, TypeScript 8
  rules with full E-8 metadata + detectors + templates + skills + evals
  + profile registration.
- Phase Q (SPACE, Q-1..Q-9): config, collector, /space-report, friction
  tracker, flow guard, privacy, cross-loop integration, honest scope,
  risk-tiered profile auto-select.
- Phase H (Hardening, H-1..H-12): the 11 features named above (operator
  polish, NOT adversarial security) PLUS H-12 continuous cost telemetry
  rollup (v1.9.1 amendment per §23).
- Phase L (PR Corpus, L-1..L-24): catalog, fetcher, triage filter,
  quality eval gate, pattern extractor, two-pass reconciler, evidence
  aggregation, /pr-corpus-update, /pr-corpus-learn, provenance extension,
  daily monitor, anti-poisoning, eval-dataset feedback, conflict
  surfacing, audit integration, cross-loop, GitHub issue tracker,
  registry, sync, daily-fresh, /pr-source-add, /pr-source-remove,
  freshness gate, consumption trace, closed-loop validation.
- Phase O (Operational Readiness, O-0..O-12): telemetry-first, seed
  corpus, --dry-run, lifecycle, multi-machine sync, signed checkpoints,
  external meta-eval, canary, threat model, shared-learning, semver,
  bootstrap evals, PLUS v1.10 amendment per §24: O-12 application
  scaffolds (next-saas, node-api, python-fastapi, react-spa greenfield
  starters with profile pre-set).
- Phase X (Execution Surfaces, X-1..X-9): GitHub Actions, GitLab CI,
  pre-commit, local-LLM, TUI, PLUS v1.9.1 amendments per §23: X-6 IDE
  rules export adapter (Cursor/Copilot/Continue/Aider/Windsurf, one-way),
  X-7 installable Claude Code hooks bundle with uninstall metadata, PLUS
  v1.10 amendments per §24: X-8 LSP surface (tdd-pro-lsp binary + VS
  Code extension; live diagnostics), X-9 cloud devcontainer surface
  (Codespaces / Dev Containers).
- Phase W (Workflow Orchestration, W-1..W-12): /architect, git-workflow,
  workflow state machine, decision provenance trail, profile registration,
  closed loop, PLUS W-7 /spec writes failing tests (CL-34), W-8 /feature +
  TDD-Guard (CL-34), W-9 UI feature DOM regression pin (CL-34), PLUS
  v1.9.1 amendment per §23: W-10 concurrent CL gate, PLUS v1.10
  amendments per §24: W-11 parallel subagent orchestrator (within-CL
  parallelism with §2.7 lock coordination), W-12 conversational PR
  review subagent (multi-turn follow-up grounded in §2.8/W-4/P-2).

**Cross-cutting contracts (§2.1..§2.22):**

- §2.1  Rubric rule schema
- §2.2  Detector contract
- §2.3  Subagent contract
- §2.4  Eval spec schema
- §2.5  Profile system
- §2.6  Standards source contract (two-tier)
- §2.7  Lock file (sectioned advisory locks)
- §2.8  AI Provenance Manifest
- §2.9  Control mapping
- §2.10 Prompt registry
- §2.11 SPACE metric schema
- §2.12 PR source contract (two-tier)
- §2.13 Active-flow stack
- §2.14 Dry-run contract
- §2.15 Workflow state contract
- §2.16 Decision provenance schema (MADR ADRs)
- §2.17 Live freshness contract
- §2.18 Generation-time consumption schema
- §2.19 Compliance source contract (two-tier)
- §2.20 Rule plugin contract
- §2.21 Source folder contract (G phase)
- §2.22 Source folder operator contract
- §2.23 Concurrent CL execution contract (v1.9.1 amendment per §23)
- §2.24 Portable audit-pack export format (v1.9.1 amendment per §23)

**CL plan:** ~265 CLs total at v1.9, +~12 CLs for v1.9.1 amendments (§23),
+~18 CLs for v1.10 amendments (§24), ~221 eval specs at v1.9
definition-of-done, +~30 evals for §23, +~50 evals for §24.

**Out of scope:** see §19 (production telemetry, EU AI Act conformity,
SOC 2 Type 2 attestation, etc. — irreducible 0.15 gap to 10.0).
