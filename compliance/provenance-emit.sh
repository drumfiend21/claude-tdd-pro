#!/usr/bin/env bash
# compliance/provenance-emit.sh — C-3 AI Provenance Manifest emitter
# per §16: "AI Provenance Manifest emitter; signed with project-local
# key; cost_telemetry; decision_provenance block; git notes integration."
#
# Per §2.8 manifest fields: commit, timestamp, author_human,
# ai_involvement, rubric_state (with rubric_hash), standards_state,
# pr_corpus_state, compliance_state, human_review, cost_telemetry
# (tokens_in/out/model/duration_ms/monetary_estimate_usd),
# decision_provenance, signature (sha256).

set -uo pipefail

COMMIT_SHA=""
TIMESTAMP=""
EMIT=""
GIT_NOTES=0
TOKENS_IN=0
TOKENS_OUT=0
MODEL=""
DURATION_MS=0
DECISION_TRAILER=""
TREE=""
SIGNING_KEY=""
RULES_EVAL=""
RULES_BLOCKED=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --commit-sha) COMMIT_SHA="$2"; shift 2 ;;
    --timestamp) TIMESTAMP="$2"; shift 2 ;;
    --emit) EMIT="$2"; shift 2 ;;
    --git-notes) GIT_NOTES=1; shift ;;
    --tokens-in) TOKENS_IN="$2"; shift 2 ;;
    --tokens-out) TOKENS_OUT="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --duration-ms) DURATION_MS="$2"; shift 2 ;;
    --decision-trailer) DECISION_TRAILER="$2"; shift 2 ;;
    --tree) TREE="$2"; shift 2 ;;
    --signing-key) SIGNING_KEY="$2"; shift 2 ;;
    --rules-evaluated) RULES_EVAL="$2"; shift 2 ;;
    --rules-blocked) RULES_BLOCKED="$2"; shift 2 ;;
    *) echo "provenance-emit: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$COMMIT_SHA" ]] && { echo "provenance-emit: --commit-sha <sha> required" >&2; exit 2; }
[[ -z "$TIMESTAMP" ]] && TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
[[ -z "$EMIT" ]] && EMIT=".claude-tdd-pro/provenance/$COMMIT_SHA.json"
mkdir -p "$(dirname "$EMIT")"

COMMIT_SHA="$COMMIT_SHA" TIMESTAMP="$TIMESTAMP" EMIT="$EMIT" \
TOKENS_IN="$TOKENS_IN" TOKENS_OUT="$TOKENS_OUT" MODEL="$MODEL" DURATION_MS="$DURATION_MS" \
DECISION_TRAILER="$DECISION_TRAILER" TREE="$TREE" SIGNING_KEY="$SIGNING_KEY" \
RULES_EVAL="$RULES_EVAL" RULES_BLOCKED="$RULES_BLOCKED" node -e '
  const fs = require("fs");
  const path = require("path");
  const crypto = require("crypto");

  const tokensIn = parseInt(process.env.TOKENS_IN || "0", 10);
  const tokensOut = parseInt(process.env.TOKENS_OUT || "0", 10);
  const monetaryEstimateUsd = (tokensIn * 3 / 1e6) + (tokensOut * 15 / 1e6);

  let rubricHash = "sha256:no-tree";
  if (process.env.TREE && fs.existsSync(process.env.TREE)) {
    const h = crypto.createHash("sha256");
    function walk(d) {
      for (const e of fs.readdirSync(d).sort()) {
        const p = path.join(d, e);
        const st = fs.statSync(p);
        if (st.isDirectory()) walk(p);
        else if (e.endsWith(".yaml")) {
          h.update(p + ":" + fs.readFileSync(p));
        }
      }
    }
    walk(process.env.TREE);
    rubricHash = "sha256:" + h.digest("hex");
  }

  const rulesEvaluated = (process.env.RULES_EVAL || "").split(",").filter(Boolean);
  const rulesBlocked = (process.env.RULES_BLOCKED || "").split(",").filter(Boolean);

  const manifest = {
    ai_involvement: { mode: "ai-collaborated", session_id: process.env.COMMIT_SHA },
    author_human: { name: "(unknown)", email: "(unknown)" },
    commit: process.env.COMMIT_SHA,
    compliance_state: {},
    cost_telemetry: {
      duration_ms: parseInt(process.env.DURATION_MS || "0", 10),
      model: process.env.MODEL || "(unspecified)",
      monetary_estimate_usd: monetaryEstimateUsd,
      tokens_in: tokensIn,
      tokens_out: tokensOut
    },
    decision_provenance: process.env.DECISION_TRAILER ? { trailer: process.env.DECISION_TRAILER } : {},
    human_review: { reviewers: [], approval_state: "pending" },
    pr_corpus_state: {},
    rubric_state: {
      rubric_hash: rubricHash,
      rules_evaluated: rulesEvaluated,
      rules_passed: rulesEvaluated.filter(r => !rulesBlocked.includes(r)),
      rules_blocked: rulesBlocked
    },
    standards_state: {},
    timestamp: process.env.TIMESTAMP
  };

  function canonicalize(v) {
    if (v === null || typeof v !== "object") return v;
    if (Array.isArray(v)) return v.map(canonicalize);
    const sorted = {};
    Object.keys(v).sort().forEach(k => { sorted[k] = canonicalize(v[k]); });
    return sorted;
  }
  const canon = canonicalize(manifest);

  const body = JSON.stringify(canon);
  const sigInput = process.env.SIGNING_KEY && fs.existsSync(process.env.SIGNING_KEY)
    ? body + fs.readFileSync(process.env.SIGNING_KEY)
    : body;
  canon.signature = "sha256:" + crypto.createHash("sha256").update(sigInput).digest("hex");

  fs.writeFileSync(process.env.EMIT, JSON.stringify(canonicalize(canon), null, 2));
'

if [[ "$GIT_NOTES" -eq 1 ]]; then
  git notes --ref=refs/notes/provenance add -f -F "$EMIT" "$COMMIT_SHA" 2>/dev/null || true
fi
