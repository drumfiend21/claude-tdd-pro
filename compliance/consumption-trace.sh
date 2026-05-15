#!/usr/bin/env bash
# consumption-trace.sh — C-20 substrate. Records frameworks consulted
# per commit at generation time per architecture section 16 C-20.
set -uo pipefail

COMMIT_SHA=""
CONSULTED=()
CONTROLS_CONSULTED=""
CONTROLS_FILE=""
EDITION=""
NOW=""
BYPASSED=0
EMIT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --commit-sha) COMMIT_SHA="$2"; shift 2 ;;
    --consulted-compliance) CONSULTED+=("$2"); shift 2 ;;
    --controls-consulted) CONTROLS_CONSULTED="$2"; shift 2 ;;
    --controls-file) CONTROLS_FILE="$2"; shift 2 ;;
    --edition) EDITION="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    --bypassed) BYPASSED=1; shift ;;
    --emit) EMIT="$2"; shift 2 ;;
    -h|--help) echo "Usage: consumption-trace.sh --commit-sha <sha> [--consulted-compliance <fw>]... [--controls-consulted <c1,c2>] [--edition <e>] [--bypassed] --emit <path>"; exit 0 ;;
    *) shift ;;
  esac
done

[[ -z "$COMMIT_SHA" || -z "$EMIT" ]] && { echo "consumption-trace: --commit-sha and --emit required" >&2; exit 2; }
[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

CONSULTED_CSV=$(IFS=,; echo "${CONSULTED[*]:-}")

COMMIT_SHA="$COMMIT_SHA" CONSULTED_CSV="$CONSULTED_CSV" \
CONTROLS_CONSULTED="$CONTROLS_CONSULTED" CONTROLS_FILE="$CONTROLS_FILE" \
EDITION="$EDITION" NOW="$NOW" BYPASSED="$BYPASSED" EMIT="$EMIT" node -e '
const fs = require("fs");
const path = require("path");
const sha = process.env.COMMIT_SHA;
const consulted = (process.env.CONSULTED_CSV || "").split(",").filter(Boolean);
const controlsConsulted = (process.env.CONTROLS_CONSULTED || "").split(",").filter(Boolean);
const controlsFile = process.env.CONTROLS_FILE;
const edition = process.env.EDITION;
const now = process.env.NOW;
const bypassed = process.env.BYPASSED === "1";
const emit = process.env.EMIT;

const compliance_state = {};
for (const fw of consulted) {
  const lastFile = `.claude-tdd-pro/compliance-last-fetch/${fw}.txt`;
  let fetched_at = null, freshness = "no-fetch-record";
  if (fs.existsSync(lastFile)) {
    fetched_at = fs.readFileSync(lastFile, "utf8").trim();
    const diff = new Date(now).getTime() - new Date(fetched_at).getTime();
    freshness = diff <= 7*86400e3 ? "fresh-within-fetch-frequency" : "stale-beyond-fetch-frequency";
  }
  const controls = {};
  if (controlsFile && fs.existsSync(controlsFile)) {
    const body = fs.readFileSync(controlsFile, "utf8");
    for (const cid of controlsConsulted) {
      const re = new RegExp(`framework:\\s*${fw}[\\s\\S]*?control_id:\\s*${cid}[\\s\\S]*?legal_review_status:\\s*(\\S+)`);
      const m = body.match(re);
      if (m) controls[cid] = { legal_review_status: m[1] };
    }
  }
  compliance_state[fw] = {
    fetched_at,
    edition: edition || null,
    freshness_at_generation: freshness,
    controls_consulted: controlsConsulted,
    controls_legal_review: controls,
    operator_bypass: bypassed ? "operator-bypass" : null,
  };
}

const manifest = {
  commit: sha,
  generated_at: now,
  compliance_state,
};

fs.mkdirSync(path.dirname(emit), { recursive: true });
fs.writeFileSync(emit, JSON.stringify(manifest));
process.stderr.write(`consumption-trace: emitted ${Object.keys(compliance_state).length} framework(s) for commit ${sha} to ${emit}\n`);
'
