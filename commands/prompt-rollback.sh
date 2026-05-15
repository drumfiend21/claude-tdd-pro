#!/usr/bin/env bash
# prompt-rollback.sh — P-6 substrate. One-command rollback to the
# most recent archived version of an agent's prompt.
#
# Per architecture section 16 P-6: "/prompt-rollback <id> one-command."
#
# Usage:
#   prompt-rollback.sh <agent> [--dry-run] [--emit-audit <path>]

set -uo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Usage: prompt-rollback.sh <agent> [--dry-run] [--emit-audit <path>]"
  exit 0
fi

AGENT="${1:-}"
shift 2>/dev/null || true

DRY_RUN=0
EMIT_AUDIT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --emit-audit) EMIT_AUDIT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -z "$AGENT" ]]; then
  echo "prompt-rollback: <agent> is required" >&2
  exit 2
fi

REGISTRY="$PWD/prompts/registry.yaml"
if [[ ! -f "$REGISTRY" ]]; then
  echo "prompt-rollback: registry not found at $REGISTRY" >&2
  exit 2
fi

REGISTRY="$REGISTRY" AGENT="$AGENT" DRY_RUN="$DRY_RUN" EMIT_AUDIT="$EMIT_AUDIT" node -e '
const fs = require("fs");
const path = require("path");

const registryPath = process.env.REGISTRY;
const agent = process.env.AGENT;
const dryRun = process.env.DRY_RUN === "1";
const auditPath = process.env.EMIT_AUDIT;

const registry = fs.readFileSync(registryPath, "utf8");
const lines = registry.split("\n");
let inAgent = false;
let activeVersion = "";
const versions = [];

for (const line of lines) {
  if (/^- id:\s*(\S+)/.test(line)) {
    inAgent = line.match(/^- id:\s*(\S+)/)[1] === agent;
    continue;
  }
  if (!inAgent) continue;
  const m = line.match(/version:\s*(\S+),.*?status:\s*(\w+)/);
  if (m) {
    versions.push({ version: m[1], status: m[2] });
    if (m[2] === "active") activeVersion = m[1];
  }
}

const archived = versions.filter(v => v.status === "archived");
if (archived.length === 0) {
  process.stderr.write(`prompt-rollback: no prior archived version to roll back to for ${agent}\n`);
  process.exit(2);
}

archived.sort((a, b) => a.version.localeCompare(b.version, undefined, { numeric: true }));
const target = archived[archived.length - 1].version;

let newRegistry = registry;
newRegistry = newRegistry.replace(/(version:\s*([\d.]+),.*?status:\s*)(active|archived|candidate)/g, (m, prefix, v) => {
  if (v === target) return `${prefix}active`;
  if (v === activeVersion && activeVersion) return `${prefix}archived`;
  return m;
});

if (!dryRun) {
  fs.writeFileSync(registryPath, newRegistry);
}
process.stderr.write(`prompt-rollback: ${dryRun ? "would roll back" : "rolled back"} ${agent} from v${activeVersion} to v${target}\n`);

if (auditPath) {
  fs.mkdirSync(path.dirname(auditPath), { recursive: true });
  fs.appendFileSync(auditPath, JSON.stringify({ event: "prompt-rollback", agent, from: activeVersion, to: target, dry_run: dryRun, at: new Date().toISOString() }) + "\n");
}
'
