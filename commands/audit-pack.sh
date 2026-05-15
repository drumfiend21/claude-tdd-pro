#!/usr/bin/env bash
# /audit-pack — emits a Markdown audit pack assembling per-commit
# provenance records under .claude-tdd-pro/provenance/. Sections:
#   --section badges            top-line freshness/coverage badges
#   --section standards-freshness   per-source freshness across commits
#
# Usage:
#   audit-pack.sh --emit <path> --section <name>

set -uo pipefail

EMIT=""
SECTION=""
CONTROLS_FILE=""
AIBOM_FILE=""
NOW_ISO=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --emit) EMIT="$2"; shift 2 ;;
    --section) SECTION="$2"; shift 2 ;;
    --controls-file) CONTROLS_FILE="$2"; shift 2 ;;
    --aibom|--include-aibom) AIBOM_FILE="$2"; SECTION="${SECTION:-aibom}"; shift 2 ;;
    --now) NOW_ISO="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) echo "Usage: audit-pack.sh --emit <path> --section <name> [--dry-run]"; exit 0 ;;
    *) echo "audit-pack: unknown flag: $1" >&2; exit 2 ;;
  esac
done
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "audit-pack: dry-run; would emit section=${SECTION:-(default)} to ${EMIT:-(default)} (no writes)" >&2
  exit 0
fi
[[ -z "$EMIT" || -z "$SECTION" ]] && { echo "audit-pack: --emit and --section required" >&2; exit 2; }

EMIT="$EMIT" SECTION="$SECTION" CONTROLS_FILE="$CONTROLS_FILE" AIBOM_FILE="$AIBOM_FILE" NOW_ISO="$NOW_ISO" node -e '
  const fs = require("fs");
  const path = require("path");
  const provDir = ".claude-tdd-pro/provenance";
  const records = [];
  if (fs.existsSync(provDir)) {
    for (const f of fs.readdirSync(provDir)) {
      if (!f.endsWith(".json")) continue;
      try { records.push(JSON.parse(fs.readFileSync(path.join(provDir, f), "utf8"))); } catch {}
    }
  }
  const lines = [];
  if (process.env.SECTION === "badges") {
    let allFresh = true;
    for (const r of records) {
      const st = r.standards_state || {};
      for (const id of Object.keys(st)) {
        if (st[id].freshness_at_generation !== "fresh-within-fetch-frequency") allFresh = false;
      }
    }
    lines.push("# Audit Pack Badges");
    lines.push("");
    lines.push(`- Standards: ${allFresh ? "all-fresh" : "mixed-freshness"}`);
  } else if (process.env.SECTION === "standards-freshness") {
    lines.push("# Standards Freshness");
    lines.push("");
    const aggregated = {};
    for (const r of records) {
      const st = r.standards_state || {};
      for (const id of Object.keys(st)) {
        aggregated[id] = aggregated[id] || [];
        aggregated[id].push({ commit: r.commit, status: st[id].freshness_at_generation });
      }
    }
    for (const id of Object.keys(aggregated).sort()) {
      lines.push(`## ${id}`);
      for (const r of aggregated[id]) {
        lines.push(`- commit ${r.commit}: ${r.status}`);
      }
      lines.push("");
    }
  } else if (process.env.SECTION === "legal-review-status") {
    lines.push("# Pending legal review");
    lines.push("");
    const cf = process.env.CONTROLS_FILE;
    if (cf && fs.existsSync(cf)) {
      const content = fs.readFileSync(cf, "utf8");
      const blocks = content.split(/^- /m).slice(1);
      for (const blk of blocks) {
        const fwMatch = blk.match(/framework:\s*([\w-]+)/);
        const cidMatch = blk.match(/control_id:\s*([\w.-]+)/);
        const stMatch = blk.match(/legal_review_status:\s*(\S+)/);
        if (stMatch && stMatch[1] === "pending" && fwMatch && cidMatch) {
          lines.push(`- ${fwMatch[1]} ${cidMatch[1]}: pending`);
        }
      }
    }
  } else if (process.env.SECTION === "attestations") {
    lines.push("# Attestations");
    lines.push("");
    const dir = "compliance/attestations";
    const nowDate = (process.env.NOW_ISO || new Date().toISOString()).slice(0, 10);
    if (fs.existsSync(dir)) {
      for (const f of fs.readdirSync(dir).sort()) {
        if (!f.endsWith(".yaml")) continue;
        const content = fs.readFileSync(path.join(dir, f), "utf8");
        const fwMatch = content.match(/framework:\s*(\S+)/);
        const expMatch = content.match(/license_expiry:\s*(\S+)/);
        if (fwMatch && expMatch) {
          const status = expMatch[1] < nowDate ? "expired" : "active";
          lines.push(`- ${fwMatch[1]}: ${status} (expires ${expMatch[1]})`);
        }
      }
    }
  } else if (process.env.SECTION === "aibom") {
    lines.push("# AIBOM");
    lines.push("");
    const af = process.env.AIBOM_FILE;
    if (af && fs.existsSync(af)) {
      lines.push("```json");
      lines.push(fs.readFileSync(af, "utf8"));
      lines.push("```");
    }
  } else {
    process.stderr.write(`audit-pack: unknown section "${process.env.SECTION}"\n`);
    process.exit(2);
  }
  fs.writeFileSync(process.env.EMIT, lines.join("\n"));
'
