#!/usr/bin/env bash
# R-10 component-API drift detector per §26 v1.11.
#
# Walks a before/after pair of source trees, identifies exported React
# components whose public API surface (prop names / prop types) changed
# between the two snapshots, and emits "potentially-breaking-for-consumers"
# findings with a suggested migration entry.
#
# Component detection: any .tsx/.ts file declaring
#   export type <Name>Props = { ... };
# or
#   export interface <Name>Props { ... }
# is treated as an exported component with the prop type as its public API.
#
# Findings:
#   - prop_removed:    a prop in before is missing in after
#   - prop_added:      a prop in after was not in before
#   - prop_type_changed: same prop name, different type
#
# Usage:
#   component-api-drift.sh --before <dir> --after <dir> [--emit <jsonl>]
#                          [--ignore-file <path>]
set -uo pipefail

BEFORE=""
AFTER=""
EMIT=""
IGNORE_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --before) BEFORE="$2"; shift 2 ;;
    --after) AFTER="$2"; shift 2 ;;
    --emit) EMIT="$2"; shift 2 ;;
    --ignore-file) IGNORE_FILE="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: component-api-drift.sh --before <dir> --after <dir> [--emit <jsonl>] [--ignore-file <path>]" >&2
      exit 0
      ;;
    *) echo "component-api-drift: unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$BEFORE" ]] && { echo "component-api-drift: --before required" >&2; exit 2; }
[[ -z "$AFTER" ]] && { echo "component-api-drift: --after required" >&2; exit 2; }
[[ ! -d "$BEFORE" ]] && { echo "component-api-drift: before dir not found: $BEFORE" >&2; exit 2; }
[[ ! -d "$AFTER" ]] && { echo "component-api-drift: after dir not found: $AFTER" >&2; exit 2; }

BEFORE="$BEFORE" AFTER="$AFTER" EMIT="$EMIT" IGNORE_FILE="$IGNORE_FILE" node -e '
  const fs = require("fs");
  const path = require("path");
  const before = process.env.BEFORE;
  const after = process.env.AFTER;
  const emitPath = process.env.EMIT;
  const ignoreFile = process.env.IGNORE_FILE;

  const ignored = new Set();
  if (ignoreFile && fs.existsSync(ignoreFile)) {
    fs.readFileSync(ignoreFile, "utf8").split("\n").forEach(l => {
      l = l.trim();
      if (l && !l.startsWith("#")) ignored.add(l);
    });
  }

  function walk(d) {
    const out = [];
    for (const e of fs.readdirSync(d)) {
      const p = path.join(d, e);
      const st = fs.statSync(p);
      if (st.isDirectory()) {
        if (e === "node_modules" || e === ".git" || e === "dist" || e === "build") continue;
        out.push(...walk(p));
      } else if (/\.(tsx?|jsx?)$/.test(e)) {
        out.push(p);
      }
    }
    return out;
  }

  function extractProps(content) {
    const result = {};
    const typeRe = /export\s+(?:type|interface)\s+([A-Z][A-Za-z0-9]+)Props\s*[=]?\s*{([^}]*)}/g;
    let m;
    while ((m = typeRe.exec(content)) !== null) {
      const compName = m[1];
      const body = m[2];
      const props = {};
      // Split body on ; and newline; parse each segment as name?: type.
      for (const seg of body.split(/[;\n]/)) {
        const t = seg.trim();
        if (!t) continue;
        const pm = t.match(/^(\w+)\??\s*:\s*(.+)$/);
        if (pm) props[pm[1]] = pm[2].trim();
      }
      result[compName] = props;
    }
    return result;
  }

  const findings = [];
  const beforeFiles = new Map();
  for (const f of walk(before)) {
    const rel = path.relative(before, f);
    beforeFiles.set(rel, extractProps(fs.readFileSync(f, "utf8")));
  }
  for (const f of walk(after)) {
    const rel = path.relative(after, f);
    const afterProps = extractProps(fs.readFileSync(f, "utf8"));
    const beforeProps = beforeFiles.get(rel) || {};
    for (const compName of Object.keys(afterProps)) {
      if (ignored.has(compName)) continue;
      const a = afterProps[compName];
      const b = beforeProps[compName] || {};
      for (const p of Object.keys(b)) {
        if (!(p in a)) {
          findings.push({ file: rel, component: compName, kind: "prop_removed", prop: p, before_type: b[p] });
        } else if (b[p] !== a[p]) {
          findings.push({ file: rel, component: compName, kind: "prop_type_changed", prop: p, before_type: b[p], after_type: a[p] });
        }
      }
      for (const p of Object.keys(a)) {
        if (!(p in b) && Object.keys(b).length > 0) {
          findings.push({ file: rel, component: compName, kind: "prop_added", prop: p, after_type: a[p] });
        }
      }
    }
  }

  if (emitPath) {
    fs.mkdirSync(path.dirname(emitPath) || ".", { recursive: true });
    fs.writeFileSync(emitPath, findings.map(f => JSON.stringify(f)).join("\n") + (findings.length ? "\n" : ""));
  }

  for (const f of findings) {
    process.stderr.write(`component-api-drift: ${f.file} component=${f.component} kind=${f.kind} prop=${f.prop}\n`);
  }
  if (findings.length === 0) {
    process.stderr.write(`component-api-drift: clean (no component-API drift between ${before} and ${after})\n`);
    process.exit(0);
  }
  process.stderr.write(`component-api-drift: ${findings.length} drift finding(s) (severity=warn; consumer migration may be required)\n`);
  process.exit(0);
'
