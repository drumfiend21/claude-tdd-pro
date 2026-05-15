#!/usr/bin/env bash
# standards/build-coverage-matrix.sh — S-3 coverage matrix generator
# per §16: "Coverage matrix -> standards/coverage-matrix.json + COVERAGE.md."
#
# Walks a source-folder tree, aggregates per-rule provenance citations,
# emits JSON (--emit) and/or Markdown (--emit-md) summaries:
#   {
#     "sources": {
#       "<source-id>": {
#         "rule_count": N, "recommended_count": N,
#         "rule_ids": [...], "section_ids": [...]
#       }
#     }
#   }
#
# With --catalog <path>:
#   --flag-orphan-rules  exits 1 if any rule cites a source not in the
#                        catalog (lists rule_id + offending source_id)
#   --flag-uncovered     exits 1 if any catalog source has zero citing
#                        rules (lists source_id with "zero rules")
#
# Usage:
#   build-coverage-matrix.sh --tree <dir>
#                            [--emit <path>] [--emit-md <path>]
#                            [--catalog <path>]
#                            [--flag-orphan-rules] [--flag-uncovered]

set -uo pipefail

TREE=""
EMIT_JSON=""
EMIT_MD=""
CATALOG=""
FLAG_ORPHANS=0
FLAG_UNCOVERED=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tree) TREE="$2"; shift 2 ;;
    --emit) EMIT_JSON="$2"; shift 2 ;;
    --emit-md) EMIT_MD="$2"; shift 2 ;;
    --catalog) CATALOG="$2"; shift 2 ;;
    --flag-orphan-rules) FLAG_ORPHANS=1; shift ;;
    --flag-uncovered) FLAG_UNCOVERED=1; shift ;;
    *) echo "build-coverage-matrix: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$TREE" ]] && { echo "build-coverage-matrix: --tree <dir> required" >&2; exit 2; }
[[ ! -d "$TREE" ]] && { echo "build-coverage-matrix: tree not found: $TREE" >&2; exit 2; }

