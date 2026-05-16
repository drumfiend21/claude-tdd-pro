#!/usr/bin/env bash
# L-22 live freshness gate for pr-corpus rules. Stale-source action depends
# on mode: --strict disables; default-non-strict demotes when severity present;
# blocks otherwise. --skip-fresh bypasses with audit-log entry.
set -uo pipefail
RULE=""; NOW=""; WINDOW="24h"; STRICT=0; SKIP_FRESH=0; AUDIT=""; EMIT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --rule) RULE="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    --freshness-window) WINDOW="$2"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    --skip-fresh) SKIP_FRESH=1; shift ;;
    --audit-log) AUDIT="$2"; shift 2 ;;
    --emit) EMIT="$2"; shift 2 ;;
    -h|--help) echo "Usage: freshness-gate.sh --rule <yaml> --now <iso> --freshness-window <dur> [--strict|--skip-fresh] [--audit-log <jsonl>] [--emit json|fields]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$RULE" || ! -f "$RULE" ]] && { echo "freshness-gate: --rule <yaml> required" >&2; exit 2; }
[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

case "$WINDOW" in
  *h) WIN_SEC=$((${WINDOW%h} * 3600)) ;;
  *m) WIN_SEC=$((${WINDOW%m} * 60)) ;;
  *d) WIN_SEC=$((${WINDOW%d} * 86400)) ;;
  *) WIN_SEC=86400 ;;
esac

RULE="$RULE" NOW="$NOW" WIN_SEC="$WIN_SEC" STRICT="$STRICT" SKIP_FRESH="$SKIP_FRESH" EMIT="$EMIT" node -e '
const fs = require("fs");
const text = fs.readFileSync(process.env.RULE, "utf8");
const ruleIdMatch = text.match(/rule_id:\s*(\S+)/);
const sevMatch = text.match(/severity:\s*(\S+)/);
const ruleId = ruleIdMatch ? ruleIdMatch[1] : "unknown";
const severity = sevMatch ? sevMatch[1] : "";

// Find all source_id references in provenance.
const sources = [];
const sm = text.match(/source_id:\s*([A-Za-z0-9_-]+)/g) || [];
for (const m of sm) sources.push(m.replace(/^source_id:\s*/, ""));

const now = new Date(process.env.NOW);
const winSec = parseInt(process.env.WIN_SEC, 10);
const sourceStatus = {};
const staleSources = [];
let lastFetchAt = "";
for (const s of sources) {
  const lf = `.claude-tdd-pro/pr-corpus/last-fetch/${s}.txt`;
  if (fs.existsSync(lf)) {
    const last = fs.readFileSync(lf, "utf8").trim();
    lastFetchAt = last;
    const diff = (now - new Date(last)) / 1000;
    if (diff < winSec) {
      sourceStatus[s] = "fresh";
    } else {
      sourceStatus[s] = "stale";
      staleSources.push(s);
    }
  } else {
    sourceStatus[s] = "missing";
    staleSources.push(s);
  }
}

const emit = process.env.EMIT;
if (emit === "fields") {
  for (const s of sources) {
    const lf = `.claude-tdd-pro/pr-corpus/last-fetch/${s}.txt`;
    if (fs.existsSync(lf)) {
      process.stderr.write(`freshness-gate: ${s}:last_fetch_at=${fs.readFileSync(lf, "utf8").trim()}\n`);
    }
  }
}

const skip = process.env.SKIP_FRESH === "1";
if (skip) {
  process.stderr.write(`freshness-gate: rule_id=${ruleId} gate=bypassed reason=skip-fresh-flag\n`);
  if (process.env.AUDIT_LOG_PATH) {
    // handled outside node
  }
  process.exit(0);
}

if (staleSources.length === 0) {
  process.stderr.write(`freshness-gate: rule_id=${ruleId} gate=pass action=none severity=${severity}\n`);
  if (emit === "json") {
    process.stderr.write(`freshness-gate: {"rule_id":"${ruleId}","action":"none","reason":"all sources fresh"}\n`);
  }
  process.exit(0);
}

const strict = process.env.STRICT === "1";
if (strict) {
  process.stderr.write(`freshness-gate: rule_id=${ruleId} action=disable mode=strict stale_sources=${staleSources.join(",")}\n`);
  if (emit === "json") {
    process.stderr.write(`freshness-gate: {"rule_id":"${ruleId}","action":"disable","reason":"strict mode + stale source"}\n`);
  }
  process.exit(0);
}

if (severity) {
  process.stderr.write(`freshness-gate: rule_id=${ruleId} action=demote from=${severity} to=warn stale_sources=${staleSources.join(",")}\n`);
  if (emit === "json") {
    process.stderr.write(`freshness-gate: {"rule_id":"${ruleId}","action":"demote","reason":"non-strict + stale source + severity present"}\n`);
  }
  process.exit(0);
}

process.stderr.write(`freshness-gate: rule_blocked rule_id=${ruleId} stale_source=${staleSources[0]} (no severity to demote; non-strict mode blocks)\n`);
if (emit === "json") {
  process.stderr.write(`freshness-gate: {"rule_id":"${ruleId}","action":"block","reason":"stale source with no severity"}\n`);
}
// --emit modes are informational reports: exit 0 so caller can pipeline.
if (emit) process.exit(0);
process.exit(1);
'
RC=$?

# --skip-fresh audit-log entry (after node block to avoid env-passing complications).
if [[ "$SKIP_FRESH" -eq 1 && -n "$AUDIT" ]]; then
  mkdir -p "$(dirname "$AUDIT")"
  RID=$(grep -E "^rule_id:" "$RULE" | head -1 | sed -E 's/rule_id:[[:space:]]*//' | tr -d ' ')
  printf '{"event":"skip-fresh-bypass","rule_id":"%s","at":"%s"}\n' "$RID" "$NOW" >> "$AUDIT"
fi

exit $RC
