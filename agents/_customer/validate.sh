#!/usr/bin/env bash
# §2.26 customer-facing AI agent safety contract validator per §26 v1.11.
#
# Validates that every agents/_customer/<name>.md template declares the
# five mandatory fields:
#   (a) grounding_sources: [<rag-store-id>, ...]
#   (b) refusal_template: "I don't have grounding..." (or inherits: w-12)
#   (c) per_turn_cost_target: <int>
#   (d) audit_log: .claude-tdd-pro/customer-agents/<name>/turns.jsonl
#   (e) safety_classifier_hook: <path>
#
# Validator output: per-file pass/fail summary + per-rule miss list.
#
# Usage:
#   validate.sh [--dir <agents/_customer>] [--emit <jsonl>]
set -uo pipefail

DIR="${CLAUDE_PLUGIN_ROOT:-.}/agents/_customer"
EMIT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) DIR="$2"; shift 2 ;;
    --emit) EMIT="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: validate.sh [--dir <agents/_customer>] [--emit <jsonl>]" >&2
      exit 0
      ;;
    *) echo "validate: unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ ! -d "$DIR" ]] && { echo "validate: dir not found: $DIR" >&2; exit 2; }

DIR="$DIR" EMIT="$EMIT" node -e '
  const fs = require("fs");
  const path = require("path");
  const dir = process.env.DIR;
  const emit = process.env.EMIT;
  const required = ["grounding_sources", "refusal_template", "per_turn_cost_target", "audit_log", "safety_classifier_hook"];
  let totalPass = 0;
  let totalFail = 0;
  const failures = [];
  const files = fs.readdirSync(dir).filter(n => n.endsWith(".md") && n !== "README.md");
  for (const f of files) {
    const content = fs.readFileSync(path.join(dir, f), "utf8");
    const missing = required.filter(k => !new RegExp(`^${k}:`, "m").test(content));
    if (missing.length === 0) {
      totalPass++;
      process.stderr.write(`validate: PASS ${f}\n`);
    } else {
      totalFail++;
      const reason = `missing: ${missing.join(", ")}`;
      process.stderr.write(`validate: FAIL ${f} ${reason}\n`);
      failures.push({ file: f, missing });
    }
  }
  if (emit) {
    fs.mkdirSync(path.dirname(emit) || ".", { recursive: true });
    fs.writeFileSync(emit, JSON.stringify({ total_pass: totalPass, total_fail: totalFail, failures }));
  }
  process.stderr.write(`validate: total_pass=${totalPass} total_fail=${totalFail}\n`);
  process.exit(totalFail > 0 ? 1 : 0);
'
