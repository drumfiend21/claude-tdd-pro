#!/usr/bin/env bash
# C-1 detector: every default catalog entry with paywalled:true MUST
# include non-empty document_url and attribution_note (per §2.19).
set -uo pipefail
CATALOG="${1:-}"
[[ -z "$CATALOG" || ! -f "$CATALOG" ]] && { echo "validate-paywalled-entries: usage: <catalog.yaml>" >&2; exit 2; }

CATALOG="$CATALOG" node -e '
  const fs = require("fs");
  const lines = fs.readFileSync(process.env.CATALOG, "utf8").split("\n");
  let cur = null;
  const entries = [];
  for (const l of lines) {
    const idMatch = l.match(/^-\s+id:\s+([A-Za-z0-9._-]+)/);
    if (idMatch) {
      if (cur) entries.push(cur);
      cur = { id: idMatch[1], paywalled: false, document_url: "", attribution_note: "" };
      continue;
    }
    if (!cur) continue;
    const m = l.match(/^\s+(paywalled|document_url|attribution_note):\s*(.*)$/);
    if (m) {
      let val = m[2].trim().replace(/^["\x27]|["\x27]$/g, "");
      if (m[1] === "paywalled") cur.paywalled = (val === "true");
      else cur[m[1]] = val;
    }
  }
  if (cur) entries.push(cur);

  let fail = 0;
  for (const e of entries) {
    if (!e.paywalled) continue;
    if (!e.document_url) { process.stderr.write(`validate-paywalled-entries: id=${e.id} paywalled=true missing document_url\n`); fail = 1; }
    if (!e.attribution_note) { process.stderr.write(`validate-paywalled-entries: id=${e.id} paywalled=true missing attribution_note\n`); fail = 1; }
  }
  if (fail) process.exit(1);
  const paywalledCount = entries.filter(e => e.paywalled).length;
  process.stderr.write(`validate-paywalled-entries: ok paywalled_entries=${paywalledCount} total_entries=${entries.length}\n`);
'
