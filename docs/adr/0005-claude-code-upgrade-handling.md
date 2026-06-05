# 0005. Intelligent Claude Code upgrade handling

- **Status:** accepted
- **Deciders:** @drumfiend21
- **Decision_id:** ADR-0005
- **Architect_session:** post-Musk-leadership review action
- **Date:** 2026-06-04

## Context

`claude-tdd-pro` is a Claude Code plugin. When Anthropic releases a
new Claude Code version, the plugin's hook surface (PreToolUse,
PostToolUse, Stop, SessionStart) and the slash-command registration
mechanism can change underneath the plugin. Prior reviews — Musk
team, Musk Engineering Leadership, joint Fowler + Musk — identified
hook brittleness as the project's highest-risk dimension.

The pre-ADR-0005 design covered upgrade handling at "satisfactory
for a disciplined solo operator who knows the workflow." It did not
cover automated detection-react-verify, which industry best practice
(npm `engines`, Cargo `rust-version`, VS Code extension
`engines.vscode`) does.

This ADR codifies the upgrade contract.

## Considered options

1. **Status quo** — operator runs `install.sh upgrade` manually
   after Claude Code updates.
2. **Auto-update the pinned plugin on Claude Code change** —
   rejected; violates the lockfile / ADR-gated upgrade discipline.
3. **Detect-verify-fall-back** — adopted.

## Decision

Adopt the **detect-verify-fall-back** model.

### Detect

`commands/claude-version-detect.sh` reads the host Claude Code
version from multiple sources (env, CLI, settings.json, version
file) and caches the result. Telemetry event
`claude-version.detected` fires on every session start.

`compatibility/claude-code-versions.yaml` declares the
`known_good`, `known_broken`, and `untested` Claude Code version
ranges, plus the hook payload contract this plugin depends on.
This is the analog of `npm engines.node` / Cargo `rust-version` /
VS Code `engines.vscode`.

### Verify

`hooks/scripts/session-start-version-check.sh` runs at every
SessionStart. If the current Claude Code version differs from the
last-seen cached value, it auto-invokes
`scripts/post-upgrade-verify.sh`, which:

- Runs `scripts/standalone-verify.sh` (the 85% platform-independent
  surface check).
- Runs a rubric suite smoke test.
- Runs the four atomic fitness gates.
- Compares against the most recent
  `audit/pre-upgrade-<timestamp>.json` snapshot if one exists.

Emits `post-upgrade.verify` telemetry with verdict
`PASS | DEGRADED | FAIL`.

### Fall back

`hooks/scripts/payload-validator.sh` is sourced at the top of every
hook script. On payload-shape divergence (missing required field,
malformed JSON, unknown event), it:

1. Logs `hook.payload-shape-divergence` telemetry event.
2. Writes `~/.claude-tdd-pro/standalone-mode` marker file.
3. Causes subsequent hook scripts to exit 0 immediately (so Claude
   Code does not see crashes / does not re-fire).
4. Operator gets a one-time stderr notification with the next-step
   command.

In **standalone mode**, the plugin's 85% platform-independent
surface (rubric runner, fitness functions, LSP, CI, CLI) continues
to function. The 15% Claude-Code-specific surface (hooks +
slash-command dispatch) is suspended until the operator runs
`bash hooks/scripts/payload-validator.sh --disengage`.

### Re-engagement

Operator-driven, never automatic. After investigating the
divergence (typically by reading
`audit/post-upgrade-<timestamp>.json` and the
`compatibility/claude-code-versions.yaml` notes), the operator:

1. Updates `compatibility/claude-code-versions.yaml` to reflect
   the now-tested range (if the new Claude Code version is
   compatible) — this is a governance edit, ADR-gated.
2. Optionally bumps the plugin pin via
   `bash commands/install.sh upgrade --yes --force`.
3. Disengages standalone mode:
   `bash hooks/scripts/payload-validator.sh --disengage`.

## Decision rationale

The model maps to known-good industry patterns:

- **Detect** is npm-style version awareness.
- **Verify** is the CD-pipeline post-deploy health check.
- **Fall back** is the VS Code extension pattern for host API
  incompatibility.

The model preserves the project's load-bearing properties:

- **Pinning discipline.** The plugin pin is never auto-bumped.
- **Audit chain.** Every transition (detect, verify, engage,
  disengage) emits telemetry; pre-upgrade snapshots persist in
  `audit/`.
- **ADR-gated upgrades.** Updating
  `compatibility/claude-code-versions.yaml` requires a governance
  CL with an ADR per `CLAUDE.md`.
- **Operator authority.** Standalone-mode disengagement is
  operator-driven. The plugin will never silently re-engage
  hooks against a version it has flagged as incompatible.

## Provenance

- Reference: npm CLI documentation on `engines` field
  (https://docs.npmjs.com/cli/v10/configuring-npm/package-json#engines)
- Reference: VS Code extension manifest `engines.vscode`
  (https://code.visualstudio.com/api/references/extension-manifest)
- Reference: Cargo Book `rust-version` field
- Validated: this CL ships the seven components and runs the suite
  green at 3763 passed, 0 failed.

## Controls

- `compatibility/claude-code-versions.yaml` — the
  declared-compatibility manifest, governance-gated.
- `commands/claude-version-detect.sh` — version-detection surface.
- `hooks/scripts/session-start-version-check.sh` — auto-detect.
- `hooks/scripts/payload-validator.sh` — shape validation +
  auto-fallback.
- `scripts/pre-upgrade-check.sh` — snapshot baseline.
- `scripts/post-upgrade-verify.sh` — verification verdict.
- `docs/CLAUDE_CODE_COMPATIBILITY.md` — operator-facing
  workflow documentation.

## What this moves at the review-grading level

This ADR is the response to:
- The Musk-leadership review's "Hook & Guard Brittleness" critique
  (closes via documented failure modes + auto-fallback).
- The xAI hiring committee's "vertical integration" critique
  (closes via documented-and-tested platform-independence model).
- The convened-panel finding that the codebase lacks an automated
  detection-react-verify loop for Claude Code upgrades specifically.

The remaining items the convened panel named (real users, real
recruits) are still external action.
