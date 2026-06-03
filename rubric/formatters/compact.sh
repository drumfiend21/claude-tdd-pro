#!/usr/bin/env bash
# E-9 ESLint compact formatter per §16. One line per finding,
# vim-quickfix-compatible.
#
# Input: aggregated detector JSON on stdin (array OR JSONL).
# Output:
#   <file>:<line>:<col>:  <severity>  <message>  (<rule>)
#
# Per §2.2: stdout-only, exit 0.

set -uo pipefail

node -e '
  const fs = require("fs");
  const raw = fs.readFileSync(0, "utf8").trim();
  if (!raw) { process.exit(0); }
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
  for (const f of findings) {
    if (!f || !f.file) continue;
    const sev = f.severity === "error" ? "Error" : "Warning";
    process.stdout.write(`${f.file}:${f.line || 0}:${f.column || 0}: ${sev} - ${f.message || ""} (${f.rule || ""})\n`);
  }
'
