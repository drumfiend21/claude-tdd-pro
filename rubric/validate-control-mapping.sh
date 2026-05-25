#!/usr/bin/env bash
# §2.9 control mapping validator. Validates compliance/controls.yaml
# entries against the §2.9 contract:
#   - framework: <id>
#     control_id: <id>
#     satisfied_by: [rubric_rule | hook | artifact]
#     legal_review_status: reviewed_by:<r>:<d> | pending | not-applicable
#
# CLI:
#   --controls PATH   controls YAML file (required)
#
# Exit codes:
#   0  valid
#   1  invalid
#   2  usage error

CONTROLS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --controls) CONTROLS="${2-}"; shift 2 ;;
    -h|--help) echo "Usage: validate-control-mapping.sh --controls <path>" >&2; exit 0 ;;
    *) echo "validate-control-mapping: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$CONTROLS" ]; then echo "validate-control-mapping: --controls required" >&2; exit 2; fi
if [ ! -f "$CONTROLS" ]; then echo "validate-control-mapping: file not found: $CONTROLS" >&2; exit 2; fi

CONTROLS_PATH="$CONTROLS" ruby - <<'RUBY'
require 'yaml'

begin
  data = YAML.unsafe_load_file(ENV['CONTROLS_PATH']) || []
rescue => e
  STDERR.write("validate-control-mapping: yaml parse error: #{e.message}\n")
  exit 1
end

unless data.is_a?(Array)
  STDERR.write("validate-control-mapping: top-level must be an array of control entries\n")
  exit 1
end

REQUIRED = %w[framework control_id satisfied_by legal_review_status].freeze
VALID_SATISFIED_BY = %w[rubric_rule hook artifact].freeze

errors = []
data.each_with_index do |entry, i|
  unless entry.is_a?(Hash)
    errors << "entry[#{i}] is not an object"
    next
  end
  REQUIRED.each do |f|
    errors << "missing required field: #{f} in entry[#{i}]" unless entry.key?(f)
  end
  if entry.key?('satisfied_by')
    sb = entry['satisfied_by']
    unless sb.is_a?(Array)
      errors << "satisfied_by must be an array in entry[#{i}]"
    else
      sb.each do |v|
        unless VALID_SATISFIED_BY.include?(v)
          errors << "satisfied_by value \"#{v}\" not in [rubric_rule|hook|artifact] for entry[#{i}]"
        end
      end
    end
  end
  if entry.key?('legal_review_status')
    v = entry['legal_review_status'].to_s
    valid = (v == 'pending' || v == 'not-applicable' || v.start_with?('reviewed_by:'))
    unless valid
      errors << "legal_review_status \"#{v}\" not in [reviewed_by:<r>:<d>|pending|not-applicable] for entry[#{i}]"
    end
  end
end

if errors.empty?
  STDERR.write("valid=true count=#{data.size}\n")
  exit 0
else
  errors.each { |e| STDERR.write("#{e}\n") }
  exit 1
end
RUBY
