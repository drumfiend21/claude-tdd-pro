---
name: concurrent-cl
description: Opt-in concurrent-CL execution (W-10 / §2.23). Reads active session envelopes from `.claude-tdd-pro/active-sessions/<session_id>.json` and gates `/spec` / `/feature` / `/architect` invocations against the §2.23 five-dimension disjointness contract (phase set, workflow-state subsections, lock sections, source-folder ownership, commit branch). Default is sequential per §20; activated via `userConfig.allow_concurrent_cls: true` or per-invocation `--concurrent`.
---

# concurrent-cl — W-10 / §2.23

Architecture §15 W-10: "Concurrent CL gate `skills/concurrent-cl/SKILL.md`
+ `hooks/scripts/concurrent-cl-gate.sh` (PreToolUse on `/spec`,
`/feature`, and `/architect`): enforces §2.23 by reading active CL
envelopes from `.claude-tdd-pro/active-sessions/<session_id>.json`."

## When this skill fires

- PreToolUse on `/spec`, `/feature`, `/architect` (per W-10 hook wiring).
- Operator runs `/cl-status` (the companion command shipped alongside).
- Concurrency is opt-in. Two activation paths:
  1. `userConfig.allow_concurrent_cls: true` in `.claude-tdd-pro/`.
  2. Per-invocation `--concurrent` flag on `/spec`, `/feature`, `/architect`.

## Session envelope shape

Each active CL writes one envelope at
`.claude-tdd-pro/active-sessions/<session_id>.json` on start; the
envelope is removed on CL completion or abort.

```json
{
  "session_id": "<unique>",
  "phases": ["E", "F"],
  "state_subsections": ["commits", "spec_path"],
  "lock_sections": ["rubric", "profiles"],
  "source_folders": ["google-jsguide/no-eval.yaml"],
  "branch": "feat/<name>"
}
```

## Disjoint-ness contract (§2.23)

Two or more CLs MAY execute concurrently when ALL of:

1. **(a) Disjoint phase set** — no two CLs author specs or
   implementation for the same phase ID.
2. **(b) Disjoint workflow-state subsections** (per §2.15) — each CL
   mutates only its own envelope.
3. **(c) Disjoint lock sections** (per §2.7) — no two CLs hold
   concurrent writes on the same `_locks.<section>`.
4. **(d) Disjoint source-folder ownership** — no two CLs author rules
   in the same `generated-code-quality-standards/<source-namespace>/<file>.yaml`.
5. **(e) Disjoint commit branches** — never on the same branch.

Overlap on any condition → reject the second CL with the offending
resource printed.

## Cross-references

- `hooks/scripts/concurrent-cl-gate.sh` — the actual gate
- `/cl-status` (`commands/cl-status.sh`) — list running CLs
- §2.23 — the contract (full text)
- §11 H-3 — sectioned advisory locks
- §2.15 — workflow state envelope shape
