#!/usr/bin/env bash
# validate-rubric-rule — validate a single rubric-rule YAML file against
# the v1.9 rubric rule JSON Schema (schemas/rubric-rule.schema.json).
#
# Usage:
#   bash validate-rubric-rule.sh <path-to-rule.yaml>
#
# Per detector contract §2.2:
#   exit 0 → valid
#   exit 2 → invalid (errors written to stderr, one per line)
#   exit 1 → tooling error (file missing, parse failure, ruby/node missing)
#
# Implementation:
#   1. Convert YAML to JSON via Ruby (stdlib).
#   2. Validate against schema via Node + lib/validate-json-schema.js.

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
SCHEMA="$PLUGIN_ROOT/schemas/rubric-rule.schema.json"
VALIDATOR="$PLUGIN_ROOT/rubric/detectors/lib/validate-json-schema.js"

if [[ $# -ne 1 ]]; then
  echo "validate-rubric-rule: usage: validate-rubric-rule.sh <path-to-rule.yaml>" >&2
  exit 1
fi

RULE_YAML="$1"

if [[ ! -f "$RULE_YAML" ]]; then
  echo "validate-rubric-rule: file not found: $RULE_YAML" >&2
  exit 1
fi

if ! command -v ruby >/dev/null 2>&1; then
  echo "validate-rubric-rule: ruby is required for YAML parsing" >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "validate-rubric-rule: node is required for schema validation" >&2
  exit 1
fi

if [[ ! -f "$SCHEMA" ]]; then
  echo "validate-rubric-rule: schema not found: $SCHEMA" >&2
  exit 1
fi

if [[ ! -f "$VALIDATOR" ]]; then
  echo "validate-rubric-rule: validator not found: $VALIDATOR" >&2
  exit 1
fi

# YAML → JSON via Ruby. Use ARGV to avoid quoting issues with paths.
RULE_JSON=$(ruby -ryaml -rjson -e '
  begin
    data = YAML.unsafe_load_file(ARGV[0])
    puts JSON.generate(data)
  rescue => e
    STDERR.puts "validate-rubric-rule: yaml parse error: #{e.message}"
    exit 1
  end
' "$RULE_YAML")

if [[ -z "$RULE_JSON" ]]; then
  echo "validate-rubric-rule: empty JSON output from YAML conversion" >&2
  exit 1
fi

# Schema validation via Node
echo "$RULE_JSON" | node "$VALIDATOR" "$SCHEMA"
exit $?
