#!/usr/bin/env bash
# standards/validate-fetch-frequency.sh — §2.28 configurable-frequency
# in-use polling contract: validates a fetch_frequency value against the
# cadence grammar that is shared, symmetrically, across the §2.6 standards,
# §2.12 PR-corpus, and §2.19 compliance two-tier registries.
#
# The grammar itself lives in lib/fetch-frequency-grammar.sh (the single
# source of truth also used by standards/poll-scheduler.sh / S-20), so the
# contract validator and the scheduler can never disagree on what is valid.
#
# CLI:
#   --value <cadence>     the fetch_frequency value to validate (may be empty)
#   --registry <name>     optional: standards | pr-corpus | compliance
#                         (asserts the grammar applies to that registry)
#
# stderr report tokens:
#   valid=true class=<calendar|subday|manual|any-frequency>
#     resolved=<token> interval_ms=<N>
#   default_applied=true          (when the value was unset/empty -> daily)
#   valid=false invalid_cadence=<value>
#   registry=<name>
#
# Exit codes: 0 valid / 2 invalid cadence or usage error.

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
# shellcheck disable=SC1091
. "$PLUGIN_ROOT/lib/fetch-frequency-grammar.sh"

VALUE=""
VALUE_SET=0
REGISTRY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --value)    VALUE="${2-}"; VALUE_SET=1; shift 2 ;;
    --registry) REGISTRY="${2-}";           shift 2 ;;
    -h|--help)
      echo "Usage: validate-fetch-frequency.sh --value <cadence> [--registry standards|pr-corpus|compliance]" >&2
      exit 0
      ;;
    *) echo "validate-fetch-frequency: unknown arg: $1" >&2; exit 2 ;;
  esac
done

# §2.28 applies symmetrically to the three two-tier registries.
if [ -n "$REGISTRY" ]; then
  case "$REGISTRY" in
    standards|pr-corpus|compliance) echo "registry=$REGISTRY" >&2 ;;
    *) echo "validate-fetch-frequency: unknown registry: $REGISTRY (expected standards|pr-corpus|compliance)" >&2; exit 2 ;;
  esac
fi

# An unset/empty value applies the daily default (§2.28).
default_applied=0
if [ "$VALUE_SET" -eq 0 ] || [ -z "$VALUE" ]; then
  default_applied=1
fi

if ! parsed=$(ff_resolve_cadence "$VALUE"); then
  echo "valid=false invalid_cadence=$VALUE" >&2
  exit 2
fi

# Split "<interval_ms> <resolved_token> <class>" without arrays.
set -- $parsed
interval_ms="$1"
resolved="$2"
class="$3"

echo "valid=true class=$class resolved=$resolved interval_ms=$interval_ms" >&2
if [ "$default_applied" -eq 1 ]; then
  echo "default_applied=true" >&2
fi

exit 0
