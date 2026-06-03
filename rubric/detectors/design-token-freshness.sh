#!/usr/bin/env bash
# O-13 design-token freshness gate per §26 v1.11.
#
# Scans source files for token id references (e.g.,
# `tokens.color.legacy.red`, `var(--color-legacy-red)`, or a literal
# token-id string) and flags references to tokens marked
# `deprecated: true` in design-tokens/registry.yaml. Each finding
# includes the replaced_by successor as a migration hint.
#
# Severity: warn (auto-demote per §2.17 enum; non-blocking unless
# --strict elevates to exit 1).
#
# Usage:
#   design-token-freshness.sh --registry <path> --paths <dir>
#                              [--strict] [--emit <jsonl>]
#                              [--ignore-file <path>]
set -uo pipefail

REGISTRY=""
PATHS=""
STRICT=0
EMIT=""
IGNORE_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --registry) REGISTRY="$2"; shift 2 ;;
    --paths) PATHS="$2"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    --emit) EMIT="$2"; shift 2 ;;
    --ignore-file) IGNORE_FILE="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: design-token-freshness.sh --registry <path> --paths <dir> [--strict] [--emit <jsonl>] [--ignore-file <path>]" >&2
      exit 0
      ;;
    *) echo "design-token-freshness: unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$REGISTRY" ]] && { echo "design-token-freshness: --registry required" >&2; exit 2; }
[[ -z "$PATHS" ]] && { echo "design-token-freshness: --paths required" >&2; exit 2; }
[[ ! -f "$REGISTRY" ]] && { echo "design-token-freshness: registry not found: $REGISTRY" >&2; exit 2; }
[[ ! -d "$PATHS" ]] && { echo "design-token-freshness: paths dir not found: $PATHS" >&2; exit 2; }

REGISTRY="$REGISTRY" PATHS="$PATHS" STRICT="$STRICT" EMIT="$EMIT" IGNORE_FILE="$IGNORE_FILE" node -e '
  const fs = require("fs");
  const path = require("path");
  const registry = fs.readFileSync(process.env.REGISTRY, "utf8");
  const blocks = registry.split(/^  - id: /m).slice(1);
  const deprecated = {};
  for (const b of blocks) {
    const id = b.split("\n")[0].trim();
    const isDep = /^\s*deprecated: true/m.test(b);
    if (!isDep) continue;
    const r = b.match(/^\s*replaced_by: (\S+)/m);
    deprecated[id] = r ? r[1] : null;
  }

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
      } else if (/\.(tsx?|jsx?|css|scss|md)$/.test(e)) {
        out.push(p);
      }
    }
    return out;
  }

  const findings = [];
  for (const f of walk(process.env.PATHS)) {
    const content = fs.readFileSync(f, "utf8");
    const lines = content.split("\n");
    for (const depId of Object.keys(deprecated)) {
      if (ignored.has(depId)) continue;
      const dotForm = depId; // e.g., color.legacy.red
      const varForm = "--" + depId.replace(/\./g, "-"); // --color-legacy-red
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        if (line.includes(dotForm) || line.includes(varForm)) {
          findings.push({
            file: f.slice(process.env.PATHS.length + 1) || path.basename(f),
            line: i + 1,
            deprecated_token: depId,
            replaced_by: deprecated[depId],
            severity: "warn"
          });
        }
      }
    }
  }

  const emit = process.env.EMIT;
  if (emit) {
    fs.mkdirSync(path.dirname(emit) || ".", { recursive: true });
    fs.writeFileSync(emit, findings.map(f => JSON.stringify(f)).join("\n") + (findings.length ? "\n" : ""));
  }

  for (const f of findings) {
    process.stderr.write(`design-token-freshness: ${f.file}:${f.line} token=${f.deprecated_token} replaced_by=${f.replaced_by} severity=${f.severity}\n`);
  }

  if (findings.length === 0) {
    process.stderr.write(`design-token-freshness: clean (no deprecated-token references in ${process.env.PATHS})\n`);
    process.exit(0);
  }
  const strict = process.env.STRICT === "1";
  process.stderr.write(`design-token-freshness: ${findings.length} deprecated-token reference(s) (severity=warn${strict ? "; --strict elevates to exit 1" : ""})\n`);
  process.exit(strict ? 1 : 0);
'
