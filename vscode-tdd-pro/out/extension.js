// X-8 VS Code extension entry per §24 v1.10 amendment. Thin packaging
// layer: spawns the tdd-pro-lsp binary (default lookup on PATH;
// override via tdd-pro.lspPath setting) and wires it to VS Code's
// language client via the standard LSP protocol.
//
// Cursor and any LSP-compliant editor read the same binary directly;
// this extension exists purely as the VS Code Marketplace packaging.

const { workspace, ExtensionContext } = require("vscode");

/** @type {import('vscode-languageclient/node').LanguageClient | undefined} */
let client;

function activate(context) {
  const cfg = workspace.getConfiguration("tdd-pro");
  const lspPath = cfg.get("lspPath", "tdd-pro-lsp");

  try {
    const { LanguageClient, TransportKind } = require("vscode-languageclient/node");
    const serverOptions = {
      command: lspPath,
      transport: TransportKind.stdio
    };
    const clientOptions = {
      documentSelector: [{ scheme: "file", pattern: "**/*" }],
      synchronize: { configurationSection: "tdd-pro" }
    };
    client = new LanguageClient("tdd-pro", "Claude TDD Pro", serverOptions, clientOptions);
    client.start();
    context.subscriptions.push({ dispose: () => client && client.stop() });
  } catch (_e) {
    // vscode-languageclient not installed; extension activates as a
    // packaging stub. Operators bring their own LSP wiring via the
    // tdd-pro.lspPath setting and a host-supplied client.
  }
}

function deactivate() {
  return client ? client.stop() : undefined;
}

module.exports = { activate, deactivate };
