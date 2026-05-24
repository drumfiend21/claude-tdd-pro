# hybrid-harness-proto

A prototype harness that pairs **Grok Build CLI** (outer loop — research, decomposition, coordination, deployment) with **Claude TDD Pro** (inner loop — Red-Green-Refactor enforcement), where Claude TDD Pro is consumed as an installed Claude Code plugin dependency.

## Why this exists

Enterprise engineering orgs (1,000+ ICs) need both pipeline-level automation AND quality discipline that survives velocity. Grok Build CLI is strong on the outer loop; Claude TDD Pro is strong on the inner loop. This repo is the design + integration substrate that lets them compose.

## How to read this repo

Read in this order:

1. `docs/architecture.md` — the harness architecture and role split
2. `TICKETS.md` — the ordered backlog (TICKET-001 .. TICKET-011)
3. `AUTOMATION_INTEL.md` — Boston/US enterprise signal log
4. `CLAUDE.md` — workflow rules when Claude Code operates inside this repo

The `docs/`, `.grok/`, `.claude/`, and `examples/` subtrees contain stubs that are filled in by individual tickets.

## Status

Design-only. No code yet. TICKET-001 lands the scaffold (this commit). All other tickets land in subsequent CLs.

## Dependency on claude-tdd-pro

This repo does not duplicate Claude TDD Pro's quality core. It depends on the **`claude-tdd-pro` Claude Code plugin** (version `0.3.0`+), installed natively via Claude Code's plugin mechanism. No sibling-checkout, no path references, no skill duplication.

The plugin ships skills, commands, agents, hooks, MCP servers, monitors, and output styles. The harness's inner loop binds to the plugin's TDD-focused skills:

- `tdd-feature-build` — TDD feature loop
- `test-first-extract` — test-first extraction discipline
- `spec-first` / `spec` — spec writing before code
- `architect`, `pr-quality`, `flow-guard`, `bug-fix-discipline` — supporting gates

> **Gap to resolve in TICKET-004:** the three session-load skills referenced in earlier scaffold drafts (`tdd-pro-cl-workflow`, `tdd-pro-batch-cl`, `tdd-pro-bash32-portability`) are not currently surfaced by claude-tdd-pro's plugin manifest, so they are not part of the dependency surface. TICKET-004 must either (a) bind to the plugin's existing TDD skills above, or (b) file an upstream request asking the claude-tdd-pro maintainer to expose the trio through the plugin manifest.

Install wiring is defined in **TICKET-004**. Version pinning policy + upgrade workflow in **TICKET-011**.

## Maintenance separation

claude-tdd-pro is a separate project with its own release cadence. grok-claude-tdd-pro tracks a pinned plugin version; upgrades are explicit, never floating. Two repos, one dependency edge. This invariant is restated as a non-negotiable rule in `CLAUDE.md`.
