---
name: lsp-bootstrap
description: Bootstraps the X-8 LSP surface for a fresh editor. Use when the operator wants inline diagnostics from the rubric runner in Cursor / VS Code / Continue / Aider / Windsurf and the tdd-pro-lsp binary isn't yet on PATH.
budget_impact_estimate: 0 tokens (mechanical install only; no LLM in the path).
paths: ["**/*"]
---

# LSP bootstrap (X-8)

The X-8 LSP server (`lsp/tdd-pro-lsp.sh`) ships with the plugin but
isn't on PATH by default. This skill performs the one-time install
so editors discover it.

## When to invoke

- Operator clones the plugin and wants editor diagnostics on the
  first session.
- `which tdd-pro-lsp` returns nothing AND the operator wants the
  LSP surface active.

## What it does

1. Symlinks `$CLAUDE_PLUGIN_ROOT/lsp/tdd-pro-lsp.sh` to
   `~/.local/bin/tdd-pro-lsp` (or `/usr/local/bin/` if writable).
2. Reports the path so the operator can configure their editor.
3. Suggests the `vscode-tdd-pro` extension for VS Code / Cursor
   users.

## Architecture cross-refs

- §14 X-8 — LSP surface (this skill)
- §14 X-9 — cloud devcontainer (Codespaces parity)
- §6 P-10 — runtime model router (LSP server respects router for
  any LLM-backed diagnostic enrichment)
