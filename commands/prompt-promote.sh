#!/usr/bin/env bash
# prompt-promote.sh — P-6 substrate. Promotes a candidate prompt
# version to active status, gated on eval pass rate >= prior active.
#
# Per architecture section 16 P-6: "/prompt-promote <id> <version>
# regression-gated; /prompt-rollback <id> one-command."
#
# Usage:
#   prompt-promote.sh <agent> <version> [--override-regression --reason <text>]
#                      [--dry-run] [--emit-audit <path>]

set -uo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Usage: prompt-promote.sh <agent> <version> [--override-regression --reason <text>] [--dry-run] [--emit-audit <path>]"
  exit 0
fi

AGENT="${1:-}"
VERSION="${2:-}"
shift 2 2>/dev/null || true

OVERRIDE=0
REASON=""
DRY_RUN=0
EMIT_AUDIT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --override-regression) OVERRIDE=1; shift ;;
    --reason) REASON="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --emit-audit) EMIT_AUDIT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -z "$AGENT" || -z "$VERSION" ]]; then
  echo "prompt-promote: <agent> and <version> are required" >&2
  exit 2
fi

REGISTRY="$PWD/prompts/registry.yaml"
EVAL_HISTORY="$PWD/prompts/eval-history/$AGENT/$VERSION.json"

if [[ ! -f "$EVAL_HISTORY" ]]; then
  echo "prompt-promote: eval is required first; run /prompt-eval $AGENT --version $VERSION" >&2
  exit 2
fi

if [[ ! -f "$REGISTRY" ]]; then
  echo "prompt-promote: registry not found at $REGISTRY" >&2
  exit 2
fi

REGISTRY="$REGISTRY" EVAL_HISTORY="$EVAL_HISTORY" AGENT="$AGENT" VERSION="$VERSION" \
OVERRIDE="$OVERRIDE" REASON="$REASON" DRY_RUN="$DRY_RUN" EMIT_AUDIT="$EMIT_AUDIT" node -e '
const fs = require("fs");
const path = require("path");

const registryPath = process.env.REGISTRY;
const evalPath = process.env.EVAL_HISTORY;
const agent = process.env.AGENT;
const version = process.env.VERSION;
const override = process.env.OVERRIDE === "1";
const reason = process.env.REASON || "";
const dryRun = process.env.DRY_RUN === "1";
const auditPath = process.env.EMIT_AUDIT;

const evalData = JSON.parse(fs.readFileSync(evalPath, "utf8"));
const candidateRate = parseFloat(evalData.eval_pass_rate || 0);

const registry = fs.readFileSync(registryPath, "utf8");
const lines = registry.split("\n");
let inAgent = false;
let priorRate = 0;
let priorVersion = "";
const versionStatus = {};

for (const line of lines) {
  if (/^- id:\s*(\S+)/.test(line)) {
    inAgent = line.match(/^- id:\s*(\S+)/)[1] === agent;
    continue;
  }
  if (!inAgent) continue;
  const m = line.match(/version:\s*(\S+),.*?eval_pass_rate:\s*([0-9.]+).*?status:\s*(\w+)/);
  if (m) {
    versionStatus[m[1]] = { rate: parseFloat(m[2]), status: m[3] };
    if (m[3] === "active") {
      priorRate = parseFloat(m[2]);
      priorVersion = m[1];
    }
  }
}

if (priorVersion && candidateRate < priorRate && !override) {
  process.stderr.write(`prompt-promote: rejected: candidate ${version} eval_pass_rate=${candidateRate} regression vs prior active ${priorVersion} eval_pass_rate=${priorRate}; use --override-regression --reason <text> to bypass\n`);
  process.exit(2);
}

if (override && !reason) {
  process.stderr.write(`prompt-promote: --override-regression requires --reason <text>\n`);
  process.exit(2);
}

let newRegistry = registry;
newRegistry = newRegistry.replace(/(version:\s*([\d.]+),.*?status:\s*)(active|archived|candidate)/g, (m, prefix, v, status) => {
  if (v === version) return `${prefix}active`;
  if (v === priorVersion && priorVersion) return `${prefix}archived`;
  return m;
});

if (!dryRun) {
  fs.writeFileSync(registryPath, newRegistry);
}
process.stderr.write(`prompt-promote: ${dryRun ? "would promote" : "promoted"} ${agent} v${version} to active${priorVersion ? ` (prior active ${priorVersion} ${dryRun ? "would be" : ""} archived)` : ""}\n`);

if (auditPath) {
  fs.mkdirSync(path.dirname(auditPath), { recursive: true });
  const audit = {
    event: "prompt-promote" + (override ? " override-regression" : ""),
    agent,
    version,
    prior_version: priorVersion,
    candidate_eval_pass_rate: candidateRate,
    prior_eval_pass_rate: priorRate,
    override_regression: override,
    reason: reason || null,
    dry_run: dryRun,
    at: new Date().toISOString(),
  };
  fs.appendFileSync(auditPath, JSON.stringify(audit) + "\n");
}
'
