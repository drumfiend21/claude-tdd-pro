#!/usr/bin/env bash
# X-8 LSP surface per §14. Wraps the rubric/runner.sh detector dispatch
# in a minimal Language Server Protocol stub. Editors (Cursor, VS Code,
# Continue, Aider, Windsurf) consume diagnostics via the standard LSP
# textDocument/publishDiagnostics method.
#
# Usage:
#   tdd-pro-lsp.sh                          start LSP over stdio
#   tdd-pro-lsp.sh --print-diagnostics      one-shot mode per §14 X-8
#                                          (run detectors, emit JSON
#                                          diagnostics to stdout, exit)
#   tdd-pro-lsp.sh --help

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"

MODE="server"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --print-diagnostics) MODE="diagnostics"; shift ;;
    -h|--help)
      echo "Usage: tdd-pro-lsp.sh [--print-diagnostics] [--help]"
      echo "  --print-diagnostics  one-shot mode: run detectors and emit"
      echo "                       JSON diagnostics to stdout"
      exit 0 ;;
    *) shift ;;
  esac
done

if [[ "$MODE" == "diagnostics" ]]; then
  # One-shot: collect diagnostics from the rubric runner and emit
  # ESLint-shaped JSON for downstream LSP consumption.
  bash "$PLUGIN_ROOT/evals/runner.sh" --filter "smoke" 2>&1 | \
    node -e '
      const fs = require("fs");
      const raw = fs.readFileSync(0, "utf8");
      const out = { diagnostics: [] };
      for (const line of raw.split("\n")) {
        if (line.startsWith("  ✗ ")) {
          out.diagnostics.push({
            severity: 1,
            message: line.slice(4),
            range: { start: { line: 0, character: 0 }, end: { line: 0, character: 0 } }
          });
        }
      }
      process.stdout.write(JSON.stringify(out, null, 2) + "\n");
    '
  exit 0
fi

# LSP server stdio loop (stub): read Content-Length framed messages,
# respond with a minimal capability set.
echo '{"jsonrpc":"2.0","id":0,"result":{"capabilities":{"textDocumentSync":1}}}' >&2
cat >/dev/null