TREE="$TREE" EMIT_JSON="$EMIT_JSON" EMIT_MD="$EMIT_MD" CATALOG="$CATALOG" \
FLAG_ORPHANS="$FLAG_ORPHANS" FLAG_UNCOVERED="$FLAG_UNCOVERED" node -e '
  const fs = require("fs");
  const path = require("path");
  const tree = process.env.TREE;
  const emitJson = process.env.EMIT_JSON;
  const emitMd = process.env.EMIT_MD;
  const catalogPath = process.env.CATALOG;
  const flagOrphans = process.env.FLAG_ORPHANS === "1";
  const flagUncovered = process.env.FLAG_UNCOVERED === "1";

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

  const files = walk(tree);

  // Regex extraction (avoids Psych failure on flow-style + bare URLs).
  const sources = {}; // sourceId -> { rule_count, recommended_count, rule_ids:Set, section_ids:Set, source_files:Set }
  const orphans = []; // {rule_id, source_id, file}

  for (const f of files) {
    const content = fs.readFileSync(f, "utf8");
    const rel = f.slice(tree.length).replace(/^\//, "");
    // Extract per-rule blocks via the rules:[] tail then per-rule "id: X"
    // markers and per-rule provenance citations.
    const rulesIdx = content.indexOf("\nrules:");
    if (rulesIdx < 0) continue;
    const rulesTail = content.slice(rulesIdx);
    const recommendedMatch = content.match(/^recommended_set:\s*\[(.*?)\]/m);
    const recommendedSet = new Set(
      (recommendedMatch ? recommendedMatch[1] : "")
        .split(",").map(s => s.trim().replace(/^"|"$/g, "")).filter(s => s.length > 0)
    );

    // Match each rule entry (flow-style "{...}" or block-style "- id: X\n  ...\n  provenance: [...]").
    const ruleRe = /(?:-\s*\{([^{}]*(?:\{[^}]*\}[^{}]*)*)\}|-\s*id:\s*([a-zA-Z0-9_/-]+)([\s\S]*?)(?=^\s*-\s+id:|^[a-z_]+:|\Z))/gm;
    let m;
    while ((m = ruleRe.exec(rulesTail)) !== null) {
      let body, ruleId;
      if (m[1] !== undefined) {
        body = m[1];
        const idMatch = body.match(/\bid:\s*([a-zA-Z0-9_/-]+)/);
        ruleId = idMatch ? idMatch[1] : null;
      } else {
        ruleId = m[2];
        body = m[3];
      }
      if (!ruleId) continue;

      // Provenance entries: each `{source: X, ..., section_id: "Y"}`.
      const provRe = /\{[^{}]*?\bsource:\s*([a-zA-Z0-9_-]+)[^{}]*?\bsection_id:\s*"?([^,"}]+)"?[^{}]*?\}/g;
      let p;
      while ((p = provRe.exec(body)) !== null) {
        const srcId = p[1];
        const secId = p[2].trim();
        if (!sources[srcId]) sources[srcId] = { rule_count: 0, recommended_count: 0, rule_ids: new Set(), section_ids: new Set(), source_files: new Set() };
        if (!sources[srcId].rule_ids.has(ruleId)) {
          sources[srcId].rule_ids.add(ruleId);
          sources[srcId].rule_count += 1;
          if (recommendedSet.has(ruleId)) sources[srcId].recommended_count += 1;
        }
        sources[srcId].section_ids.add(secId);
        sources[srcId].source_files.add(rel);
      }
    }
  }

  // Catalog-driven checks.
  let catalogIds = [];
  if (catalogPath && fs.existsSync(catalogPath)) {
    const content = fs.readFileSync(catalogPath, "utf8");
    const idRe = /^- id:\s*([a-zA-Z0-9_-]+)/gm;
    let m;
    while ((m = idRe.exec(content)) !== null) catalogIds.push(m[1]);
  }

  if (flagOrphans) {
    const errors = [];
    for (const srcId of Object.keys(sources)) {
      if (!catalogIds.includes(srcId)) {
        for (const rid of sources[srcId].rule_ids) {
          errors.push(`coverage-matrix: rule "${rid}" cites unknown source "${srcId}" (not in catalog)`);
        }
      }
    }
    if (errors.length > 0) {
      errors.forEach(e => process.stderr.write(e + "\n"));
      process.exit(1);
    }
  }

  if (flagUncovered) {
    const uncovered = catalogIds.filter(id => !sources[id]);
    if (uncovered.length > 0) {
      uncovered.forEach(id => process.stderr.write(`coverage-matrix: source "${id}" has zero rules citing it (zero rules)\n`));
      process.exit(1);
    }
  }

  // Build serializable matrix (sorted keys for determinism).
  const matrix = { sources: {} };
  for (const srcId of Object.keys(sources).sort()) {
    const s = sources[srcId];
    matrix.sources[srcId] = {
      rule_count: s.rule_count,
      recommended_count: s.recommended_count,
      rule_ids: Array.from(s.rule_ids).sort(),
      section_ids: Array.from(s.section_ids).sort(),
      source_files: Array.from(s.source_files).sort()
    };
  }

  if (emitJson) {
    fs.writeFileSync(emitJson, JSON.stringify(matrix, null, 2));
  }

  if (emitMd) {
    const totalSources = Object.keys(matrix.sources).length;
    const totalRules = Object.values(matrix.sources).reduce((a, s) => a + s.rule_count, 0);
    const totalRecommended = Object.values(matrix.sources).reduce((a, s) => a + s.recommended_count, 0);
    const lines = ["# Coverage Matrix", ""];
    lines.push("- sources: " + totalSources);
    lines.push("- rules: " + totalRules);
    lines.push("- recommended: " + totalRecommended);
    lines.push("- uncovered_sources: " + Math.max(0, catalogIds.length - totalSources));
    lines.push("");
    for (const srcId of Object.keys(matrix.sources).sort()) {
      const s = matrix.sources[srcId];
      lines.push("## " + srcId);
      lines.push("");
      // Per §17 G-1 source-folder convention, files live under the project-
      // relative path generated-code-quality-standards/<rel>.
      for (const sf of s.source_files) {
        lines.push("- file: [generated-code-quality-standards/" + sf + "](generated-code-quality-standards/" + sf + ")");
      }
      lines.push("- " + srcId + ": rules: " + s.rule_count + ", recommended: " + s.recommended_count + ", sections: [" + s.section_ids.join(", ") + "]");
      lines.push("");
    }
    fs.writeFileSync(emitMd, lines.join("\n"));
  }
'
