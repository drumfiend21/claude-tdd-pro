#!/usr/bin/env bash
# Q-12 agent-invocation observability log per §26 v1.11.
#
# Per-invocation trace record for every §2.3 subagent dispatch. Records:
#   subagent_id, prompt_id, prompt_version, tokens_in, tokens_out,
#   model, latency_ms, exit_code, finding_count, ts
#
# Distinct from H-12 cost rollup (aggregate budget surface): Q-12 is
# the debug/trace surface — one line per invocation, query-able by
# subagent_id, prompt_id, or commit_sha.
#
# Storage: .claude-tdd-pro/agent-invocations.jsonl (append-only).
# Privacy: honors Q-6 (local-only by default; export via Q-6 filter).
#
# Subcommands:
#   --append    --subagent-id <id> --prompt-id <id> --prompt-version <semver>
#               --model <name> --tokens-in <int> --tokens-out <int>
#               --latency-ms <int> --exit-code <int> [--finding-count <int>]
#               [--commit-sha <sha>] [--now <iso>]
#   --query     [--subagent-id <id>] [--prompt-id <id>] [--commit-sha <sha>]
#               [--format <jsonl|text>]
#   --summarize-by <dimension>   subagent_id | prompt_id | model
set -uo pipefail

LOG_PATH="${Q12_LOG_PATH:-.claude-tdd-pro/agent-invocations.jsonl}"

CMD=""
SUBAGENT_ID=""
PROMPT_ID=""
PROMPT_VERSION=""
MODEL=""
TOKENS_IN=""
TOKENS_OUT=""
LATENCY_MS=""
EXIT_CODE=""
FINDING_COUNT="0"
COMMIT_SHA=""
NOW_ISO=""
QUERY_SUBAGENT=""
QUERY_PROMPT=""
QUERY_COMMIT=""
FORMAT="text"
SUMMARIZE_BY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --append) CMD="append"; shift ;;
    --query) CMD="query"; shift ;;
    --summarize-by) CMD="summarize"; SUMMARIZE_BY="$2"; shift 2 ;;
    --subagent-id)
      if [[ "$CMD" == "query" ]]; then QUERY_SUBAGENT="$2"; else SUBAGENT_ID="$2"; fi
      shift 2
      ;;
    --prompt-id)
      if [[ "$CMD" == "query" ]]; then QUERY_PROMPT="$2"; else PROMPT_ID="$2"; fi
      shift 2
      ;;
    --prompt-version) PROMPT_VERSION="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --tokens-in) TOKENS_IN="$2"; shift 2 ;;
    --tokens-out) TOKENS_OUT="$2"; shift 2 ;;
    --latency-ms) LATENCY_MS="$2"; shift 2 ;;
    --exit-code) EXIT_CODE="$2"; shift 2 ;;
    --finding-count) FINDING_COUNT="$2"; shift 2 ;;
    --commit-sha)
      if [[ "$CMD" == "query" ]]; then QUERY_COMMIT="$2"; else COMMIT_SHA="$2"; fi
      shift 2
      ;;
    --now) NOW_ISO="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: agent-invocations.sh --append|--query|--summarize-by <dim> [...flags]" >&2
      exit 0
      ;;
    *) echo "agent-invocations: unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$CMD" ]] && { echo "agent-invocations: one of --append, --query, --summarize-by required" >&2; exit 2; }

