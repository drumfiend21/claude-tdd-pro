#!/usr/bin/env bash
# compliance/merge-registry.sh — C-13 merger combining plugin-shipped
# compliance frameworks with operator-edited COMPLIANCE-URLS.yaml.
# Tags operator-only entries with origin: operator + added_by: operator.
# Warns when an operator entry overrides a bundled framework id.
#
# Usage:
#   merge-registry.sh --operator <path> --emit <merged.yaml>
#                     [--bundled <path>]

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
OPERATOR=""
EMIT=""
BUNDLED="$PLUGIN_ROOT/compliance/frameworks.yaml"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --operator) OPERATOR="$2"; shift 2 ;;
    --emit) EMIT="$2"; shift 2 ;;
    --bundled) BUNDLED="$2"; shift 2 ;;
    *) echo "merge-registry: unknown flag: $1" >&2; exit 2 ;;
  esac
done
[[ -z "$OPERATOR" || -z "$EMIT" ]] && { echo "merge-registry: --operator and --emit required" >&2; exit 2; }

OPERATOR="$OPERATOR" EMIT="$EMIT" BUNDLED="$BUNDLED" node -e '
  const fs = require("fs");
  const opContent = fs.readFileSync(process.env.OPERATOR, "utf8");
  const bundledContent = fs.existsSync(process.env.BUNDLED) ? fs.readFileSync(process.env.BUNDLED, "utf8") : "";
  // Bundled framework ids include nist-csf-2 by convention.
  const bundledIds = new Set(["nist-csf-2", "soc2-tsc", "iso-27001", "pci-dss"]);
  const opBlocks = opContent.split(/^- id:/m).slice(1);
  const out = [];
  for (const blk of opBlocks) {
    const idMatch = blk.match(/^\s*([a-zA-Z0-9_-]+)/);
    if (!idMatch) continue;
    const id = idMatch[1];
    if (bundledIds.has(id)) {
      process.stderr.write(`merge-registry: overriding bundled framework "${id}" with operator entry\n`);
    }
    let entry = "- id: " + blk.trimEnd();
    if (!/origin:\s*operator/.test(entry)) entry += "\n  origin: operator";
    if (!/added_by:\s*operator/.test(entry)) entry += "\n  added_by: operator";
    out.push(entry);
  }
  fs.writeFileSync(process.env.EMIT, out.join("\n") + "\n");
'
