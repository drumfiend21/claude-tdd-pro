#!/usr/bin/env bash
# L-9 provenance entry validator. Validates pr-corpus class provenance:
# verbatim_quote on every supporting PR, evidence_count integer, organizations_count integer,
# optional --check-counts (declared vs actual), --strict (non-empty supporting_prs),
# --check-class (emit class= field).
set -uo pipefail
PROV=""; CHECK_CLASS=0; CHECK_COUNTS=0; STRICT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --provenance) PROV="$2"; shift 2 ;;
    --check-class) CHECK_CLASS=1; shift ;;
    --check-counts) CHECK_COUNTS=1; shift ;;
    --strict) STRICT=1; shift ;;
    -h|--help) echo "Usage: validate-provenance.sh --provenance <json> [--check-class] [--check-counts] [--strict]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$PROV" || ! -f "$PROV" ]] && { echo "validate-provenance: --provenance <file> required" >&2; exit 2; }

PROV="$PROV" CHECK_CLASS="$CHECK_CLASS" CHECK_COUNTS="$CHECK_COUNTS" STRICT="$STRICT" node -e '
const fs = require("fs");
const j = JSON.parse(fs.readFileSync(process.env.PROV, "utf8"));
const errors = [];
const prs = Array.isArray(j.supporting_prs) ? j.supporting_prs : [];

if (process.env.STRICT === "1" && prs.length === 0) {
  errors.push("supporting_prs is empty (--strict mode requires non-empty array)");
}
if (j.evidence_count === undefined) errors.push("missing required field: evidence_count");
if (j.organizations_count === undefined) errors.push("missing required field: organizations_count");
for (const pr of prs) {
  if (pr.verbatim_quote === undefined || pr.verbatim_quote === "") {
    errors.push(`missing required field: verbatim_quote pr=${pr.number}`);
  }
}
if (process.env.CHECK_COUNTS === "1") {
  const actualEvidence = prs.length;
  if (j.evidence_count !== undefined && j.evidence_count !== actualEvidence) {
    errors.push(`evidence_count_mismatch declared=${j.evidence_count} actual=${actualEvidence}`);
  }
  const actualOrgs = new Set(prs.map(p => p.org).filter(Boolean)).size;
  if (j.organizations_count !== undefined && j.organizations_count !== actualOrgs) {
    errors.push(`organizations_count_mismatch declared=${j.organizations_count} actual=${actualOrgs}`);
  }
}

if (errors.length > 0) {
  for (const e of errors) process.stderr.write(`validate-provenance: ${e}\n`);
  process.exit(1);
}

if (process.env.CHECK_CLASS === "1") {
  process.stderr.write(`validate-provenance: class=${j.class || ""}\n`);
}
process.stderr.write(`validate-provenance: valid=true\n`);
'
