#!/usr/bin/env bash
# P-7 fine-tunes registry validator. Schema: artifact_id + base_model
# required; training_data + license optional but recommended; no
# duplicate artifact_id within the registry.
set -uo pipefail
REGISTRY=""; CHECK=""; EMIT=""; OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --registry) REGISTRY="$2"; shift 2 ;;
    --check) CHECK="$2"; shift 2 ;;
    --emit) EMIT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    -h|--help) echo "Usage: validate-fine-tunes.sh --registry <yaml> [--check license|training-data] [--emit json --out <file>]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$REGISTRY" || ! -f "$REGISTRY" ]] && { echo "validate-fine-tunes: --registry <yaml> required" >&2; exit 2; }

REGISTRY="$REGISTRY" CHECK="$CHECK" EMIT="$EMIT" OUT="$OUT" node -e '
const fs = require("fs");
const body = fs.readFileSync(process.env.REGISTRY, "utf8");
const lines = body.split("\n");
const entries = [];
for (const l of lines) {
  const m = l.match(/-\s*\{([^}]+)\}/);
  if (m) {
    const obj = {};
    for (const p of m[1].split(",").map(s => s.trim())) {
      const idx = p.indexOf(":");
      if (idx > 0) {
        const k = p.slice(0, idx).trim();
        const v = p.slice(idx + 1).trim().replace(/^["\047]|["\047]$/g, "");
        obj[k] = v;
      }
    }
    entries.push(obj);
  }
}

const check = process.env.CHECK;
if (check === "license") {
  for (const e of entries) {
    if (!e.license) { process.stderr.write(`validate-fine-tunes: artifact=${e.artifact_id} missing license\n`); process.exit(1); }
    process.stderr.write(`validate-fine-tunes: artifact_id=${e.artifact_id} license=${e.license}\n`);
  }
  process.exit(0);
}
if (check === "training-data") {
  for (const e of entries) {
    if (!e.training_data) { process.stderr.write(`validate-fine-tunes: artifact=${e.artifact_id} missing training_data\n`); process.exit(1); }
    process.stderr.write(`validate-fine-tunes: artifact_id=${e.artifact_id} training_data=${e.training_data}\n`);
  }
  process.exit(0);
}

// Default validation: artifact_id + base_model required; no dupes.
const seen = new Set();
for (const e of entries) {
  if (!e.artifact_id) { process.stderr.write("validate-fine-tunes: entry missing required field: artifact_id\n"); process.exit(1); }
  if (!e.base_model) { process.stderr.write(`validate-fine-tunes: artifact=${e.artifact_id} missing required field: base_model\n`); process.exit(1); }
  if (seen.has(e.artifact_id)) { process.stderr.write(`validate-fine-tunes: duplicate_artifact_id=${e.artifact_id}\n`); process.exit(1); }
  seen.add(e.artifact_id);
}

if (process.env.EMIT === "json" && process.env.OUT) {
  require("fs").writeFileSync(process.env.OUT, JSON.stringify({ valid: true, entries, count: entries.length }));
}

process.stderr.write(`validate-fine-tunes: valid=true count=${entries.length} registry=${process.env.REGISTRY}\n`);
'
