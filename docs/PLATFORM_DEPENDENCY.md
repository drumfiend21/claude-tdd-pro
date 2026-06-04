# Platform dependency — Claude Code and the abstraction layer

Per the simulated Musk-team review (Ashok / Elon):
> "You're a plugin on top of Claude Code. You're not in control of
>  your platform. What happens when Claude Code's hook API changes?"

This document is the answer.

## The dependency surface

The system depends on Claude Code at these specific touchpoints:

| Touchpoint | What we use | Risk if changed |
|---|---|---|
| Hook API | `Stop`, `PreToolUse`, `PostToolUse`, `SessionStart` event names + the `hooks` block in `~/.claude/settings.json` | High — installer breaks |
| Slash command surface | `/<name>` syntax + `commands/<name>.md` registration | Medium — operator UX changes |
| Agent definition format | `agents/<name>.md` frontmatter (name, description, model) | Medium — subagent dispatch breaks |
| Skill definition format | `skills/<name>/SKILL.md` frontmatter | Medium — skill auto-trigger breaks |
| File system layout | `~/.claude/` / `.claude/` scope distinction | Low — installer adjusts |

## The abstraction layer

The system is designed so the **runner is portable**. Specifically:

- `rubric/runner.sh` does not import Claude Code's API. It reads from
  the file system and writes to stdout/stderr.
- `lsp/tdd-pro-lsp/src/server.ts` speaks standard LSP. It does not
  call Claude Code APIs. Any LSP-compliant editor consumes it.
- `.github/workflows/rubric-check.yml`, `.gitlab-ci.yml`, and the
  `hooks/pre-commit` script invoke the runner directly. They don't
  depend on Claude Code.
- The installer (`scripts/install.sh`) is the only component that
  touches `~/.claude/settings.json`. It is isolated to one file.

This means the system runs **without Claude Code** in the following
configurations:

1. **CLI-only.** `bash $CLAUDE_PLUGIN_ROOT/evals/runner.sh` works
   anywhere bash + node + ruby are installed.
2. **LSP for any editor.** `tdd-pro-lsp` works in Cursor, VS Code,
   Vim/Neovim (via nvim-lspconfig), Emacs (via eglot/lsp-mode), Helix.
3. **CI-only.** The GitHub Actions / GitLab CI / pre-commit
   workflows do not require Claude Code on the runner.

The Claude-Code-specific layer is **only the hooks bundle (X-7) and
the slash commands**. Roughly 15% of the system's operational
surface. The other 85% runs platform-independently.

## What we do not depend on

- Claude API specifically — the LLM-judge detector (`llm-judge.sh`)
  auto-detects `claude` or `grok` CLI; can be extended to OpenAI,
  Llama, or any HTTP-based model.
- Anthropic's SDK at runtime — only at install time (the installer
  hint to set the SDK env var).
- Cloud services — everything is local-first. Telemetry is opt-in.

## The vertical-integration roadmap

If Claude Code as a platform becomes problematic (deprecated, API
breaks, pricing model changes), the migration path is:

1. **Hooks → file-watcher.** Replace the Claude Code hook surface
   with a generic `fswatch` / `inotify` watcher that fires the same
   events on save. Estimated effort: 1 day.
2. **Slash commands → operator CLI.** Replace `/<command>` with
   `tdd-pro <command>` as a single binary. Already partially done
   via `scripts/install.sh` subcommands. Estimated effort: 0.5 day.
3. **Agent + skill definitions → portable contract.** Move
   frontmatter formats under our control by versioning the schema in
   `docs/agent-schema-v1.yaml` and `docs/skill-schema-v1.yaml`.
   Estimated effort: 1 day.

Total cost of leaving Claude Code as a platform: ~2.5 days
engineering. **The system is not architecturally captive.**

## Why we ship as a Claude Code plugin first

Network effects. Claude Code has the developer audience for an
AI-assisted-development workflow tool. Shipping as a plugin gets
the customer journey to first-use in <60 seconds (per
`QUICKSTART.md`). Building a standalone CLI/LSP/CI gate first
would have meant shipping into a vacuum.

The plugin model is the GTM. The portability is the insurance.

## What changes if the platform changes

When Claude Code ships a breaking change to the hook API:

1. The installer (`scripts/install.sh`) is the only component that
   needs updating.
2. The fitness functions and rubric runner are unaffected.
3. Existing installs continue to work until they `install.sh upgrade`.
4. The CHANGELOG entry names the breaking change explicitly.

This is a **bounded** dependency, not a captive one.
