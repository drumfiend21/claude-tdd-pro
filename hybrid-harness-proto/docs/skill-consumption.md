# Skill Consumption

Status: **stub — filled in by TICKET-004**.

This file will document, concretely, how the installed `claude-tdd-pro` Claude Code plugin is wired into prototype-repo `claude -p` sessions:

- Install entry: marketplace declaration or git URL in `.claude/settings.json`
- Version pin format and where it lives
- Which plugin-shipped skills the harness binds to (default candidates: `tdd-feature-build`, `test-first-extract`, `spec-first`, `spec`, `architect`, `pr-quality`, `flow-guard`, `bug-fix-discipline`)
- Resolution of the session-load-skills gap (the three `tdd-pro-*` skills are not currently in the plugin manifest's `./skills/`; this ticket decides whether to bind to plugin-shipped equivalents or upstream the trio)
- Invocation patterns for the inner loop from `.grok/` orchestrator templates

The **Dependency invariant** from `CLAUDE.md` is the non-negotiable backdrop: no filesystem path references to claude-tdd-pro are permitted; the plugin is the only consumption surface.
