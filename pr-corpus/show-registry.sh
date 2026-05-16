#!/usr/bin/env bash
# L-17 prints registry entries with optional --field projection.
# Uses a tolerant flow-mapping parser since `last_modified: 2026-05-13T00:00:00Z`
# inside an inline flow mapping is rejected by Psych as ambiguous tokens.
set -uo pipefail
REG=""; FIELD=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --registry) REG="$2"; shift 2 ;;
    --field) FIELD="$2"; shift 2 ;;
    -h|--help) echo "Usage: show-registry.sh --registry <yaml> [--field <name>]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$REG" || ! -f "$REG" ]] && { echo "show-registry: --registry <yaml> required" >&2; exit 2; }

REG="$REG" FIELD="$FIELD" node -e '
const fs = require("fs");
const text = fs.readFileSync(process.env.REG, "utf8");
const lines = text.split("\n");
const field = process.env.FIELD;
let inSources = false;
for (const l of lines) {
  if (/^sources:/.test(l)) { inSources = true; continue; }
  if (/^[a-zA-Z_]/.test(l)) { inSources = false; continue; }
  if (!inSources) continue;
  const flowMatch = l.match(/-\s*\{(.+)\}/);
  if (flowMatch) {
    const parts = flowMatch[1].split(",").map(s => s.trim());
    const obj = {};
    for (const p of parts) {
      const idx = p.indexOf(":");
      if (idx > 0) {
        const k = p.slice(0, idx).trim();
        const v = p.slice(idx + 1).trim();
        obj[k] = v;
      }
    }
    if (obj.id) {
      if (field && obj[field] !== undefined) {
        process.stderr.write(`show-registry: id=${obj.id} ${field}=${obj[field]}\n`);
      } else {
        process.stderr.write(`show-registry: id=${obj.id}\n`);
      }
    }
  }
}
'
