#!/usr/bin/env bash
# rubric/sarif-aggregate.sh - the composite-engine SARIF 2.1.0 bus (ADR-0008, §28.28 Wave 1).
#
# Every tool in the composite engine (Semgrep, ESLint, Checkov, ... and CTP's own
# prose-judge.sh / md-structure.sh / json-syntax.sh / yaml-syntax.sh) emits SARIF 2.1.0.
# This script is the normalization point: it reads N SARIF documents, merges their runs into
# one sarifLog, de-duplicates identical results, and computes a single verdict. One normalized
# stream feeds dashboards, GitHub code-scanning, IDEs, and the engine's pass/fail gate.
#
# CLI:
#   --in <file>     a SARIF document to ingest (repeatable)
#   --dir <dir>     ingest every *.sarif / *.sarif.json under <dir>
#   --strict        fail on warning-level results too (audit-time gate); default fails on error only
#   --json          emit the merged SARIF 2.1.0 log to stdout
# stderr: per tool `sarif-aggregate tool=<driver> results=<n>`; summary
#         `sarif-aggregate status=<green|red> tools=<t> error=<e> warning=<w> note=<n>`
# Exit: 0 green (no blocking results) | 1 red (>=1 blocking) | 2 usage (no valid SARIF input).

set -uo pipefail
INS=(); DIR=""; STRICT=0; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --in)     INS+=("${2-}"); shift 2 ;;
    --dir)    DIR="${2-}"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    --json)   JSON=1; shift ;;
    -h|--help) echo "Usage: sarif-aggregate.sh --in <file> [--in <file>...] | --dir <dir> [--strict] [--json]" >&2; exit 0 ;;
    *) echo "sarif-aggregate: unknown arg: $1" >&2; exit 2 ;;
  esac
done

command -v node >/dev/null 2>&1 || { echo "sarif-aggregate: node required" >&2; exit 2; }

INPUTS_CSV="$(IFS=,; echo "${INS[*]:-}")" DIR="$DIR" STRICT="$STRICT" JSON="$JSON" node -e '
  const fs = require("fs"), path = require("path");
  const strict = process.env.STRICT === "1", wantJson = process.env.JSON === "1";
  let files = (process.env.INPUTS_CSV || "").split(",").filter(Boolean);
  const dir = process.env.DIR || "";
  if (dir) {
    const walk = d => { for (const e of (fs.readdirSync(d, {withFileTypes:true}) || [])) {
      const p = path.join(d, e.name);
      if (e.isDirectory()) { if (e.name !== ".git" && e.name !== "node_modules") walk(p); }
      else if (/\.sarif(\.json)?$/.test(e.name)) files.push(p);
    } };
    try { walk(dir); } catch (e) {}
  }
  files = [...new Set(files)];

  const mergedRuns = [];
  const perTool = {};
  let nError = 0, nWarning = 0, nNote = 0, validDocs = 0;
  const seen = new Set();

  for (const f of files) {
    let doc;
    try { doc = JSON.parse(fs.readFileSync(f, "utf8")); } catch (e) { continue; }
    if (!doc || doc.version !== "2.1.0" || !Array.isArray(doc.runs)) continue;  // not SARIF 2.1.0
    validDocs++;
    for (const run of doc.runs) {
      const driver = (run.tool && run.tool.driver && run.tool.driver.name) || "unknown";
      const results = Array.isArray(run.results) ? run.results : [];
      let kept = 0;
      const kr = [];
      for (const r of results) {
        const loc = (r.locations && r.locations[0] && r.locations[0].physicalLocation) || {};
        const uri = (loc.artifactLocation && loc.artifactLocation.uri) || "";
        const line = (loc.region && loc.region.startLine) || 0;
        const key = [driver, r.ruleId || "", r.level || "", uri, line].join("|");
        if (seen.has(key)) continue;       // dedupe identical findings across docs
        seen.add(key);
        kr.push(r); kept++;
        const lvl = r.level || "warning";
        if (lvl === "error") nError++; else if (lvl === "note") nNote++; else nWarning++;
      }
      perTool[driver] = (perTool[driver] || 0) + kept;
      mergedRuns.push({ tool: { driver: { name: driver, version: (run.tool.driver.version || "") } }, results: kr });
    }
  }

  if (validDocs === 0) { process.stderr.write("sarif-aggregate: no valid SARIF 2.1.0 input\n"); process.exit(2); }

  const merged = {
    version: "2.1.0",
    $schema: "https://docs.oasis-open.org/sarif/sarif/v2.1.0/errata01/os/schemas/sarif-schema-2.1.0.json",
    runs: mergedRuns
  };
  if (wantJson) process.stdout.write(JSON.stringify(merged));

  for (const [t, n] of Object.entries(perTool)) process.stderr.write(`sarif-aggregate tool=${t} results=${n}\n`);
  const blocking = nError + (strict ? nWarning : 0);
  const status = blocking > 0 ? "red" : "green";
  process.stderr.write(`sarif-aggregate status=${status} tools=${Object.keys(perTool).length} error=${nError} warning=${nWarning} note=${nNote}\n`);
  process.exit(blocking > 0 ? 1 : 0);
'
