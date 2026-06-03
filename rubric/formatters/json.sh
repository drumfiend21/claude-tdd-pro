#!/usr/bin/env bash
# E-9 ESLint json formatter per §16. Re-emits aggregated detector
# findings as ESLint-shaped JSON (array of {filePath, messages: [...]}
# objects). The wrapping is what existing ESLint CI plugins expect.
#
# Input: detector JSON on stdin.
# Output: ESLint-shape JSON on stdout.
# Per §2.2: stdout-only, exit 0.

set -uo pipefail

node -e '
  const fs = require("fs");
  const raw = fs.readFileSync(0, "utf8").trim();
  if (!raw) { process.stdout.write("[]\n"); process.exit(0); }
  let findings = [];
  try {
    const parsed = JSON.parse(raw);
    findings = Array.isArray(parsed) ? parsed : [parsed];
  } catch {
    for (const line of raw.split("\n")) {
      if (!line.trim()) continue;
      try { findings.push(JSON.parse(line)); } catch {}
    }
  }
  const byFile = {};
  for (const f of findings) {
    if (!f || !f.file) continue;
    (byFile[f.file] = byFile[f.file] || []).push({
      ruleId: f.rule || null,
      severity: f.severity === "error" ? 2 : 1,
      message: f.message || "",
      line: f.line || 0,
      column: f.column || 0,
      nodeType: null,
      messageId: f.messageId || undefined
    });
  }
  const out = Object.keys(byFile).sort().map(file => ({
    filePath: file,
    messages: byFile[file],
    errorCount: byFile[file].filter(m => m.severity === 2).length,
    warningCount: byFile[file].filter(m => m.severity === 1).length
  }));
  process.stdout.write(JSON.stringify(out, null, 2) + "\n");
'
