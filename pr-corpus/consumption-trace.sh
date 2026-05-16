#!/usr/bin/env bash
# L-23 generation-time pr-corpus consumption trace. Records every pattern_id
# referenced and every PR consulted during a generation event (commit-scoped),
# with freshness_status and operator_bypass tags.
set -uo pipefail
EVENT=""; OUT=""; PATTERNS_INDEX=""; NOW=""; WINDOW="24h"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --event) EVENT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --patterns-index) PATTERNS_INDEX="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    --freshness-window) WINDOW="$2"; shift 2 ;;
    -h|--help) echo "Usage: consumption-trace.sh --event <json> --out <jsonl> [--patterns-index <yaml>] [--now <iso>] [--freshness-window <dur>]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$EVENT" || ! -f "$EVENT" ]] && { echo "consumption-trace: --event <json> required" >&2; exit 2; }
[[ -z "$OUT" ]] && { echo "consumption-trace: --out <jsonl> required" >&2; exit 2; }
[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

case "$WINDOW" in
  *h) WIN_SEC=$((${WINDOW%h} * 3600)) ;;
  *m) WIN_SEC=$((${WINDOW%m} * 60)) ;;
  *d) WIN_SEC=$((${WINDOW%d} * 86400)) ;;
  *) WIN_SEC=86400 ;;
esac

mkdir -p "$(dirname "$OUT")"
touch "$OUT"

EVENT="$EVENT" OUT="$OUT" PI="$PATTERNS_INDEX" NOW="$NOW" WIN_SEC="$WIN_SEC" node -e '
const fs = require("fs");
const e = JSON.parse(fs.readFileSync(process.env.EVENT, "utf8"));
const out = process.env.OUT;
const now = new Date(process.env.NOW);
const winSec = parseInt(process.env.WIN_SEC, 10);

const patternsRef = e.patterns_referenced;
const consultedPrs = e.consulted_prs;

if (Array.isArray(patternsRef) && patternsRef.length === 0 && Array.isArray(consultedPrs) && consultedPrs.length === 0) {
  process.stderr.write("consumption-trace: no_pr_corpus_referenced (event has empty patterns_referenced and consulted_prs)\n");
  process.exit(0);
}

let patternsIndex = null;
if (process.env.PI && fs.existsSync(process.env.PI)) {
  const text = fs.readFileSync(process.env.PI, "utf8");
  patternsIndex = {};
  for (const line of text.split("\n")) {
    const m = line.match(/id:\s*([A-Za-z0-9_-]+)/);
    if (m) {
      const pcMatch = line.match(/provenance_class:\s*([A-Za-z0-9_-]+)/);
      patternsIndex[m[1]] = pcMatch ? pcMatch[1] : null;
    }
  }
}

const references = [];
for (const pid of (patternsRef || [])) {
  const ref = { pattern_id: pid };
  if (patternsIndex && patternsIndex[pid]) ref.provenance_class = patternsIndex[pid];
  references.push(ref);
}

const consulted = [];
for (const pr of (consultedPrs || [])) {
  const entry = { number: pr.number };
  if (pr.org) { entry.source_org = pr.org; entry.source_pr_number = pr.number; }
  if (pr.source_id) {
    entry.source_pr_number = entry.source_pr_number || pr.number;
    const lf = `.claude-tdd-pro/pr-corpus/last-fetch/${pr.source_id}.txt`;
    if (fs.existsSync(lf)) {
      const last = fs.readFileSync(lf, "utf8").trim();
      const diff = (now - new Date(last)) / 1000;
      entry.freshness_status = diff < winSec ? "fresh" : "stale";
    }
  }
  consulted.push(entry);
}

const record = {
  event: e.event || "generation",
  commit: e.commit || null,
  at: process.env.NOW,
  references,
  consulted_prs: consulted,
};
if (e.skip_fresh) record.operator_bypass = true;

fs.appendFileSync(out, JSON.stringify(record) + "\n");
process.stderr.write(`consumption-trace: written 1 event to ${out} (refs=${references.length} prs=${consulted.length})\n`);
'
