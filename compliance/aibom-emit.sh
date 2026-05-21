#!/usr/bin/env bash
# P-7 AIBOM emitter. Ingests prompts/fine-tunes.yaml (and other model
# components) and emits a structured JSON bill of materials.
set -uo pipefail
FINE_TUNES=""; OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fine-tunes) FINE_TUNES="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    -h|--help) echo "Usage: aibom-emit.sh --fine-tunes <yaml> --out <json>"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$OUT" ]] && { echo "aibom-emit: --out <json> required" >&2; exit 2; }

mkdir -p "$(dirname "$OUT")"
FT="$FINE_TUNES" OUT="$OUT" node -e '
const fs = require("fs");
const records = [];
if (process.env.FT && fs.existsSync(process.env.FT)) {
  const body = fs.readFileSync(process.env.FT, "utf8");
  for (const line of body.split("\n")) {
    const m = line.match(/-\s*\{([^}]+)\}/);
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
      records.push(obj);
    }
  }
}
fs.writeFileSync(process.env.OUT, JSON.stringify({ fine_tunes: records, generated_at: new Date().toISOString() }));
'
echo "aibom-emit: wrote $OUT" >&2
