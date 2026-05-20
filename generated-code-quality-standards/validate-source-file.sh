#!/usr/bin/env bash
# validate-source-file (architecture-named entry point per §17 G-6).
#
# Per §17 G-6 verbatim:
#   "Source-file schema per §2.21 contract;
#    generated-code-quality-standards/validate-source-file.sh."
#
# Wrapper that delegates to the substrate validator at
# rubric/detectors/validate-source-file.sh. The substrate predates the
# G-phase architecture; full path consolidation is tracked under §23.7
# substrate reconciliation.

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"

# G-8 --file <path> --check id-prefix mode: verify every rule id in an
# _operator/<org>/ file is prefixed with the org name (per §2.22 operator
# namespacing contract).
FILE=""; CHECK=""
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) FILE="$2"; shift 2 ;;
    --check) CHECK="$2"; shift 2 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

if [[ -n "$CHECK" && "$CHECK" == "id-prefix" ]]; then
  [[ -z "$FILE" || ! -f "$FILE" ]] && { echo "validate-source-file: --file <path> required for --check id-prefix" >&2; exit 2; }
  ORG=$(echo "$FILE" | sed -E 's|.*_operator/([^/]+)/.*|\1|')
  IDS=$(grep -E '^[[:space:]]*-[[:space:]]*id:' "$FILE" | sed -E 's/.*id:[[:space:]]*//' | tr -d ' ')
  ALL_OK=true
  for rid in $IDS; do
    case "$rid" in
      "$ORG"-*|"$ORG"/*) : ;;
      *) ALL_OK=false; echo "validate-source-file: rule id=$rid lacks org prefix '$ORG-' in operator namespace" >&2 ;;
    esac
  done
  if [[ "$ALL_OK" == "true" ]]; then
    echo "validate-source-file: all_rules_have_org_prefix=true file=$FILE org=$ORG" >&2
    exit 0
  fi
  exit 1
fi

# --file <path> mode (no --check): minimal structural check (source: + rules:
# present). Used by G-11 to sanity-check copied _community plugin namespaces
# without requiring full shipped-source schema conformance.
if [[ -n "$FILE" ]]; then
  [[ ! -f "$FILE" ]] && { echo "validate-source-file: file not found: $FILE" >&2; exit 2; }
  if grep -qE "^source:" "$FILE" && grep -qE "^rules:" "$FILE"; then
    echo "validate-source-file: valid=true file=$FILE (minimal structural: source: + rules: present)" >&2
    exit 0
  fi
  echo "validate-source-file: valid=false file=$FILE (missing source: or rules:)" >&2
  exit 1
fi

# Positional-path mode: delegate to substrate validator for full schema check.
set +u
exec bash "$PLUGIN_ROOT/rubric/detectors/validate-source-file.sh" "${ARGS[@]}"
