#!/usr/bin/env bash
# §2.3 Subagent findings format validator. Validates a JSON array of
# findings per the §2.3 contract: each item must have severity, file,
# line, finding, suggested_fix. rule_id is optional (non-rule findings
# do not carry one).
#
# Usage:
#   bash validate-findings.sh --findings <path-to-findings.json>
#
# Exit codes:
#   0  valid
#   1  invalid
#   2  usage error

FINDINGS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --findings) FINDINGS="${2-}"; shift 2 ;;
    -h|--help) echo "Usage: validate-findings.sh --findings <path>" >&2; exit 0 ;;
    *) echo "validate-findings: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$FINDINGS" ]; then
  echo "validate-findings: --findings required" >&2
  exit 2
fi
if [ ! -f "$FINDINGS" ]; then
  echo "validate-findings: file not found: $FINDINGS" >&2
  exit 2
fi

FINDINGS_PATH="$FINDINGS" ruby - <<'RUBY'
require 'json'

path = ENV['FINDINGS_PATH'].to_s
begin
  data = JSON.parse(File.read(path))
rescue => e
  STDERR.write("validate-findings: parse error: #{e.message}\n")
  exit 1
end

unless data.is_a?(Array)
  STDERR.write("validate-findings: top-level must be an array\n")
  exit 1
end

REQUIRED = %w[severity file line finding suggested_fix].freeze

errors = []
data.each_with_index do |item, i|
  unless item.is_a?(Hash)
    errors << "finding[#{i}] is not an object"
    next
  end
  REQUIRED.each do |f|
    unless item.key?(f)
      errors << "missing required field: #{f} in finding[#{i}]"
    end
  end
end

STDERR.write("count=#{data.size}\n")

if errors.empty?
  STDERR.write("valid=true\n")
  exit 0
else
  errors.each { |e| STDERR.write("#{e}\n") }
  exit 1
end
RUBY
