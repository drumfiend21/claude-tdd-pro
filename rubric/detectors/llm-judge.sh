#!/usr/bin/env bash
# AI-native detector: LLM-as-judge for code quality rules.
#
# Replaces per-rule grep with a single LLM call. Reads:
#   - the code at $TARGET
#   - the rule text at $RULE
#   - the rule's source citation
# Asks the model: "Does this code satisfy this rule? Justify."
# Emits a JSON finding the runner can consume.
#
# Per the simulated Musk-team review (Igor Babuschkin):
#   "The architects of the system used the most powerful tool
#    available; the system they built uses 1970s tools. Pick one
#    detector. Replace it with a single Grok or Claude call."
#
# This is the proof-of-concept. Once measured side-by-side against
# the grep-based detectors and shown to match or exceed at lower
# maintenance cost, the runner becomes a coordinator of LLM
# judgments, not a grep dispatcher.
#
# Usage:
#   llm-judge.sh --target <file> --rule <rule-id> [--model <name>]
#                [--dry-run] [--explain]
#
# Models supported (auto-detect order):
#   1. `claude` CLI (Anthropic SDK CLI) if on PATH
#   2. `grok` CLI (xAI) if on PATH
#   3. fallback to a heuristic — equivalent to skipping in grep mode
#
# Exit codes:
#   0 — code satisfies the rule (no finding)
#   1 — code violates the rule (finding emitted on stdout as JSON)
#   2 — usage error
#   3 — model unavailable (degraded mode)

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
TARGET=""
TEXT_INLINE=""
RULE_ID=""
MODEL=""
DRY_RUN=0
EXPLAIN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --text) TEXT_INLINE="$2"; shift 2 ;;   # P-8 fix: judge inline prose (prose-judge.sh tier-2)
    --rule) RULE_ID="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --explain) EXPLAIN=1; shift ;;
    -h|--help)
      cat >&2 <<USAGE
Usage: llm-judge.sh (--target <file> | --text <prose>) --rule <rule-id>
                    [--model claude|grok|auto]
                    [--dry-run] [--explain]

LLM-as-judge replacement for per-rule grep detectors. Reads the
rule from generated-code-quality-standards/ and asks the model
whether the target satisfies it.

Exit codes:
  0 satisfies | 1 violates | 2 usage | 3 model unavailable
USAGE
      exit 0 ;;
    *) echo "llm-judge: unknown arg: $1" >&2; exit 2 ;;
  esac
done

# P-8 fix: --text materializes inline prose into a tempfile so all downstream $TARGET
# logic (prompt, model dispatch, messages) works unchanged. prose-judge.sh tier-2 passes
# a prose section here; the temp is cleaned on exit.
if [[ -n "$TEXT_INLINE" ]]; then
  TARGET=$(mktemp "${TMPDIR:-/tmp}/llm-judge-text.XXXXXX") || { echo "llm-judge: mktemp failed" >&2; exit 2; }
  trap 'rm -f "$TARGET"' EXIT
  printf '%s' "$TEXT_INLINE" > "$TARGET"
fi

[[ -z "$TARGET" || -z "$RULE_ID" ]] && {
  echo "llm-judge: (--target | --text) + --rule required" >&2; exit 2;
}
[[ -f "$TARGET" ]] || { echo "llm-judge: target not found: $TARGET" >&2; exit 2; }

# Resolve the rule text from the source-namespace tree.
rule_file=$(grep -rl --include="*.yaml" -E "^[[:space:]]*-?[[:space:]]*id:[[:space:]]*${RULE_ID}\$" \
  "$PLUGIN_ROOT/generated-code-quality-standards/" 2>/dev/null | head -1)
if [[ -z "$rule_file" ]]; then
  echo "llm-judge: rule not found in standards tree: $RULE_ID" >&2
  exit 2
fi

# Extract the rule block (id + name + description + remediation).
rule_text=$(awk -v id="$RULE_ID" '
  /^[[:space:]]*-?[[:space:]]*id:[[:space:]]*/ {
    in_match = ($0 ~ "id:[[:space:]]*"id"[[:space:]]*$")
    if (in_match) blk = $0
    else if (blk != "") exit
    next
  }
  { if (in_match) blk = blk "\n" $0 }
  END { print blk }
' "$rule_file")

# Auto-detect the model command.
if [[ -z "$MODEL" || "$MODEL" == "auto" ]]; then
  if command -v claude >/dev/null 2>&1; then MODEL="claude"
  elif command -v grok >/dev/null 2>&1; then MODEL="grok"
  else MODEL="unavailable"
  fi
fi

# Compose the prompt.
prompt=$(cat <<EOF
You are a code quality reviewer applying a specific rule from a
published engineering standard.

Rule (from $rule_file):
\`\`\`yaml
$rule_text
\`\`\`

Code under review (from $TARGET):
\`\`\`
$(cat "$TARGET")
\`\`\`

Question: Does the code satisfy this rule?

Respond in JSON only:
{
  "verdict": "satisfies" | "violates",
  "confidence": 0.0..1.0,
  "justification": "<one sentence citing the specific code location and the rule clause>",
  "suggested_fix": "<one sentence describing what to change, or null>"
}
EOF
)

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "llm-judge: dry-run; would invoke model=$MODEL on rule=$RULE_ID target=$TARGET" >&2
  [[ "$EXPLAIN" -eq 1 ]] && echo "$prompt" >&2
  exit 0
fi

case "$MODEL" in
  claude)
    response=$(printf '%s' "$prompt" | claude --no-stream -p 2>&1 || true)
    ;;
  grok)
    response=$(printf '%s' "$prompt" | grok -p 2>&1 || true)
    ;;
  unavailable)
    echo "llm-judge: no model CLI on PATH (tried: claude, grok). Skipping rule $RULE_ID (degraded mode)." >&2
    exit 3
    ;;
  *)
    echo "llm-judge: unknown model: $MODEL" >&2; exit 2 ;;
esac

# Parse the JSON response.
verdict=$(echo "$response" | node -e '
  const raw = require("fs").readFileSync(0, "utf8");
  const m = raw.match(/\{[\s\S]*?"verdict"[\s\S]*?\}/);
  if (!m) { process.stderr.write("llm-judge: model did not return JSON\n"); process.exit(0); }
  try {
    const j = JSON.parse(m[0]);
    process.stdout.write(j.verdict || "");
  } catch { process.exit(0); }
' 2>/dev/null)

if [[ "$verdict" == "satisfies" ]]; then
  exit 0
elif [[ "$verdict" == "violates" ]]; then
  # Emit finding as JSON on stdout (runner-consumable).
  echo "$response" | node -e '
    const raw = require("fs").readFileSync(0, "utf8");
    const m = raw.match(/\{[\s\S]*?\}/);
    if (m) try {
      const j = JSON.parse(m[0]);
      process.stdout.write(JSON.stringify({
        rule_id: process.env.RULE_ID,
        file: process.env.TARGET,
        verdict: j.verdict,
        confidence: j.confidence,
        justification: j.justification,
        suggested_fix: j.suggested_fix,
        source: "llm-judge",
        model: process.env.MODEL,
      }) + "\n");
    } catch {}
  ' RULE_ID="$RULE_ID" TARGET="$TARGET" MODEL="$MODEL" 2>/dev/null
  exit 1
else
  echo "llm-judge: indeterminate verdict on rule $RULE_ID target $TARGET" >&2
  exit 3
fi
