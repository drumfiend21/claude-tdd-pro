#!/usr/bin/env bash
# Q-11 AI-assisted PR quality scorecard per §26 v1.11.
#
# Scores a PR against four input dimensions:
#   1. AI Provenance Manifest (§2.8) — cited evidence for each AI-touched file
#   2. Decision Trail (W-4) — referenced ADRs
#   3. R-10 component-API drift findings — number + severity
#   4. Q-12 invocation count — proxy for AI workload
#
# Output: per-PR score (0-100) + per-author + per-team rollup.
#
# Scoring:
#   Manifest completeness:    up to 30 pts
#   ADR coverage:             up to 25 pts
#   API drift hygiene:        up to 25 pts  (deduct per prop_removed)
#   Invocation observability: up to 20 pts  (logged Q-12 trace per AI turn)
#
# Privacy: per-author rollup uses anonymized P0..P3 quartile bands by
# default; full attribution requires --individual-attribution (Q-6).
#
# Usage:
#   pr-quality-scorecard.sh --pr-sha <sha> --manifest <path>
#                            --adrs-csv <list> --drift-findings <jsonl>
#                            --invocations-count <int>
#                            [--author <name>] [--team <name>]
#                            [--format text|json]
#                            [--rollup <path>] [--individual-attribution]
set -uo pipefail

PR_SHA=""
MANIFEST=""
ADRS_CSV=""
DRIFT_FINDINGS=""
INVOCATIONS=""
AUTHOR=""
TEAM=""
FORMAT="text"
ROLLUP=""
INDIVIDUAL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr-sha) PR_SHA="$2"; shift 2 ;;
    --manifest) MANIFEST="$2"; shift 2 ;;
    --adrs-csv) ADRS_CSV="$2"; shift 2 ;;
    --drift-findings) DRIFT_FINDINGS="$2"; shift 2 ;;
    --invocations-count) INVOCATIONS="$2"; shift 2 ;;
    --author) AUTHOR="$2"; shift 2 ;;
    --team) TEAM="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --rollup) ROLLUP="$2"; shift 2 ;;
    --individual-attribution) INDIVIDUAL=1; shift ;;
    -h|--help)
      echo "Usage: pr-quality-scorecard.sh --pr-sha <sha> --manifest <path> --adrs-csv <list> --drift-findings <jsonl> --invocations-count <int> [--author <name>] [--team <name>] [--format text|json] [--rollup <path>] [--individual-attribution]" >&2
      exit 0
      ;;
    *) echo "pr-quality-scorecard: unknown arg: $1" >&2; exit 2 ;;
  esac
done

for f in PR_SHA MANIFEST DRIFT_FINDINGS INVOCATIONS; do
  if [[ -z "${!f}" ]]; then
    echo "pr-quality-scorecard: --pr-sha --manifest --adrs-csv --drift-findings --invocations-count all required (missing: $f)" >&2
    exit 2
  fi
done
case "$FORMAT" in text|json) ;; *) echo "pr-quality-scorecard: --format must be text|json" >&2; exit 2 ;; esac

PR_SHA="$PR_SHA" MANIFEST="$MANIFEST" ADRS_CSV="$ADRS_CSV" \
DRIFT_FINDINGS="$DRIFT_FINDINGS" INVOCATIONS="$INVOCATIONS" \
AUTHOR="$AUTHOR" TEAM="$TEAM" FORMAT="$FORMAT" ROLLUP="$ROLLUP" \
INDIVIDUAL="$INDIVIDUAL" node -e '
  const fs = require("fs");
  const pr = process.env.PR_SHA;
  const fmt = process.env.FORMAT;
  const individual = process.env.INDIVIDUAL === "1";

  // (1) Manifest completeness 0..30.
  let manifestScore = 0;
  let manifestReasons = [];
  if (fs.existsSync(process.env.MANIFEST)) {
    try {
      const m = JSON.parse(fs.readFileSync(process.env.MANIFEST, "utf8"));
      let pts = 0;
      if (m.commit) pts += 5;
      if (m.ai_involvement && Array.isArray(m.ai_involvement.models_used) && m.ai_involvement.models_used.length > 0) pts += 10;
      if (m.standards_state && Object.keys(m.standards_state).length > 0) pts += 5;
      if (m.cost_telemetry && m.cost_telemetry.tokens_in > 0) pts += 5;
      if (m.decision_provenance && Array.isArray(m.decision_provenance.adrs)) pts += 5;
      manifestScore = pts;
      manifestReasons.push(`manifest pts=${pts}/30`);
    } catch (e) {
      manifestReasons.push(`manifest parse error: ${e.message}`);
    }
  } else {
    manifestReasons.push(`manifest absent`);
  }

  // (2) ADR coverage 0..25.
  const adrs = (process.env.ADRS_CSV || "").split(",").filter(Boolean);
  const adrScore = Math.min(25, adrs.length * 5);
  const adrReason = `adrs n=${adrs.length} pts=${adrScore}/25`;

  // (3) R-10 drift hygiene 0..25 (deduct 5 per prop_removed; baseline 25).
  let driftScore = 25;
  let driftReason = "no drift findings";
  if (fs.existsSync(process.env.DRIFT_FINDINGS)) {
    const lines = fs.readFileSync(process.env.DRIFT_FINDINGS, "utf8").split("\n").filter(Boolean);
    let removed = 0;
    for (const l of lines) {
      try { const e = JSON.parse(l); if (e.kind === "prop_removed") removed++; } catch {}
    }
    driftScore = Math.max(0, 25 - removed * 5);
    driftReason = `drift prop_removed=${removed} pts=${driftScore}/25`;
  }

  // (4) Invocation observability 0..20.
  const inv = parseInt(process.env.INVOCATIONS, 10) || 0;
  const invScore = inv > 0 ? 20 : 0;
  const invReason = `invocations=${inv} pts=${invScore}/20`;

  const total = manifestScore + adrScore + driftScore + invScore;

  const card = {
    pr_sha: pr,
    score: total,
    components: {
      manifest_completeness: manifestScore,
      adr_coverage: adrScore,
      drift_hygiene: driftScore,
      invocation_observability: invScore
    },
    reasons: [...manifestReasons, adrReason, driftReason, invReason]
  };
  if (process.env.AUTHOR) card.author = individual ? process.env.AUTHOR : "P" + Math.min(3, Math.floor(total / 26));
  if (process.env.TEAM) card.team = process.env.TEAM;

  if (process.env.ROLLUP) {
    const path = require("path");
    fs.mkdirSync(path.dirname(process.env.ROLLUP) || ".", { recursive: true });
    fs.appendFileSync(process.env.ROLLUP, JSON.stringify(card) + "\n");
  }

  if (fmt === "json") {
    process.stdout.write(JSON.stringify(card));
  } else {
    process.stderr.write(`pr-quality-scorecard: pr_sha=${pr} score=${total}/100\n`);
    for (const r of card.reasons) process.stderr.write(`  ${r}\n`);
    if (card.author) process.stderr.write(`  author=${card.author} (${individual ? "individual" : "quartile-band"})\n`);
    if (card.team) process.stderr.write(`  team=${card.team}\n`);
  }
'
