#!/usr/bin/env bash
# agents/_runner.sh — R-1 substrate stub.
#
# Per §16 R-1 ("Subagents: agents/review-react-rsc.md (sonnet,
# prompt_id rsc-reviewer), agents/review-react-a11y.md (sonnet,
# prompt_id a11y-reviewer)") and §2.3 (subagent contract): invokes
# the named subagent on the given input file and emits one JSON
# finding per line to the configured findings sink in the §2.3 shape:
# {severity, rule_id?, file, line, finding, suggested_fix}.
#
# This is the substrate stub. Real subagent invocation (spawning a
# Claude session per §2.3) lands later in the W phase; for now the
# stub emits a representative finding so downstream specs (R-2..R-7,
# T-1..T-6) can compose against a stable findings.jsonl shape.
#
# Usage:
#   _runner.sh --agent <name> --input <file> --emit-findings <path>

set -uo pipefail

AGENT=""
INPUT=""
EMIT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) AGENT="$2"; shift 2 ;;
    --input) INPUT="$2"; shift 2 ;;
    --emit-findings) EMIT="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: _runner.sh --agent <name> --input <file> --emit-findings <path>"
      exit 0
      ;;
    *)
      echo "_runner: unknown flag: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$AGENT" || -z "$EMIT" ]]; then
  echo "_runner: --agent and --emit-findings are required" >&2
  exit 2
fi

FILE_NAME="stdin"
if [[ -n "$INPUT" ]]; then
  FILE_NAME=$(basename "$INPUT")
fi

case "$AGENT" in
  review-react-rsc)
    printf '%s\n' '{"severity":"warn","rule_id":"react/no-client-only-import-in-server","file":"'"$FILE_NAME"'","line":1,"finding":"client-only import in server boundary (stub)","suggested_fix":"move import behind a use client directive or relocate component"}' > "$EMIT"
    ;;
  review-react-a11y)
    printf '%s\n' '{"severity":"warn","rule_id":"react-a11y/img-alt","file":"'"$FILE_NAME"'","line":1,"finding":"img element missing alt attribute; wcag-2-2 §1.3.1 §2.4.7 §4.1.2","suggested_fix":"add an alt attribute (use alt= for decorative images)"}' > "$EMIT"
    ;;
  *)
    echo "_runner: unknown agent: $AGENT" >&2
    exit 2
    ;;
esac

exit 0
