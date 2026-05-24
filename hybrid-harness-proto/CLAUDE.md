# CLAUDE.md — hybrid-harness-proto

Project instructions for Claude when operating in this repo.

## Scope

This repo is a **prototype harness**, not the quality core. The quality core lives in `claude-tdd-pro` and is consumed here as an **installed Claude Code plugin dependency** (see "Dependency invariant" below). When in doubt about TDD discipline, architecture fidelity, or commit workflow, defer to:

- The installed `claude-tdd-pro` plugin (skills/agents/commands surfaced via Claude Code)
- The plugin's source-of-truth docs in the upstream `claude-tdd-pro` repository (`CLAUDE.md`, `docs/architecture-v1.9.md`) — referenced for context, not edited from here

This file adds only what is specific to the hybrid harness.

## Dependency invariant (prime directive)

`claude-tdd-pro` is imported only as an installed Claude Code plugin (`.claude/settings.json` pins a specific version). It is NOT consumed via sibling-checkout, path references, file copies, or skill duplication. Every ticket, every commit, every CI check must preserve this property:

- No relative or absolute path under `../claude-tdd-pro/` or `/.../claude-tdd-pro/` may appear in any tracked file.
- Skill / command / agent names referenced in this repo MUST resolve through the installed plugin's manifest, not through filesystem assumptions.
- Upgrades to claude-tdd-pro happen by bumping the plugin version pin (explicit), never by reaching across the filesystem.

If a feature would require breaking this invariant, the answer is "no" — re-scope the feature or get the dependency upstreamed into claude-tdd-pro's plugin manifest first.

## Two harness rules (non-negotiable)

1. **Grok owns the outer loop.** Research, requirements gathering, architecture decomposition, ticket spawning, deployment, long-running monitoring, self-healing triggers. Grok does not edit code directly inside acceptance-tested scope — it hands off to Claude TDD Pro for that.
2. **Claude TDD Pro owns the inner loop.** Red-Green-Refactor enforcement for one ticket at a time. Claude does not do its own research or deploy — it receives a structured handoff (TICKET-002 schema), produces a passing change, returns control.

Violating either rule means the harness is not being used; it's just two tools running adjacent.

## Working in this repo

- One ticket per CL. Ticket IDs come from `TICKETS.md`.
- Commit messages reference the ticket: `TICKET-NNN: <verb> <object>`.
- Do not modify `claude-tdd-pro` from this repo. If a harness lesson warrants a feature there, file it as a v1.11 amendment proposal in that repo separately.
- The handoff contract (TICKET-002) is the API boundary. If you find yourself extending it ad-hoc, stop and update the contract first.

## What this repo does NOT do

- Re-implement Red-Green-Refactor. Bind to the TDD skills shipped by the installed claude-tdd-pro plugin (see `docs/architecture.md`).
- Define a new `tdd-pro-core` SKILL.md. The plugin's existing skills are the core.
- Touch `claude-tdd-pro` substrate, specs, or architecture text.
- Reach into the claude-tdd-pro repo via filesystem path (see "Dependency invariant" above).
