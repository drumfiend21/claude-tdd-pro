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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --emit) EMIT="$2"; shift 2 ;;
    --section) SECTION="$2"; shift 2 ;;
    *) echo "audit-pack: unknown flag: $1" >&2; exit 2 ;;
  esac
done
[[ -z "$EMIT" || -z "$SECTION" ]] && { echo "audit-pack: --emit and --section required" >&2; exit 2; }

EMIT="$EMIT" SECTION="$SECTION" node -e '
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
  } else {
    process.stderr.write(`audit-pack: unknown section "${process.env.SECTION}"\n`);
    process.exit(2);
  }
  fs.writeFileSync(process.env.EMIT, lines.join("\n"));
'
