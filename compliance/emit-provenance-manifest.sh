#!/usr/bin/env bash
# §2.8 AI Provenance Manifest emitter. Writes a per-commit manifest at
# .claude-tdd-pro/provenance/<commit-sha>.json with the §2.8 envelope
# scaffold populated. Each top-level block (ai_involvement, rubric_state,
# standards_state, pr_corpus_state, compliance_state, human_review,
# cost_telemetry, decision_provenance) is initialized to an empty
# object/array per the contract so downstream tooling can mutate it.
#
# CLI:
#   --commit SHA   commit sha to record (required)
#   --out PATH     output path (required)
#   --now ISO      timestamp to record (required)
#
# Exit codes:
#   0  written
#   2  usage error

COMMIT=""
OUT=""
NOW=""

while [ $# -gt 0 ]; do
  case "$1" in
    --commit) COMMIT="${2-}"; shift 2 ;;
    --out)    OUT="${2-}";    shift 2 ;;
    --now)    NOW="${2-}";    shift 2 ;;
    -h|--help)
      echo "Usage: emit-provenance-manifest.sh --commit <sha> --out <path> --now <iso>" >&2
      exit 0
      ;;
    *) echo "emit-provenance-manifest: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$COMMIT" ] || [ -z "$OUT" ] || [ -z "$NOW" ]; then
  echo "emit-provenance-manifest: --commit, --out, --now all required" >&2
  exit 2
fi

COMMIT_SHA="$COMMIT" OUT_PATH="$OUT" NOW_ISO="$NOW" ruby - <<'RUBY'
require 'json'

doc = {
  "commit"       => ENV['COMMIT_SHA'],
  "timestamp"    => ENV['NOW_ISO'],
  "author_human" => nil,
  "ai_involvement" => {
    "tier" => nil,
    "models_used" => [],
    "agents_invoked" => [],
    "skills_invoked" => [],
    "prompts" => [],
  },
  "rubric_state" => {
    "rubric_hash" => nil,
    "rules_evaluated" => [],
    "rules_passed" => [],
    "rules_blocked" => [],
  },
  "standards_state"  => {},
  "pr_corpus_state"  => {},
  "compliance_state" => {},
  "human_review" => {
    "reviewer" => nil,
    "review_kind" => nil,
    "verifier_consulted" => false,
  },
  "cost_telemetry" => {
    "tokens_in" => 0,
    "tokens_out" => 0,
    "model" => nil,
    "duration_ms" => 0,
    "monetary_estimate_usd" => 0,
  },
  "decision_provenance" => {
    "adrs" => [],
    "architect_session_id" => nil,
    "decisions_referenced" => [],
  },
  "signature" => nil,
}

File.write(ENV['OUT_PATH'], JSON.generate(doc))
STDERR.write("emit-provenance-manifest: wrote #{ENV['OUT_PATH']}\n")
RUBY
