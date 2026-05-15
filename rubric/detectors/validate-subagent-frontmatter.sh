#!/usr/bin/env bash
# validate-subagent-frontmatter.sh — C-11 substrate. Validates a
# subagent .md file's YAML frontmatter against §2.3 + per-spec
# constraints.
#
# Usage:
#   validate-subagent-frontmatter.sh <agent.md> --field <name> [--present]
#                                                 [--non-empty] [--equals <value>]
#                                                 [--enum]

set -uo pipefail

AGENT="${1:-}"
shift || true

FIELD=""
PRESENT=0
NON_EMPTY=0
EQUALS=""
ENUM=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --field) FIELD="$2"; shift 2 ;;
    --present) PRESENT=1; shift ;;
    --non-empty) NON_EMPTY=1; shift ;;
    --equals) EQUALS="$2"; shift 2 ;;
    --enum) ENUM=1; shift ;;
    *) shift ;;
  esac
done

if [[ -z "$AGENT" || ! -f "$AGENT" ]]; then
  echo "validate-subagent-frontmatter: agent file not found: $AGENT" >&2
  exit 2
fi

if [[ -z "$FIELD" ]]; then
  echo "validate-subagent-frontmatter: --field <name> required" >&2
  exit 2
fi

VALUE=$(awk -v field="$FIELD" '
  /^---$/ { fm = !fm; next }
  fm && $0 ~ "^"field":" {
    sub("^"field":[[:space:]]*", "")
    print
    exit
  }
' "$AGENT")

if [[ "$PRESENT" -eq 1 && -z "$VALUE" ]]; then
  echo "validate-subagent-frontmatter: $AGENT field $FIELD: missing or empty" >&2
  exit 2
fi

if [[ "$NON_EMPTY" -eq 1 && -z "$VALUE" ]]; then
  echo "validate-subagent-frontmatter: $AGENT field $FIELD: must be non-empty" >&2
  exit 2
fi

if [[ -n "$EQUALS" && "$VALUE" != "$EQUALS" ]]; then
  echo "validate-subagent-frontmatter: $AGENT field $FIELD: expected '$EQUALS', got '$VALUE'" >&2
  exit 2
fi

if [[ "$ENUM" -eq 1 ]]; then
  case "$FIELD" in
    prompt_migration_status)
      case "$VALUE" in
        original|migrated-zero-delta|migrated-with-delta:*) ;;
        *)
          echo "validate-subagent-frontmatter: $AGENT field prompt_migration_status: value '$VALUE' not in enum [original, migrated-zero-delta, migrated-with-delta:<reason>]" >&2
          exit 2
          ;;
      esac
      ;;
    model)
      case "$VALUE" in
        sonnet|opus|haiku) ;;
        *)
          echo "validate-subagent-frontmatter: $AGENT field model: value '$VALUE' not in enum [sonnet, opus, haiku]" >&2
          exit 2
          ;;
      esac
      ;;
    *)
      echo "validate-subagent-frontmatter: --enum check not supported for field $FIELD" >&2
      exit 2
      ;;
  esac
fi

echo "validate-subagent-frontmatter: $AGENT field $FIELD ok (value='$VALUE')" >&2
exit 0
