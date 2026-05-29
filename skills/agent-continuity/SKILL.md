---
name: agent-continuity
description: H-13 long-running agent harness continuity per §26 v1.11. When a CL exceeds a single agent context window, the initializer agent writes a continuation artifact at `.claude-tdd-pro/agent-continuations/<session_id>.json` and the incremental successor agent reads it at startup to resume from `next_action` without losing the §2.15 workflow state envelope.
---

# agent-continuity — H-13 / v1.11 §26

Architecture §11 H-13: "Long-running agent harness continuity (§2.27).
When a single CL exceeds an agent's context window, the harness writes
a continuation artifact at
`.claude-tdd-pro/agent-continuations/<session_id>.json`."

## Schema (§2.27 verbatim)

```json
{
  "parent_session_id": "<id>",
  "parent_cl_id": "<id>",
  "current_phase": "<phase-id>",
  "completed_steps": [
    { "step_id": "<id>", "completed_at": "<iso>", "summary": "<text>" }
  ],
  "pending_steps": [
    { "step_id": "<id>", "queued_at": "<iso>", "prerequisite_ids": ["<id>"] }
  ],
  "context_summary": "<= 500 char",
  "last_tool_calls": [
    "<= 10 entries"
  ],
  "next_action": { "action": "<text>", "rationale": "<text>" }
}
```

## Substrate

`commands/agent-continuity.sh` provides three subcommands:

- `--write`   — initializer writes the artifact at session boundary
- `--read`    — successor reads + validates the parent_session_id
- `--purge-stale` — TTL purge (24h since last write; per §2.27)

## Invariants

- **Parent session must be active.** `--read` validates that
  `parent_session_id` references an envelope in
  `.claude-tdd-pro/workflow-state.json` (§2.15). Stale parent → refuse.
- **No contract-relaxation.** Resumption preserves §2.23 lock-section
  ownership, §2.7 source-folder ownership, and §2.25 vocabulary
  fidelity. The artifact is a context-window-crossing mechanism, not
  an escape hatch.
- **24-hour TTL.** Stale artifacts are stale state, not historical
  record. Purge daily via `--purge-stale --now <iso>`.

## Cross-references

- §2.27 — the contract surface
- §2.15 — workflow state envelope (the `_resumable` block)
- §2.23 — concurrent CL contract (continuation does not bypass)
- W-3 — workflow state machine (consumer of resumed envelope)
- §2.8 — provenance manifest (artifact citation in `models_used` block)
