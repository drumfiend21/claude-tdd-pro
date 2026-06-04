#!/usr/bin/env bash
# Drift gate: substrate-completeness audit.
#
# For every architecture feature ID, verifies that at least one
# substrate path referenced by the feature's specs exists on disk.
# Catches the failure mode where an arch feature ID is documented
# but the implementation file never landed (or got deleted).
#
# Usage:
#   bash rubric/detectors/audit-substrate-completeness.sh [--quiet]
#
# Exit codes:
#   0 — clean (every feature's spec-referenced substrate exists)
#   1 — dirty (one or more features reference missing substrate)
#   2 — usage error

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
QUIET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet|-q) QUIET=1; shift ;;
    -h|--help)
      echo "Usage: audit-substrate-completeness.sh [--quiet]" >&2
      exit 0 ;;
    *) echo "audit-substrate-completeness: unknown arg: $1" >&2; exit 2 ;;
  esac
done

cd "$PLUGIN_ROOT"

# Collect every (feature-id, substrate-path) pair from the spec corpus.
# Use node -e for JSON parsing (bash regex can't handle nested JSON).
PLUGIN_ROOT="$PLUGIN_ROOT" node -e '
  const fs = require("fs");
  const path = require("path");
  const root = process.env.PLUGIN_ROOT;
  const specDir = path.join(root, "evals/specs");
  if (!fs.existsSync(specDir)) { console.log("specs_dir_missing"); process.exit(2); }
  const byFeature = {};
  for (const f of fs.readdirSync(specDir)) {
    if (!f.endsWith(".json")) continue;
    const m = f.match(/^cl\d+-([A-Z]-\d+)-/);
    if (!m) continue;
    const feat = m[1];
    let cmd = "";
    try {
      cmd = JSON.parse(fs.readFileSync(path.join(specDir, f), "utf8")).command || "";
    } catch { continue; }
    // Extract substrate paths from the command (anything under $CLAUDE_PLUGIN_ROOT/)
    const re = /\$CLAUDE_PLUGIN_ROOT\/([a-zA-Z0-9_./*-]+)/g;
    let m2;
    while ((m2 = re.exec(cmd)) !== null) {
      const p = m2[1].replace(/[*?[\]]+.*$/, "").replace(/\/+$/, "");
      if (p.length === 0) continue;
      if (!byFeature[feat]) byFeature[feat] = new Set();
      byFeature[feat].add(p);
    }
  }
  // Check each feature: at least one referenced path must exist.
  let dirty = 0;
  const results = [];
  for (const [feat, paths] of Object.entries(byFeature).sort()) {
    let anyExists = false;
    const checked = [];
    for (const p of paths) {
      const full = path.join(root, p);
      if (fs.existsSync(full)) { anyExists = true; break; }
      checked.push(p);
    }
    if (!anyExists) {
      results.push(`MISSING ${feat}: none of [${[...paths].slice(0,3).join(", ")}] exist`);
      dirty++;
    }
  }
  for (const r of results) console.log(r);
  console.log(`substrate_audit=${dirty === 0 ? "clean" : "dirty"} features_audited=${Object.keys(byFeature).length} missing=${dirty}`);
  process.exit(dirty === 0 ? 0 : 1);
'
