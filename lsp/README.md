# tdd-pro LSP surface (X-8)

Per architecture §14 X-8. Provides a Language Server Protocol shim
over the rubric runner so editors (Cursor, VS Code, Continue, Aider,
Windsurf) consume diagnostics inline.

## Modes

- **Server (default):** start LSP over stdio, respond to
  `textDocument/publishDiagnostics` requests.
- **One-shot (`--print-diagnostics`):** run the rubric runner once
  and emit ESLint-shaped JSON diagnostics to stdout. Useful for CI
  pipelines, batch scoring, or non-LSP consumers.

## Install

```bash
# Locally
bash lsp/tdd-pro-lsp.sh --help

# As a VS Code language server (configured via vscode-tdd-pro/)
code --install-extension vscode-tdd-pro
```

## Related

- X-1..X-3: CI surfaces (GitHub Actions, GitLab CI, pre-commit)
- X-6: one-way IDE rules export (ESLint-shaped config)
- X-9: cloud devcontainer (Codespaces / Dev Containers parity)
