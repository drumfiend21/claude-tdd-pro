#!/usr/bin/env bash
# /agent-verify — F-3 entry point per §16:
#   "/agent-verify <path> + agents/critical-path-verifier.md (opus);
#    .claude-tdd-pro/critical-paths.txt"
#
# Independent-verifier discipline (Karpathy/Cursor pattern): a separate
# Claude invocation reads the candidate diff and returns "verdict: agree"
# or "verdict: disagree <reason>". The verifier runs as its own process
# (distinct context window, no shared state with the editing instance);
# its verdict is appended to .claude-tdd-pro/agent-verify.jsonl and gates
# the commit.
#
# In production, --verifier-stub points at the agents/critical-path-
# verifier.md skill invocation. For testing, the stub is any executable
# that reads diff on stdin and emits "verdict: agree|disagree" on stdout.
#
# Usage:
#   agent-verify.sh --diff <path> --verifier-stub <path>
#
# Exit codes (per §2.2):
#   0 — verifier agreed; commit may proceed
#   1 — verifier disagreed; commit blocked
#   2 — usage error / empty diff / verifier missing or returned no verdict

set -uo pipefail

DIFF=""
VERIFIER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --diff) DIFF="$2"; shift 2 ;;
    --verifier-stub) VERIFIER="$2"; shift 2 ;;
    *) echo "agent-verify: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$DIFF" ]] && { echo "agent-verify: --diff <path> required" >&2; exit 2; }
[[ ! -f "$DIFF" ]] && { echo "agent-verify: diff not found: $DIFF" >&2; exit 2; }
[[ ! -s "$DIFF" ]] && { echo "agent-verify: empty diff at $DIFF (nothing to verify)" >&2; exit 2; }
[[ -z "$VERIFIER" ]] && { echo "agent-verify: --verifier-stub <path> required" >&2; exit 2; }
[[ ! -x "$VERIFIER" ]] && { echo "agent-verify: verifier not found or not executable: $VERIFIER" >&2; exit 2; }

# Run verifier in its own process (distinct Claude instance per F-3).
# Pipe diff to stdin; capture combined stdout+stderr so we can scan
# for the verdict line and surface verifier output to our stderr.
VERIFIER_OUT=$(< "$DIFF" "$VERIFIER" 2>&1)
VERIFIER_RC=$?

# Echo verifier output to our stderr so callers see verdict reasoning
# (and so the "verifier-instance-id" emission from the stub is visible).
echo "$VERIFIER_OUT" >&2

# Parse verdict line.
VERDICT=$(echo "$VERIFIER_OUT" | grep -E '^verdict:[[:space:]]*(agree|disagree)' | head -1 | sed -E 's/^verdict:[[:space:]]*//; s/[[:space:]]+$//')
if [[ -z "$VERDICT" ]]; then
  echo "agent-verify: verifier returned no \"verdict: agree|disagree\" line" >&2
  exit 2
fi

# Audit-log entry per F-3 audit-trail requirement: ISO8601 timestamp,
# sha256 of the diff, the verifier verdict, and any reason text.
mkdir -p .claude-tdd-pro
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
DIFF_SHA=$(shasum -a 256 "$DIFF" | awk '{print $1}')
REASON=$(echo "$VERIFIER_OUT" | grep -E '^reason:' | head -1 | sed -E 's/^reason:[[:space:]]*//')
TS="$TS" DIFF_SHA="$DIFF_SHA" VERDICT="$VERDICT" REASON="$REASON" node -e '
  const fs = require("fs");
  fs.appendFileSync(".claude-tdd-pro/agent-verify.jsonl",
    JSON.stringify({
      timestamp: process.env.TS,
      diff_sha256: process.env.DIFF_SHA,
      verdict: process.env.VERDICT,
      reason: process.env.REASON || ""
    }) + "\n");
'

case "$VERDICT" in
  agree) exit 0 ;;
  disagree) exit 1 ;;
esac
