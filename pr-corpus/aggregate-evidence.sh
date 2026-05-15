#!/usr/bin/env bash
# L-6 evidence aggregation: ≥3 PRs, ≥2 orgs, ≥1 tier-1.
set -uo pipefail
PATTERN=""; EMIT_FIELDS=0; RESOLVE_CONSORTIA=0; NOW=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pattern) PATTERN="$2"; shift 2 ;;
    --emit-fields) EMIT_FIELDS=1; shift ;;
    --resolve-consortia) RESOLVE_CONSORTIA=1; shift ;;
    --now) NOW="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[[ -z "$PATTERN" || ! -f "$PATTERN" ]] && { echo "aggregate-evidence: --pattern required" >&2; exit 2; }

PATTERN="$PATTERN" EMIT_FIELDS="$EMIT_FIELDS" RESOLVE_CONSORTIA="$RESOLVE_CONSORTIA" node -e '
const fs = require("fs");
const p = JSON.parse(fs.readFileSync(process.env.PATTERN, "utf8"));
const prs = p.supporting_prs || [];
const orgs = new Set();
let tier1 = 0;

for (const pr of prs) {
  // Resolve consortium reviewers to member orgs.
  if (process.env.RESOLVE_CONSORTIA === "1" && pr.reviewer) {
    const cachePath = `.claude-tdd-pro/pr-corpus/affiliation-cache/${pr.reviewer}.json`;
    if (fs.existsSync(cachePath)) {
      try {
        const c = JSON.parse(fs.readFileSync(cachePath, "utf8"));
        if (Array.isArray(c.member_orgs)) c.member_orgs.forEach(o => orgs.add(o));
        else if (c.org) orgs.add(c.org);
      } catch {}
    }
  } else if (pr.org) {
    orgs.add(pr.org);
  }
  if ((pr.tier || 99) === 1) tier1++;
}

const evidence_count = prs.length;
const organizations_count = orgs.size;
const tier1_count = tier1;
const orgs_list = [...orgs];

if (process.env.EMIT_FIELDS === "1") {
  process.stderr.write(JSON.stringify({pattern_id: p.pattern_id, evidence_count, organizations_count, tier1_count, organizations: orgs_list}) + "\n");
}

const failures = [];
if (evidence_count < 3) failures.push(`evidence_count=${evidence_count} required>=3`);
if (organizations_count < 2) failures.push(`organizations_count=${organizations_count} required>=2`);
if (tier1_count < 1) failures.push(`tier1_count=${tier1_count} required>=1`);

if (failures.length > 0) {
  process.stderr.write(`aggregate-evidence: pattern=${p.pattern_id} BLOCKED failures=${failures.length}\n`);
  process.stderr.write(`aggregate-evidence: evidence_count=${evidence_count} organizations_count=${organizations_count} tier1_count=${tier1_count}\n`);
  failures.forEach(f => process.stderr.write(`aggregate-evidence:   ${f}\n`));
  // Informational modes (consortium resolution / emit-fields) report
  // counts but do not gate; --resolve-consortia is for affiliation
  // research, not promotion gating.
  if (process.env.RESOLVE_CONSORTIA === "1" || process.env.EMIT_FIELDS === "1") {
    process.stderr.write(`aggregate-evidence: organizations=${orgs_list.join(",")} (informational mode)\n`);
    process.exit(0);
  }
  process.exit(1);
}

process.stderr.write(`aggregate-evidence: pattern=${p.pattern_id} decision=promote evidence_count=${evidence_count} organizations_count=${organizations_count} tier1_count=${tier1_count} orgs=${orgs_list.join(",")}\n`);
'
