// X-8 LSP server per §14 X-8 + §24 v1.10 amendment.
//
// Real LSP implementation (replaces the 56-line bash stub at
// lsp/tdd-pro-lsp/tdd-pro-lsp). Speaks the standard
// Language Server Protocol over stdio:
//
//   initialize / initialized
//   textDocument/didOpen
//   textDocument/didSave
//   textDocument/publishDiagnostics
//   shutdown / exit
//
// For each open document, invokes the rubric runner with --filter
// and translates `✗ <spec>` lines into LSP Diagnostic records.
//
// Build:    npx tsc --project lsp/tdd-pro-lsp/
// Run:      node lsp/tdd-pro-lsp/out/server.js
//
// The shipped tdd-pro-lsp shell wrapper at lsp/tdd-pro-lsp/tdd-pro-lsp
// invokes this compiled server when --print-diagnostics is given, and
// also serves as the LSP server entry for editor wiring.

import {
  createConnection,
  TextDocuments,
  TextDocumentSyncKind,
  ProposedFeatures,
  InitializeParams,
  InitializeResult,
  Diagnostic,
  DiagnosticSeverity,
  DidSaveTextDocumentParams,
  DidOpenTextDocumentParams,
  Range,
} from 'vscode-languageserver/node';
import { TextDocument } from 'vscode-languageserver-textdocument';
import { execFile } from 'node:child_process';
import * as path from 'node:path';

interface RubricFinding {
  specName: string;
  message: string;
  severity: DiagnosticSeverity;
  range: Range;
}

const PLUGIN_ROOT =
  process.env.CLAUDE_PLUGIN_ROOT ||
  path.resolve(__dirname, '..', '..', '..');

const connection = createConnection(ProposedFeatures.all);
const documents: TextDocuments<TextDocument> = new TextDocuments(TextDocument);

connection.onInitialize((_params: InitializeParams): InitializeResult => {
  return {
    capabilities: {
      textDocumentSync: TextDocumentSyncKind.Incremental,
      diagnosticProvider: {
        interFileDependencies: true,
        workspaceDiagnostics: false,
      },
    },
    serverInfo: { name: 'tdd-pro-lsp', version: '0.4.0' },
  };
});

connection.onInitialized(() => {
  connection.console.log(
    `tdd-pro-lsp ready (CLAUDE_PLUGIN_ROOT=${PLUGIN_ROOT})`,
  );
});

documents.onDidOpen((event: { document: TextDocument }) => {
  validate(event.document);
});

documents.onDidSave((event: { document: TextDocument }) => {
  validate(event.document);
});

async function validate(doc: TextDocument): Promise<void> {
  const filter = path.basename(doc.uri).replace(/\.[^.]+$/, '');
  const findings = await runRubric(filter);
  const diagnostics: Diagnostic[] = findings.map((f) => ({
    range: f.range,
    severity: f.severity,
    message: f.message,
    source: 'tdd-pro',
    code: f.specName,
  }));
  connection.sendDiagnostics({ uri: doc.uri, diagnostics });
}

function runRubric(filter: string): Promise<RubricFinding[]> {
  return new Promise((resolve) => {
    execFile(
      'bash',
      [path.join(PLUGIN_ROOT, 'evals/runner.sh'), '--filter', filter],
      { env: { ...process.env, CLAUDE_PLUGIN_ROOT: PLUGIN_ROOT } },
      (_err, stdout, _stderr) => {
        const findings: RubricFinding[] = [];
        for (const line of stdout.split('\n')) {
          const m = line.match(/^\s*✗\s+(.+)$/);
          if (!m) continue;
          findings.push({
            specName: m[1],
            message: `rubric spec failed: ${m[1]}`,
            severity: DiagnosticSeverity.Error,
            range: {
              start: { line: 0, character: 0 },
              end: { line: 0, character: 0 },
            },
          });
        }
        resolve(findings);
      },
    );
  });
}

documents.listen(connection);
connection.listen();
