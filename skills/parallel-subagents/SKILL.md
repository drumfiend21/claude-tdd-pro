---
name: parallel-subagents
description: Orchestrate multiple §2.3 subagents within a single CL concurrently (W-11 / v1.10 §24). Distinct from W-10 — W-10 is CL-level concurrency; W-11 is within-CL agent-level parallelism. Reads `userConfig.max_parallel_subagents` (default 1 = sequential; opt-in N≥2) and §2.7 sectioned-lock contract. Per-subagent token-cost telemetry rolls into H-12 with `subagent_id` tag preserved.
---

# parallel-subagents — W-11 / v1.10 §24

Architecture §15 W-11: "Parallel subagent orchestrator
`skills/parallel-subagents/SKILL.md` + coordinator subagent
`agents/parallel-coordinator.md` (sonnet, prompt_id
`parallel-coordinator`): orchestrates multiple §2.3 subagents within
a single CL concurrently."

## When this skill fires

- Operator (or a CL workflow step) decides to fan out to multiple
  subagents in one phase.
- `userConfig.max_parallel_subagents: <N>` controls fan-out cap:
  - `1` (default) → sequential dispatch
  - `>=2` → parallel dispatch up to N concurrent

## Lock-section integration (§2.7)

Concurrent subagents claiming overlapping lock sections serialize via
lock acquisition; non-overlapping subagents run in parallel.

Example: two reviewer subagents both wanting `rubric` write → second
serializes behind first. A reviewer writing to `rubric` and a code-
critic writing to `compliance-report` → run in parallel.

## Token budget

`userConfig.parallel_budget_tokens: <N>` (default unbounded). Coordinator
refuses parallel execution when total estimated tokens exceed the
budget.

## Consolidated finding set

Coordinator emits a single consolidated finding set to W-3 workflow
state. Deduplication key: `rule_id + file + line` (per the architecture).

## Telemetry

Per-subagent token cost is preserved with `subagent_id` tag in H-12
rollups; cost report dimensions (`--by=subagent`) surface this.

## Orthogonality to W-10

W-10 (CL-level concurrency, §2.23) and W-11 (subagent-level
parallelism) are orthogonal. A single CL with
`max_parallel_subagents: 4` runs 4 subagents in parallel; two CLs
each with `max_parallel_subagents: 4` (allowed by W-10) run up to 8
subagents total, gated by per-profile parallel-budget.
