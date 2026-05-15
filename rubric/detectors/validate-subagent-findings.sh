#!/usr/bin/env bash
# validate-subagent-findings.sh — C-11 substrate. Validates a JSON
# array of findings against the §2.3 subagent-findings shape:
# {severity, rule_id?, file, line, finding, suggested_fix}.

set -uo pipefail

FINDINGS="${1:-}"
if [[ -z "$FINDINGS" || ! -f "$FINDINGS" ]]; then
  echo "validate-subagent-findings: file not found: $FINDINGS" >&2
  exit 2
fi

FINDINGS="$FINDINGS" node -e '
const fs = require("fs");
const required = ["severity", "file", "line", "finding"];
const data = JSON.parse(fs.readFileSync(process.env.FINDINGS, "utf8"));
if (!Array.isArray(data)) {
  process.stderr.write("validate-subagent-findings: root must be a JSON array of findings\n");
  process.exit(2);
}
const errors = [];
data.forEach((f, idx) => {
  for (const r of required) {
    if (!(r in f) || f[r] === null || f[r] === "" || f[r] === undefined) {
      errors.push(`finding[${idx}]: missing required field ${r}`);
    }
  }
});
if (errors.length > 0) {
  errors.forEach(e => process.stderr.write(`validate-subagent-findings: ${e}\n`));
  process.exit(2);
}
process.stderr.write(`validate-subagent-findings: ok (${data.length} findings)\n`);
'
