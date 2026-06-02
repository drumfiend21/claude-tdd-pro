#!/usr/bin/env bash
# E-9 ESLint stylish formatter per §16. Reads aggregated detector JSON
# from stdin and emits ESLint's stylish format to stdout (one finding
# per line, grouped by file, with ASCII colour-codes optional).
#
# Input shape (one JSON object per line OR a single JSON array):
#   {"file":"<path>","line":<n>,"column":<n>,"severity":"error|warn",
#    "message":"<text>","rule":"<rule-id>"}
#
# Output (ESLint stylish-compatible):
#   <abs-path>
#     <line>:<col>  error|warning  <message>  <rule-id>
#   ✖ <total> problems (<errors> errors, <warnings> warnings)
#
# Per §2.2 detector contract: stdout = formatted findings, exit 0 (no
# violation surface; this is just a format wrapper).

set -uo pipefail

node -e '
  const fs = require("fs");
  const raw = fs.readFileSync(0, "utf8").trim();
  if (!raw) { process.stdout.write(""); process.exit(0); }
  let findings = [];
  // Accept either JSON array or one-per-line JSONL.
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
    (byFile[f.file] = byFile[f.file] || []).push(f);
  }
  let errors = 0, warnings = 0;
  for (const file of Object.keys(byFile).sort()) {
    process.stdout.write(file + "\n");
    for (const f of byFile[file]) {
      const sev = f.severity === "error" ? "error" : "warning";
      if (sev === "error") errors++; else warnings++;
      const line = `  ${f.line || 0}:${f.column || 0}  ${sev}  ${f.message || ""}  ${f.rule || ""}`;
      process.stdout.write(line + "\n");
    }
    process.stdout.write("\n");
  }
  const total = errors + warnings;
  process.stdout.write(`✖ ${total} problems (${errors} errors, ${warnings} warnings)\n`);
'
