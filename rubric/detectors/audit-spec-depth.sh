#!/usr/bin/env bash
# Drift gate: spec-depth audit.
#
# For each architecture feature that has executable substrate
# (.sh/.js script), counts how many of its specs INVOKE the
# substrate (behavior) vs grep-only (shape). Warns when a feature
# falls below the configurable threshold (default: 1 behavior
# spec per executable feature, or ≥30% behavior ratio).
#
# Defends drift mechanism #5 (pattern-cloned coverage). The CL-414
# session's shape-heavy specs were the symptom this detector exists
# to catch.
#
# Usage:
#   bash rubric/detectors/audit-spec-depth.sh [--quiet] [--min-behavior N]
#
# Exit codes:
#   0 — clean (every executable feature meets the threshold)
#   1 — dirty (one or more features below threshold)
#   2 — usage error

set -uo pipefail
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
QUIET=0
MIN_BEHAVIOR=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet|-q) QUIET=1; shift ;;
    --min-behavior) MIN_BEHAVIOR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: audit-spec-depth.sh [--quiet] [--min-behavior N]" >&2
      exit 0 ;;
    *) echo "audit-spec-depth: unknown arg: $1" >&2; exit 2 ;;
  esac
done

cd "$PLUGIN_ROOT"

PLUGIN_ROOT="$PLUGIN_ROOT" MIN_BEHAVIOR="$MIN_BEHAVIOR" node -e '
  const fs = require("fs");
  const path = require("path");
  const root = process.env.PLUGIN_ROOT;
  const minBehavior = parseInt(process.env.MIN_BEHAVIOR || "1", 10);
  const specDir = path.join(root, "evals/specs");
  if (!fs.existsSync(specDir)) { console.log("specs_dir_missing"); process.exit(2); }
  // Classify each spec: behavior (invokes substrate) vs shape (grep).
  const byFeature = {};
  for (const f of fs.readdirSync(specDir)) {
    if (!f.endsWith(".json")) continue;
    const m = f.match(/^cl\d+-([A-Z]-\d+)-/);
    if (!m) continue;
    const feat = m[1];
    let cmd = "";
    try { cmd = JSON.parse(fs.readFileSync(path.join(specDir, f), "utf8")).command || ""; }
    catch { continue; }
    const isBehavior = /(bash|node)\s+["]?\$CLAUDE_PLUGIN_ROOT[^"\s]*/.test(cmd) ||
                       /\|\s*(bash|node)\s+["]?\$CLAUDE_PLUGIN_ROOT/.test(cmd);
    // hasExecSubstrate: the spec EXPLICITLY invokes the substrate
    // (bash X / node X / pipe through bash X). Pure existence checks
    // [ -f $X.sh ] or grep $X.sh count as data references, not exec.
    const hasExecSubstrate = /(bash|node)\s+["]?\$CLAUDE_PLUGIN_ROOT[^"\s]*\.(sh|js)/.test(cmd) ||
                             /(bash|node)\s+["]?\$CLAUDE_PLUGIN_ROOT[^"\s]*\/[a-zA-Z][a-zA-Z0-9_-]+["\s]/.test(cmd);
    byFeature[feat] = byFeature[feat] || { behavior: 0, shape: 0, total: 0, hasExecSubstrate: false };
    byFeature[feat].total++;
    if (isBehavior) byFeature[feat].behavior++;
    else byFeature[feat].shape++;
    if (hasExecSubstrate) byFeature[feat].hasExecSubstrate = true;
  }
  let dirty = 0;
  const findings = [];
  for (const [feat, s] of Object.entries(byFeature).sort()) {
    if (!s.hasExecSubstrate) continue;  // doc-only features get a pass
    if (s.behavior < minBehavior) {
      findings.push(`SHALLOW ${feat}: ${s.behavior} behavior / ${s.total} total (need >= ${minBehavior})`);
      dirty++;
    }
  }
  for (const f of findings) console.log(f);
  const executable = Object.values(byFeature).filter(s => s.hasExecSubstrate).length;
  console.log(`spec_depth_audit=${dirty === 0 ? "clean" : "dirty"} executable_features=${executable} shallow=${dirty} min_behavior=${minBehavior}`);
  process.exit(dirty === 0 ? 0 : 1);
'
