#!/usr/bin/env bash
# rubric/detectors/rubric-provenance.sh — S-6 provenance enforcement
# detector per §16: "every rule has >=1 entry; tier matches severity;
# <=90 days fresh."
#
# Walks --tree, validates each rule's provenance[]:
#   - >=1 entry per rule
#   - section_id required, non-empty
#   - class in {published-standard, pr-corpus, community-plugin,
#     regulator-doc, internal-policy}
#   - url must start with https://
#   - content_hash must start with sha256:
#   - --check-tier-matches-severity: P0 rules require >=1 entry with
#     class=published-standard (tier-1)
#   - --max-age-days N --now <iso>: rejects entries older than N days
#   - --check-catalog <path>: provenance.source must appear in catalog
#
# Usage:
#   rubric-provenance.sh --tree <dir> [--format json] [--max-age-days N]
#                         [--now <iso>] [--check-tier-matches-severity]
#                         [--check-catalog <yaml>]
#
# Exit codes (per §2.2):
#   0 — all rules pass
#   1 — freshness failure (stale provenance)
#   2 — structural failure (other validation errors)

set -uo pipefail

TREE=""
FORMAT="text"
MAX_AGE_DAYS=0
NOW_ISO=""
CHECK_TIER=0
CHECK_CATALOG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tree) TREE="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --max-age-days) MAX_AGE_DAYS="$2"; shift 2 ;;
    --now) NOW_ISO="$2"; shift 2 ;;
    --check-tier-matches-severity) CHECK_TIER=1; shift ;;
    --check-catalog) CHECK_CATALOG="$2"; shift 2 ;;
    *) echo "rubric-provenance: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$TREE" ]] && { echo "rubric-provenance: --tree <dir> required" >&2; exit 2; }
[[ ! -d "$TREE" ]] && { echo "rubric-provenance: tree not found: $TREE" >&2; exit 2; }

TREE="$TREE" FORMAT="$FORMAT" MAX_AGE_DAYS="$MAX_AGE_DAYS" NOW_ISO="$NOW_ISO" \
CHECK_TIER="$CHECK_TIER" CHECK_CATALOG="$CHECK_CATALOG" node -e '
  const fs = require("fs");
  const path = require("path");
  const tree = process.env.TREE;
  const format = process.env.FORMAT;
  const maxAgeDays = parseInt(process.env.MAX_AGE_DAYS || "0", 10);
  const nowIso = process.env.NOW_ISO;
  const checkTier = process.env.CHECK_TIER === "1";
  const catalogPath = process.env.CHECK_CATALOG;

  const ALLOWED_CLASSES = new Set(["published-standard", "pr-corpus", "community-plugin", "regulator-doc", "internal-policy"]);

  let catalogIds = null;
  if (catalogPath && fs.existsSync(catalogPath)) {
    catalogIds = new Set();
    const c = fs.readFileSync(catalogPath, "utf8");
    const re = /^- id:\s*([a-zA-Z0-9_-]+)/gm;
    let m; while ((m = re.exec(c)) !== null) catalogIds.add(m[1]);
  }

  function walk(d) {
    const out = [];
    for (const e of fs.readdirSync(d).sort()) {
      const p = path.join(d, e);
      if (e === "_meta" || e === "_archived") continue;
      const st = fs.statSync(p);
      if (st.isDirectory()) out.push(...walk(p));
      else if (e.endsWith(".yaml")) out.push(p);
    }
    return out;
  }

  const errors = [];
  const stale = [];
  let checked = 0, passed = 0, failed = 0;

  for (const f of walk(tree)) {
    const fileContent = fs.readFileSync(f, "utf8");
    // Restrict rule extraction to the rules block so source.id
    // is not mis-matched as a rule id.
    const rulesIdx = fileContent.indexOf("\nrules:");
    if (rulesIdx < 0) continue;
    const c = fileContent.slice(rulesIdx);
    const ruleRe = /\bid:\s*([a-zA-Z0-9_/-]+)[\s\S]*?\bseverity:\s*(P[0-9])[\s\S]*?\bprovenance:\s*\[([\s\S]*?)\](?=\s*\}|\s*\n[a-z_]|\s*\n\s*-\s*\{|\s*\n\s*-\s+id:|\s*\Z)/g;
    let m;
    while ((m = ruleRe.exec(c)) !== null) {
      checked += 1;
      const ruleId = m[1];
      const severity = m[2];
      const provBody = m[3].trim();
      let ruleFailed = false;

      if (provBody.length === 0) {
        errors.push(`rule ${ruleId}: provenance is empty (>=1 entry required)`);
        ruleFailed = true;
      } else {
        // Split provenance entries by top-level "}" ... "{" boundaries.
        const entryRe = /\{([^{}]*)\}/g;
        const entries = [];
        let em; while ((em = entryRe.exec(provBody)) !== null) entries.push(em[1]);

        let hasTier1 = false;
        for (const entry of entries) {
          const get = (k) => {
            const re = new RegExp("\\b" + k + ":\\s*\"?([^,\"}]+?)\"?(?:\\s*,|\\s*$)");
            const r = entry.match(re);
            return r ? r[1].trim() : null;
          };
          const cls = get("class");
          const sectionId = get("section_id");
          const url = get("url");
          const contentHash = get("content_hash");
          const fetchedAt = get("fetched_at");
          const source = get("source");

          if (!sectionId || sectionId === "" || sectionId === "\"\"") {
            errors.push(`rule ${ruleId}: provenance.section_id required (non-empty)`);
            ruleFailed = true;
          }
          if (cls && !ALLOWED_CLASSES.has(cls)) {
            errors.push(`rule ${ruleId}: provenance.class "${cls}" not in enum {${[...ALLOWED_CLASSES].join(", ")}}`);
            ruleFailed = true;
          }
          if (url && !url.startsWith("https://")) {
            errors.push(`rule ${ruleId}: provenance.url must start with https:// (got ${url})`);
            ruleFailed = true;
          }
          if (contentHash && !contentHash.startsWith("sha256:")) {
            errors.push(`rule ${ruleId}: provenance.content_hash must start with sha256: (got ${contentHash})`);
            ruleFailed = true;
          }
          if (catalogIds && source && !catalogIds.has(source)) {
            errors.push(`rule ${ruleId}: provenance.source "${source}" not present in --check-catalog`);
            ruleFailed = true;
          }
          if (cls === "published-standard") hasTier1 = true;

          if (maxAgeDays > 0 && nowIso && fetchedAt) {
            const ageMs = new Date(nowIso).getTime() - new Date(fetchedAt).getTime();
            const ageDays = ageMs / 86400000;
            if (ageDays > maxAgeDays) {
              stale.push(`rule ${ruleId}: provenance.fetched_at ${fetchedAt} is stale (${Math.round(ageDays)} days, limit ${maxAgeDays})`);
            }
          }
        }
        if (checkTier && severity === "P0" && !hasTier1) {
          errors.push(`rule ${ruleId}: P0 severity requires >=1 tier-1 (class=published-standard) provenance entry`);
          ruleFailed = true;
        }
      }

      if (ruleFailed) failed += 1;
      else passed += 1;
    }
  }

  if (format === "json") {
    process.stderr.write(JSON.stringify({ checked, passed, failed }));
  }

  for (const e of errors) process.stderr.write(e + "\n");
  for (const s of stale) process.stderr.write(s + "\n");

  if (errors.length > 0) process.exit(2);
  if (stale.length > 0) process.exit(1);
  process.exit(0);
'
