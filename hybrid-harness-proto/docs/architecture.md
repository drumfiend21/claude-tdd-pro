# Hybrid Harness Architecture

## Goal

Compose Grok Build CLI (outer orchestration) with Claude TDD Pro (inner Red-Green-Refactor quality core) into one harness suitable for enterprise pipelines at 1,000+ engineer scale, where:

- Pipelines need to be end-to-end automated.
- Every code change must still pass a strict TDD gate with audit-quality provenance.

## Role split (the contract)

### Grok Build CLI — outer loop

Owns:

- Research and requirements gathering (real-time external sources)
- Architecture decomposition (turning a feature request into ordered tickets)
- Ticket dispatch (handing one ticket at a time to the inner loop)
- Deployment and post-deploy verification
- Long-running monitors and self-healing triggers

Does NOT:

- Edit production code directly. All code edits inside acceptance-tested scope go through the inner loop.
- Override the inner loop's "green" gate. If Claude says tests fail, Grok does not deploy.

### Claude TDD Pro — inner loop

Owns:

- Red: write minimal failing test for the current ticket
- Green: implement minimal code to pass
- Refactor: improve while keeping tests green
- Decision-trail emission for the change (file paths, test outcomes, provenance refs)

Does NOT:

- Do its own research outside the ticket's pre-supplied context
- Decide whether a ticket should exist
- Deploy

The inner loop is invoked via `claude -p` (headless) inside a workspace where the **`claude-tdd-pro` Claude Code plugin** has been installed and pinned to a specific version. The plugin's `.claude-plugin/plugin.json` manifest surfaces its full toolkit — skills, commands, agents, hooks, MCP servers, monitors, output styles — and Claude Code discovers them automatically.

The harness's inner loop binds to these plugin-shipped skills:

- `tdd-feature-build` — the TDD feature loop
- `test-first-extract` — test-first extraction discipline
- `spec-first` / `spec` — write the spec before the code
- `architect`, `pr-quality`, `flow-guard`, `bug-fix-discipline` — supporting gates

> **Gap to resolve in TICKET-004:** the three session-load skills referenced in earlier drafts (`tdd-pro-cl-workflow`, `tdd-pro-batch-cl`, `tdd-pro-bash32-portability`) are not exposed by claude-tdd-pro's plugin manifest, so they are outside the dependency surface today. TICKET-004 resolves this by either (a) binding to the plugin's TDD skills above, or (b) filing an upstream request to add the trio to the plugin manifest's shipped skill set.

## Dependency boundary

claude-tdd-pro is an **installable Claude Code plugin**. grok-claude-tdd-pro depends on it the same way an npm app depends on a package: via a versioned pin in configuration, with explicit upgrades.

- **Install surface.** grok-claude-tdd-pro's `.claude/settings.json` lists `claude-tdd-pro` as an enabled plugin (via marketplace entry or git URL), pinned to a specific version (e.g. `0.3.0`).
- **What's pinned.** The `version` field in claude-tdd-pro's `.claude-plugin/plugin.json` (currently `0.3.0`).
- **What comes with the pin.** Everything the plugin manifest declares: skills (`./skills/`), commands (`./commands/`), agents (`./agents/`), hooks (`./hooks/hooks.json`), MCP servers (`./.mcp.json`), monitors (`./monitors/monitors.json`), output styles (`./output-styles/`), LSP config (`./.lsp.json`), and user-tunable config (`userConfig`).
- **Upgrade path.** Bump the version pin, re-install, run the harness's smoke tests (TICKET-006 wires these), then commit. Never reach across the filesystem to a sibling claude-tdd-pro checkout — that defeats versioning.
- **Two repos, one edge.** claude-tdd-pro evolves independently. grok-claude-tdd-pro tracks the version that works.

This boundary is enforced by the **Dependency invariant** in `CLAUDE.md` — no path-based references to claude-tdd-pro are permitted in any tracked file.

## Handoff contract (defined in detail by TICKET-002)

Grok → Claude (per-ticket payload):

```json
{
  "ticket_id": "TICKET-NNN",
  "title": "...",
  "acceptance_criteria": ["...", "..."],
  "file_scope": ["path/to/touch.ext", "..."],
  "context": {
    "research_refs": ["url-or-doc-id", "..."],
    "decomposition_parent": "FEATURE-NNN",
    "prior_decisions": ["..."]
  }
}
```

Claude → Grok (per-ticket response):

```json
{
  "ticket_id": "TICKET-NNN",
  "status": "green" | "red" | "blocked",
  "changed_files": ["...", "..."],
  "test_results": {"passed": N, "failed": N, "skipped": N},
  "decision_trail_ref": "path/or/id",
  "notes": "..."
}
```

The exact JSON schema, error semantics, and freshness rules land in TICKET-002.

## No new SKILL.md

The briefing's suggestion of a new `tdd-pro-core` SKILL.md is deliberately rejected. The plugin already ships the inner-loop machinery (`tdd-feature-build`, `test-first-extract`, `spec-first`, `architect`, `pr-quality`, …). A new SKILL.md inside grok-claude-tdd-pro would either duplicate the plugin's capabilities or become a thin wrapper.

Whatever harness-specific behavior is needed lives in:

1. The handoff contract (TICKET-002) — the JSON wire format between Grok and Claude.
2. The orchestrator templates in `.grok/` (TICKET-003) — Grok's prompt scaffolding.
3. The install wiring (TICKET-004) — pinning the plugin version and surfacing its skills.

None of those require authoring a new SKILL.md. The plugin is the SKILL surface.

## Self-healing extension (designed in TICKET-008)

Beyond the per-feature flow, Grok runs a long-running monitor that:

- Watches debt thresholds (test flake rate, refactor backlog, coverage delta)
- Spawns Claude TDD Pro refactor cycles when thresholds breach
- Re-runs the deploy pipeline on green

This closes the loop: the harness is not just "build the feature" but "keep the codebase healthy on autopilot."

## What this architecture is NOT

- A replacement for the canonical architecture inside the `claude-tdd-pro` plugin. That remains the source of truth for the quality core. This document is the architecture for the **harness around the plugin**.
- An invitation to invent features inside claude-tdd-pro. If the harness needs something claude-tdd-pro doesn't expose, that lands as a v1.11 amendment proposal in that repo, separately.
