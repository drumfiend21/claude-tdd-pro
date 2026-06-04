# Scale target — manufacturability story

Per the simulated Musk-team review (Elon / Mark Juncosa):
> "If 100 teams adopted this tomorrow, the rubric runner's bash
>  substrate would not survive 1000× concurrent installations.
>  Needs the typed-binary rewrite for scale."

This document defines the scale targets and the migration path.

## Current scale (measured)

| Metric | Value | Method |
|---|---|---|
| Spec corpus | 3,886 active | `ls evals/specs/*.json \| wc -l` |
| Active features | 193 | from architecture-v1.9.md |
| Single-install size on disk | ~50 MB | `du -sh ~/.claude-tdd-pro` |
| Cold install wall-clock | 5-15 s | `scripts/bench.sh` |
| Full suite warm | 3-5 s | `scripts/bench.sh` |
| Full suite cold | 3-4 min | first run after cache invalidation |
| Concurrent installs tested | 1 | single-author project |

## Scale targets (per tier)

### Tier 1 — current (single-developer adoption)

- 1-50 installs per day across the world
- 1 maintainer
- 1 release per 1-2 weeks
- Bash substrate adequate

### Tier 2 — team adoption (within next 6 months)

- 50-500 installs per day
- 1 maintainer + 2-3 secondary reviewers
- 1 release per week
- **Bash substrate strained; LLM-judge optional**

Requires:
- Recruit secondary maintainers (see `MAINTAINERS.md`)
- Stabilize public API per `docs/GROK_INTEGRATION_PLAN.md`
- Cut MINOR release rhythm to weekly
- Performance: cold install must stay <30s p95 even with cold GitHub CDN

### Tier 3 — small-org adoption (12-24 months)

- 500-5,000 installs per day
- 3+ maintainers
- 1-2 releases per week
- **Bash substrate replaced with typed binary**

Requires:
- Go or Rust rewrite of `rubric/runner.sh` per ADR-0001 §rollback
- LLM-judge becomes the primary detector mode
- Per-tenant telemetry pipeline (currently local-only per Q-6)
- Multi-region GitHub CDN distribution OR npm publish for installer

### Tier 4 — large-org adoption (24+ months)

- 5,000+ installs per day
- Plural maintainer team
- Continuous release
- **Standalone product, not just a Claude Code plugin**

Requires:
- Platform-independence per `docs/PLATFORM_DEPENDENCY.md` realized
- SaaS dashboard for organizational SPACE telemetry
- Compliance certifications (SOC 2, ISO 27001) if pricing tier exists
- Enterprise support contract terms

## Blockers per tier transition

### Tier 1 → Tier 2

| Blocker | Effort | Status |
|---|---|---|
| Recruit secondary maintainer | external | open per `MAINTAINERS.md` |
| Public API surface document | 1 day | open per `docs/GROK_INTEGRATION_PLAN.md` |
| Weekly release cadence | 0.5 day | open |
| Cold-install performance gate (<30s p95) | 0 (already <15s) | met |

### Tier 2 → Tier 3

| Blocker | Effort | Status |
|---|---|---|
| Typed binary runner rewrite | ~1.5 days engineering | open per ADR-0001 |
| LLM-judge replaces grep detectors | ongoing per `llm-judge.sh` | scaffolded this CL |
| Per-tenant telemetry pipeline | 2 days | scaffolded via `space/telemetry-emit.sh` |
| Distribution beyond GitHub clone | 0.5 day (npm publish) | gated on API stability |

### Tier 3 → Tier 4

| Blocker | Effort |
|---|---|
| Platform-independence | ~2.5 days per `docs/PLATFORM_DEPENDENCY.md` |
| Org SaaS dashboard | weeks |
| Compliance certifications | months + audit cost |
| Enterprise support model | business decision |

## What we don't do at any tier

- **Microservice decomposition.** The system is a monolith with a
  clear bounded context. Decomposition adds tax without benefit.
  Per the simulated Sam Newman review: "Keep the monolith."
- **Commit to a roadmap before measuring demand.** Each tier
  transition is gated on actual install-count crossing the
  threshold, not aspirational planning.

## The Musk-team test

Elon's question: "How many teams adopted this tomorrow could the
bash substrate survive?" Honest answer: ~50 concurrent operations
(rubric runner is parallel-aware; cache + tree-sha indexing scale
fine; the GitHub CDN clone bottleneck is upstream of us).

For 100+: the typed binary rewrite is the prerequisite. ADR-0001
documents this dependency. The CHANGELOG.md [Unreleased] roadmap
sequences it.

For 1000+: full platform-independence + SaaS. Tier 4. Out of
scope until adoption demands it.
