#!/usr/bin/env bash
# validate-eval-dataset-jsonl.sh — C-11 substrate. Validates that
# each record in an eval-dataset .jsonl has the required fields.
#
# Usage:
#   validate-eval-dataset-jsonl.sh <dataset.jsonl> --require-fields field1,field2,...

set -uo pipefail

DATASET="${1:-}"
shift || true
REQUIRE_FIELDS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --require-fields) REQUIRE_FIELDS="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -z "$DATASET" || ! -f "$DATASET" ]]; then
  echo "validate-eval-dataset-jsonl: dataset not found: $DATASET" >&2
  exit 2
fi

DATASET="$DATASET" REQUIRE_FIELDS="$REQUIRE_FIELDS" node -e '
const fs = require("fs");
const required = (process.env.REQUIRE_FIELDS || "").split(",").map(s => s.trim()).filter(Boolean);
const lines = fs.readFileSync(process.env.DATASET, "utf8").trim().split("\n").filter(Boolean);
const errors = [];
lines.forEach((l, idx) => {
  let rec;
  try { rec = JSON.parse(l); } catch (e) {
    errors.push(`record[${idx}]: invalid JSON (${e.message})`);
    return;
  }
  for (const f of required) {
    if (!(f in rec) || rec[f] === null || rec[f] === undefined || rec[f] === "") {
      errors.push(`record[${idx}]: missing required field ${f}`);
    }
  }
});
if (errors.length > 0) {
  errors.slice(0, 10).forEach(e => process.stderr.write(`validate-eval-dataset-jsonl: ${e}\n`));
  if (errors.length > 10) process.stderr.write(`validate-eval-dataset-jsonl: ... and ${errors.length - 10} more errors\n`);
  process.exit(2);
}
process.stderr.write(`validate-eval-dataset-jsonl: ok (${lines.length} records, all have required fields)\n`);
'
