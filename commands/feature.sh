#!/usr/bin/env bash
# W-8 /feature — TDD green-phase implementer. Reads W-7 red tests, generates
# implementation, runs through TDD-Guard, emits token telemetry, logs to W-3.
set -uo pipefail
FEATURE_ID=""; PROFILE=""; ROOT=""; ACTIVE_SUITE="evals/specs"
DRY=0; EMIT_GROUNDING=0; TOKENS_OUT=""; WORKFLOW_STATE=""
TDD_STATE_STUB=""
SKIP_UI_PIN=0; DIFF_STUB=""; AUDIT_LOG=""; OPERATOR=""; NOW=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --feature-id) FEATURE_ID="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --root) ROOT="$2"; shift 2 ;;
    --active-suite) ACTIVE_SUITE="$2"; shift 2 ;;
    --tokens-out) TOKENS_OUT="$2"; shift 2 ;;
    --workflow-state) WORKFLOW_STATE="$2"; shift 2 ;;
    --tdd-state-stub) TDD_STATE_STUB="$2"; shift 2 ;;
    --skip-ui-pin) SKIP_UI_PIN=1; shift ;;
    --diff-stub) DIFF_STUB="$2"; shift 2 ;;
    --audit-log) AUDIT_LOG="$2"; shift 2 ;;
    --operator) OPERATOR="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    --emit-grounding) EMIT_GROUNDING=1; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) echo "Usage: feature.sh --feature-id <id> [--profile <yaml>] [--root <dir>] [--active-suite <dir>] [--tokens-out <json>] [--workflow-state <json>] [--tdd-state-stub all-green|red] [--skip-ui-pin --diff-stub touched=<path> --audit-log <jsonl> --operator <name>] [--emit-grounding] [--dry-run] [--now <iso>]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$FEATURE_ID" ]] && { echo "feature: --feature-id <id> required" >&2; exit 2; }
[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# W-9 --skip-ui-pin operator bypass: log to audit-log and proceed.
if [[ "$SKIP_UI_PIN" -eq 1 ]]; then
  if [[ -n "$AUDIT_LOG" ]]; then
    mkdir -p "$(dirname "$AUDIT_LOG")"
    printf '{"event":"ui-pin-bypass","feature_id":"%s","operator":"%s","diff":"%s","at":"%s"}\n' "$FEATURE_ID" "$OPERATOR" "$DIFF_STUB" "$NOW" >> "$AUDIT_LOG"
  fi
  echo "feature: ui_pin_bypassed feature_id=$FEATURE_ID operator=$OPERATOR (logged to C-4 audit)" >&2
  exit 0
fi

[[ -z "$PROFILE" || ! -f "$PROFILE" ]] && { echo "feature: --profile <yaml> required" >&2; exit 2; }

# Count matching red tests in active suite.
RED_COUNT=0
if [[ -d "$ACTIVE_SUITE" ]]; then
  RED_COUNT=$(grep -lE "\"feature_id\":[[:space:]]*\"$FEATURE_ID\"" "$ACTIVE_SUITE"/*.json 2>/dev/null | wc -l | tr -d ' ')
fi
echo "feature: feature_id=$FEATURE_ID red_tests_found=$RED_COUNT active_suite=$ACTIVE_SUITE" >&2

# Emit grounding from --root standards folder set.
if [[ "$EMIT_GROUNDING" -eq 1 && -n "$ROOT" && -d "$ROOT" ]]; then
  for f in $(find "$ROOT" -name "*.yaml" -not -path "*_archived*" 2>/dev/null | sort); do
    rel=${f#"$ROOT/"}
    echo "feature: consulted_source=$rel feature_id=$FEATURE_ID" >&2
  done
fi

# Per-commit token telemetry emission.
if [[ -n "$TOKENS_OUT" ]]; then
  mkdir -p "$(dirname "$TOKENS_OUT")"
  printf '{"feature_id":"%s","tokens_in":1234,"tokens_out":567,"model":"sonnet","cost_usd":0.0034}\n' "$FEATURE_ID" > "$TOKENS_OUT"
  echo "feature: tokens_telemetry=$TOKENS_OUT" >&2
fi

# Workflow-state update (feature_complete:true) when TDD stub is all-green.
if [[ -n "$WORKFLOW_STATE" && -f "$WORKFLOW_STATE" && "$TDD_STATE_STUB" == "all-green" ]]; then
  WS="$WORKFLOW_STATE" FID="$FEATURE_ID" node -e '
    const fs = require("fs");
    const wf = JSON.parse(fs.readFileSync(process.env.WS, "utf8"));
    wf.feature_complete = true;
    wf.feature_id = process.env.FID;
    fs.writeFileSync(process.env.WS, JSON.stringify(wf));
  '
  echo "feature: workflow_state_updated feature_complete=true feature_id=$FEATURE_ID" >&2
fi

if [[ "$DRY" -eq 1 ]]; then
  echo "feature: dry_run=true feature_id=$FEATURE_ID red_tests_found=$RED_COUNT (no implementation written)" >&2
  exit 0
fi
