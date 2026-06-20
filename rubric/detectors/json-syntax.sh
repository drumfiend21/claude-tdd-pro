#!/usr/bin/env bash
# rubric/detectors/json-syntax.sh - Layer-1 JSON well-formedness detector (ADR-0007 /
# §28.24, CTP-D-4). Rule-id-driven like cloud-guidance-rule.sh so enforce.sh dispatches
# it via --rule/--root. Dependency-free (uses node's JSON.parse); grounds in RFC 8259.
# If node is absent the detector reports not_enforced (exit 3) rather than a vacuous green.
#
# Rules:
#   g-json-well-formed  - every *.json file must parse as RFC 8259 JSON.
#
# CLI: --rule <id> --root <dir> [--paths <glob>] [--json]
# stderr: per finding `json-syntax file=<f> rule=<id>`; summary `json-syntax rule=<id> status=<green|red> findings=<n>`
# Exit: 0 clean | 1 findings | 3 not_enforced (node absent) | 2 usage.

set -uo pipefail
RULE=""; ROOT="."; PATHS=""; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --rule)  RULE="${2-}";  shift 2 ;;
    --root)  ROOT="${2-}";  shift 2 ;;
    --paths) PATHS="${2-}"; shift 2 ;;
    --json)  JSON=1; shift ;;
    -h|--help) echo "Usage: json-syntax.sh --rule <id> --root <dir> [--paths <glob>] [--json]" >&2; exit 0 ;;
    *) echo "json-syntax: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$RULE" ] && { echo "json-syntax: --rule <id> required" >&2; exit 2; }
[ "$RULE" != "g-json-well-formed" ] && { echo "json-syntax: unknown rule $RULE" >&2; exit 2; }
command -v node >/dev/null 2>&1 || { echo "json-syntax rule=$RULE status=not_enforced reason=node-absent" >&2; exit 3; }

RULE="$RULE" ROOT="$ROOT" PATHS="$PATHS" JSON="$JSON" node -e '
  const fs = require("fs"), path = require("path");
  const rule = process.env.RULE, root = process.env.ROOT, wantJson = process.env.JSON === "1";
  const paths = (process.env.PATHS || "").trim();
  function walk(d, acc) {
    let ents = [];
    try { ents = fs.readdirSync(d, { withFileTypes: true }); } catch (e) { return acc; }
    for (const e of ents) {
      const p = path.join(d, e.name);
      if (e.isDirectory()) { if (e.name !== ".git" && e.name !== "node_modules") walk(p, acc); }
      else if (e.isFile() && e.name.endsWith(".json")) acc.push(p);
    }
    return acc;
  }
  const files = paths ? paths.split(",").map(s => s.trim()).filter(f => { try { return fs.statSync(f).isFile(); } catch (e) { return false; } })
                      : walk(root, []);
  const findings = [];
  for (const f of files) {
    try { JSON.parse(fs.readFileSync(f, "utf8")); }
    catch (e) { findings.push(f); }
  }
  if (wantJson) {
    const sarif = { version: "2.1.0",
      "$schema": "https://docs.oasis-open.org/sarif/sarif/v2.1.0/errata01/os/schemas/sarif-schema-2.1.0.json",
      runs: [{ tool: { driver: { name: "json-syntax", version: "1.0.0", rules: [{ id: rule }] } },
        results: findings.map(f => ({ ruleId: rule, level: "error",
          message: { text: rule + " violation: not well-formed JSON" },
          locations: [{ physicalLocation: { artifactLocation: { uri: f }, region: { startLine: 1 } } }] })) }] };
    process.stdout.write(JSON.stringify(sarif));
  }
  for (const f of findings) process.stderr.write("json-syntax file=" + f + " rule=" + rule + "\n");
  process.stderr.write("json-syntax rule=" + rule + " status=" + (findings.length ? "red" : "green") + " findings=" + findings.length + "\n");
  process.exit(findings.length ? 1 : 0);
'