case "$CMD" in
  append)
    for f in SUBAGENT_ID PROMPT_ID PROMPT_VERSION MODEL TOKENS_IN TOKENS_OUT LATENCY_MS EXIT_CODE; do
      if [[ -z "${!f}" ]]; then
        echo "agent-invocations: --append requires --subagent-id --prompt-id --prompt-version --model --tokens-in --tokens-out --latency-ms --exit-code (missing: $f)" >&2
        exit 2
      fi
    done
    [[ -z "$NOW_ISO" ]] && NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    mkdir -p "$(dirname "$LOG_PATH")"
    SUBAGENT_ID="$SUBAGENT_ID" PROMPT_ID="$PROMPT_ID" PROMPT_VERSION="$PROMPT_VERSION" \
    MODEL="$MODEL" TOKENS_IN="$TOKENS_IN" TOKENS_OUT="$TOKENS_OUT" \
    LATENCY_MS="$LATENCY_MS" EXIT_CODE="$EXIT_CODE" FINDING_COUNT="$FINDING_COUNT" \
    COMMIT_SHA="$COMMIT_SHA" NOW_ISO="$NOW_ISO" LOG_PATH="$LOG_PATH" node -e '
      const fs = require("fs");
      const entry = {
        ts: process.env.NOW_ISO,
        subagent_id: process.env.SUBAGENT_ID,
        prompt_id: process.env.PROMPT_ID,
        prompt_version: process.env.PROMPT_VERSION,
        model: process.env.MODEL,
        tokens_in: parseInt(process.env.TOKENS_IN, 10),
        tokens_out: parseInt(process.env.TOKENS_OUT, 10),
        latency_ms: parseInt(process.env.LATENCY_MS, 10),
        exit_code: parseInt(process.env.EXIT_CODE, 10),
        finding_count: parseInt(process.env.FINDING_COUNT, 10),
        commit_sha: process.env.COMMIT_SHA || null
      };
      fs.appendFileSync(process.env.LOG_PATH, JSON.stringify(entry) + "\n");
      process.stderr.write(`agent-invocations: appended subagent_id=${entry.subagent_id} prompt_id=${entry.prompt_id} latency_ms=${entry.latency_ms}\n`);
    '
    ;;
  query)
    [[ ! -f "$LOG_PATH" ]] && { echo "agent-invocations: no log at $LOG_PATH" >&2; exit 0; }
    QUERY_SUBAGENT="$QUERY_SUBAGENT" QUERY_PROMPT="$QUERY_PROMPT" \
    QUERY_COMMIT="$QUERY_COMMIT" FORMAT="$FORMAT" LOG_PATH="$LOG_PATH" node -e '
      const fs = require("fs");
      const qsub = process.env.QUERY_SUBAGENT;
      const qprm = process.env.QUERY_PROMPT;
      const qcmt = process.env.QUERY_COMMIT;
      const fmt = process.env.FORMAT;
      const lines = fs.readFileSync(process.env.LOG_PATH, "utf8").split("\n").filter(Boolean);
      const matches = [];
      for (const l of lines) {
        const e = JSON.parse(l);
        if (qsub && e.subagent_id !== qsub) continue;
        if (qprm && e.prompt_id !== qprm) continue;
        if (qcmt && e.commit_sha !== qcmt) continue;
        matches.push(e);
      }
      if (fmt === "jsonl") {
        process.stdout.write(matches.map(e => JSON.stringify(e)).join("\n") + (matches.length ? "\n" : ""));
      } else {
        for (const e of matches) {
          process.stderr.write(`agent-invocations: ts=${e.ts} subagent_id=${e.subagent_id} prompt_id=${e.prompt_id}@${e.prompt_version} model=${e.model} tokens=${e.tokens_in}/${e.tokens_out} latency_ms=${e.latency_ms} exit=${e.exit_code} findings=${e.finding_count}\n`);
        }
        process.stderr.write(`agent-invocations: query_matches=${matches.length}\n`);
      }
    '
    ;;
  summarize)
    case "$SUMMARIZE_BY" in subagent_id|prompt_id|model) ;; *) echo "agent-invocations: --summarize-by must be subagent_id|prompt_id|model" >&2; exit 2 ;; esac
    [[ ! -f "$LOG_PATH" ]] && { echo "agent-invocations: no log at $LOG_PATH" >&2; exit 0; }
    SUMMARIZE_BY="$SUMMARIZE_BY" LOG_PATH="$LOG_PATH" node -e '
      const fs = require("fs");
      const dim = process.env.SUMMARIZE_BY;
      const totals = {};
      for (const l of fs.readFileSync(process.env.LOG_PATH, "utf8").split("\n").filter(Boolean)) {
        const e = JSON.parse(l);
        const k = e[dim] || "unknown";
        totals[k] = totals[k] || { invocations: 0, tokens_in: 0, tokens_out: 0, total_latency_ms: 0 };
        totals[k].invocations += 1;
        totals[k].tokens_in += e.tokens_in || 0;
        totals[k].tokens_out += e.tokens_out || 0;
        totals[k].total_latency_ms += e.latency_ms || 0;
      }
      process.stderr.write(`agent-invocations: summarize_by=${dim}\n`);
      for (const [k, v] of Object.entries(totals)) {
        const avgLat = v.invocations ? Math.round(v.total_latency_ms / v.invocations) : 0;
        process.stderr.write(`  [${k}] invocations=${v.invocations} tokens_in=${v.tokens_in} tokens_out=${v.tokens_out} avg_latency_ms=${avgLat}\n`);
      }
    '
    ;;
esac
