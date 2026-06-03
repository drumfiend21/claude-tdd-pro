---
name: install-hooks
description: X-7 per §23 — installs the packaged Claude Code hooks bundle (Stop, PreToolUse, PostToolUse, SessionStart subset) plus slash commands, agents, and detectors into a target settings.json. Idempotent; emits uninstall metadata so /uninstall-cleanup (O-3) can restore prior state.
budget_impact_estimate: 0 tokens (mechanical settings.json patching).
paths: ["**/*"]
---

# X-7 installable hooks bundle (§23 amendment)

Writes packaged hooks + slash commands + agents + detectors to the
target `settings.json`. Uninstall metadata block stamped at install
time so the cleanup path (O-3) can restore prior state without
auto-deleting audit-log or evidence directories.

## Invocation

```
/install-hooks [--scope user|project] [--include <component>...] [--dry-run] [--force]
```

- `--scope user|project` — install to `~/.claude/settings.json` (user)
  or `.claude/settings.json` (project). Default: `project`.
- `--include <component>` — install only this component (repeatable).
  Components: `hooks`, `commands`, `agents`, `detectors`.
- `--dry-run` — emit plan; no settings.json writes (per §2.14).
- `--force` — override the conflict refusal when target already has
  conflicting hook scripts. Logged to C-4 with conflict diff.

## Uninstall metadata block

```json
{
  "tdd_pro_installed_at": "<ISO 8601>",
  "tdd_pro_components": ["hooks", "commands", "..."],
  "tdd_pro_version": "<semver>",
  "tdd_pro_signature": "<sha256>"
}
```

## Idempotency

Re-running with no version change is a no-op. On version change,
runs the appropriate `migrations/<from>-to-<to>.sh` per O-3.

## Cross-references

- §23 v1.9.1 amendment (this skill)
- O-3 /uninstall-cleanup
- C-4 audit log
- §2.14 destructive command dry-run subjects
