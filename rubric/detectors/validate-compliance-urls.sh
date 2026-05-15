#!/usr/bin/env bash
# rubric/detectors/validate-compliance-urls.sh — C-13 operator-facing
# COMPLIANCE-URLS.yaml validator per §2.19 compliance source contract.
#
# Operator-facing required: id, name, url, authoritative_publisher,
# jurisdiction, applicable_to, identifier_scheme, why_authoritative
# (multi-line, ≥3 lines), fetch_frequency, legal_review_required
# (boolean), paywalled (boolean), document_url, attribution_note.
#
# Constraints:
#   - jurisdiction in {US Federal, EU, ISO, OTHER, CA, UK, AU, JP, ...}
#   - paywalled and legal_review_required must be boolean
#   - paywalled=true entries must include document_url + attribution_note
#   - id unique within registry
#   - why_authoritative must be ≥ 3 lines

set -uo pipefail

REG="${1:-}"
[[ -z "$REG" ]] && { echo "validate-compliance-urls: usage: <path>" >&2; exit 2; }
[[ ! -f "$REG" ]] && { echo "validate-compliance-urls: file not found: $REG" >&2; exit 2; }

REG="$REG" node -e '
  const fs = require("fs");
  const content = fs.readFileSync(process.env.REG, "utf8");
  const errs = [];
  const requiredOp = ["id", "name", "url", "authoritative_publisher",
    "jurisdiction", "applicable_to", "identifier_scheme",
    "why_authoritative", "fetch_frequency", "legal_review_required",
    "paywalled", "document_url", "attribution_note"];
  const jurisdictionEnum = ["US Federal", "EU", "ISO", "OTHER", "CA", "UK", "AU", "JP", "Global"];

  // Regex-based per-entry extraction (block on `^- id:` boundaries).
  const blocks = content.split(/^- id:/m).slice(1);
  const ids = {};
  blocks.forEach((blk, idx) => {
    const idMatch = blk.match(/^\s*([a-zA-Z0-9_-]+)/);
    const eid = idMatch ? idMatch[1] : `(#${idx})`;
    if (idMatch && ids[idMatch[1]] !== undefined) {
      errs.push(`id "${idMatch[1]}": duplicate (also at entry #${ids[idMatch[1]]})`);
    } else if (idMatch) {
      ids[idMatch[1]] = idx;
    }

    // Required fields: paywalled-conditional fields handled below.
    const isPaywalled = /^\s*paywalled:\s*true/m.test(blk);
    for (const k of requiredOp) {
      if (k === "id") continue;
      if (!new RegExp(`^\\s*${k}:`, "m").test(blk)) {
        if ((k === "document_url" || k === "attribution_note") && !isPaywalled) continue;
        errs.push(`id "${eid}": ${k} required`);
      }
    }
    // Paywalled-true must include document_url + attribution_note.
    if (isPaywalled) {
      if (!/^\s*document_url:/m.test(blk)) errs.push(`id "${eid}": paywalled entry missing document_url`);
      if (!/^\s*attribution_note:/m.test(blk)) errs.push(`id "${eid}": paywalled entry missing attribution_note`);
    }

    const j = (blk.match(/^\s*jurisdiction:\s*"?([^"\n]+?)"?\s*$/m) || [])[1];
    if (j && !jurisdictionEnum.includes(j)) errs.push(`id "${eid}": jurisdiction "${j}" not in known set`);

    const lr = (blk.match(/^\s*legal_review_required:\s*(\S+)/m) || [])[1];
    if (lr && lr !== "true" && lr !== "false") errs.push(`id "${eid}": legal_review_required must be boolean (got ${lr})`);
    const pw = (blk.match(/^\s*paywalled:\s*(\S+)/m) || [])[1];
    if (pw && pw !== "true" && pw !== "false") errs.push(`id "${eid}": paywalled must be boolean (got ${pw})`);

    // why_authoritative line count: a literal block (key: |) OR a single string.
    const whyMatch = blk.match(/^\s*why_authoritative:\s*(\|[+\-]?)?\s*\n((?:\s{4,}.*\n)+)/m);
    if (whyMatch) {
      const lines = whyMatch[2].trim().split("\n").filter(Boolean);
      if (lines.length < 3) errs.push(`id "${eid}": why_authoritative must be ≥ 3 lines (got ${lines.length})`);
    } else {
      // Single-string form like why_authoritative: "single line"
      const singleMatch = blk.match(/^\s*why_authoritative:\s*"([^"]*)"/m);
      if (singleMatch) {
        errs.push(`id "${eid}": why_authoritative must be ≥ 3 lines (got single-line scalar)`);
      }
    }
  });

  if (errs.length === 0) process.exit(0);
  errs.forEach(e => process.stderr.write(e + "\n"));
  process.exit(2);
'
