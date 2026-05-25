#!/usr/bin/env bash
# §2.1 rubric rule schema contract validator. Validates a single rule given
# as a JSON document against the §2.1 contract. Distinct from
# rubric/detectors/validate-rubric-rule.sh (which validates a YAML rule file
# via the full schemas/rubric-rule.schema.json JSON-Schema doc and is
# detector-contract-shaped per §2.2). This validator is the
# cross-cutting-contract surface used by tooling that needs a focused
# pass/fail + key=value telemetry on the §2.1 schema slice.
#
# CLI surface:
#   --rule PATH            JSON rule file (required)
#   --check MODE           subcheck mode: provenance | legal-review
#   --emit json            emit a structured json record
#   --out PATH             output path for --emit json
#
# Exit codes:
#   0  validation passed
#   1  validation failed
#   2  usage error / bad input

RULE=""
CHECK=""
EMIT=""
OUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --rule)  RULE="${2-}";  shift 2 ;;
    --check) CHECK="${2-}"; shift 2 ;;
    --emit)  EMIT="${2-}";  shift 2 ;;
    --out)   OUT="${2-}";   shift 2 ;;
    -h|--help)
      echo "Usage: validate-rule-schema.sh --rule <path> [--check <mode>] [--emit json --out <path>]" >&2
      exit 0
      ;;
    *)
      echo "validate-rule-schema: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

if [ -z "$RULE" ]; then
  echo "validate-rule-schema: --rule required" >&2
  exit 2
fi
if [ ! -f "$RULE" ]; then
  echo "validate-rule-schema: rule file not found: $RULE" >&2
  exit 2
fi

RULE_PATH="$RULE" CHECK_MODE="$CHECK" EMIT_MODE="$EMIT" OUT_PATH="$OUT" ruby - <<'RUBY'
require 'json'

rule_path = ENV['RULE_PATH'].to_s
check     = ENV['CHECK_MODE'].to_s
emit      = ENV['EMIT_MODE'].to_s
out_path  = ENV['OUT_PATH'].to_s

begin
  rule = JSON.parse(File.read(rule_path))
rescue => e
  STDERR.write("validate-rule-schema: parse error: #{e.message}\n")
  exit 1
end

def emit_err(line)
  STDERR.write("#{line}\n")
end

# Subchecks
if check == 'provenance'
  prov = rule['provenance'] || []
  emit_err("provenance_count=#{prov.size}")
  exit 0

elsif check == 'legal-review'
  lr = rule['legal_review_status']
  if lr.is_a?(Hash)
    emit_err("legal_review_status_present=true")
    emit_err("frameworks_with_status=#{lr.size}")
  else
    emit_err("legal_review_status_present=false")
    emit_err("frameworks_with_status=0")
  end
  exit 0
end

# Full validation: id strictly required; other §2.1 fields validated as
# enums *if present*. This matches the contract specs which assert
# behavior on the slice they pass in (e.g. rejecting severity=P9 without
# requiring semver or rule_state at the same time).
errors = []

unless rule['id'].is_a?(String) && !rule['id'].empty?
  errors << "missing required field: id"
end

VALID_SEVERITY = %w[P0 P1 P2].freeze
VALID_TYPE     = %w[problem suggestion layout].freeze
VALID_FIXABLE  = ['code', 'whitespace', nil].freeze
VALID_RULE_STATE = %w[warn-only block disabled].freeze
SEMVER_RX      = /\A\d+\.\d+\.\d+\z/

if rule.key?('severity') && !VALID_SEVERITY.include?(rule['severity'])
  errors << "invalid_severity=#{rule['severity']}"
  errors << "allowed=P0|P1|P2"
end

if rule.key?('type') && !VALID_TYPE.include?(rule['type'])
  errors << "invalid_type=#{rule['type']}"
  errors << "allowed=problem|suggestion|layout"
end

if rule.key?('fixable') && !VALID_FIXABLE.include?(rule['fixable'])
  errors << "invalid_fixable=#{rule['fixable']}"
  errors << "allowed=code|whitespace|null"
end

if rule.key?('rule_state') && !VALID_RULE_STATE.include?(rule['rule_state'])
  errors << "invalid_rule_state=#{rule['rule_state']}"
  errors << "allowed=warn-only|block|disabled"
end

if rule.key?('semver') && !(rule['semver'].is_a?(String) && rule['semver'] =~ SEMVER_RX)
  errors << "invalid_semver=#{rule['semver']}"
end

valid = errors.empty?

if emit == 'json' && !out_path.empty?
  result = {
    "valid"   => valid,
    "rule_id" => rule['id'],
    "errors"  => errors,
  }
  File.write(out_path, JSON.generate(result))
end

errors.each { |e| emit_err(e) }
emit_err("valid=#{valid}")
exit(valid ? 0 : 1)
RUBY
