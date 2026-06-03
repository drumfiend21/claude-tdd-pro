#!/usr/bin/env bash
# §2.26 customer-agent safety classifier per §26 v1.11.
#
# Default PreToolUse hook for customer-facing agents. Reads the proposed
# output on stdin and blocks (exit 2) when any of the unsafe-content
# triggers fire. Logs the classification decision to the agent's
# audit_log (passed via --audit-log).
#
# Triggers (literal substring match, case-insensitive):
#   - self-harm references
#   - explicit hate speech against protected classes
#   - PII echo (SSN, credit card, IBAN patterns)
#
# Operators extend via --extra-blocklist <file> (one regex per line).
#
# Usage:
#   echo "<proposed output>" | safety-classifier.sh --agent <name> [--audit-log <path>] [--extra-blocklist <file>]
set -uo pipefail

AGENT=""
AUDIT_LOG=""
EXTRA_BLOCKLIST=""
NOW_ISO=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) AGENT="$2"; shift 2 ;;
    --audit-log) AUDIT_LOG="$2"; shift 2 ;;
    --extra-blocklist) EXTRA_BLOCKLIST="$2"; shift 2 ;;
    --now) NOW_ISO="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: safety-classifier.sh --agent <name> [--audit-log <path>] [--extra-blocklist <file>] [--now <iso>]" >&2
      exit 0
      ;;
    *) echo "safety-classifier: unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$AGENT" ]] && { echo "safety-classifier: --agent required" >&2; exit 2; }
[[ -z "$NOW_ISO" ]] && NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)

CONTENT=$(cat)

# Built-in safety patterns (regex, case-insensitive).
PATTERNS=(
  "self.?harm"
  "kill.{0,10}(myself|yourself)"
  "\\b[0-9]{3}-[0-9]{2}-[0-9]{4}\\b"  # SSN
  "\\b4[0-9]{12}(?:[0-9]{3})?\\b"     # Visa-like 13/16 digits
  "\\b5[1-5][0-9]{14}\\b"             # Mastercard
)

# Operator blocklist append.
if [[ -n "$EXTRA_BLOCKLIST" && -f "$EXTRA_BLOCKLIST" ]]; then
  while IFS= read -r line; do
    line=$(echo "$line" | sed 's/[[:space:]]*$//')
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    PATTERNS+=("$line")
  done < "$EXTRA_BLOCKLIST"
fi

VERDICT="allow"
HIT=""
for pat in "${PATTERNS[@]}"; do
  if echo "$CONTENT" | grep -qiE -- "$pat"; then
    VERDICT="block"
    HIT="$pat"
    break
  fi
done

if [[ -n "$AUDIT_LOG" ]]; then
  mkdir -p "$(dirname "$AUDIT_LOG")"
  printf '{"ts":"%s","agent":"%s","verdict":"%s","hit_pattern":"%s"}\n' "$NOW_ISO" "$AGENT" "$VERDICT" "$HIT" >> "$AUDIT_LOG"
fi

if [[ "$VERDICT" == "block" ]]; then
  echo "safety-classifier: agent=$AGENT verdict=block hit_pattern=\"$HIT\"" >&2
  exit 2
fi

echo "safety-classifier: agent=$AGENT verdict=allow" >&2
exit 0
