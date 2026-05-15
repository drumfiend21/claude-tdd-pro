#!/usr/bin/env bash
# validate-risk-classification-yaml.sh — C-8 substrate. Validates a
# compliance/risk-classification.yaml against the §16 C-8 schema.
#
# Required fields: use_case, classification, source_framework, obligations.
# classification enum: prohibited | high | limited | minimal.

set -uo pipefail

YAML="${1:-}"
if [[ -z "$YAML" || ! -f "$YAML" ]]; then
  echo "validate-risk-classification-yaml: file not found: $YAML" >&2
  exit 2
fi

YAML="$YAML" LANG="${LANG:-en_US.UTF-8}" ruby -ryaml -e '# coding: utf-8
Encoding.default_external = Encoding::UTF_8
yaml_path = ENV["YAML"]
begin
  data = YAML.load_file(yaml_path)
rescue => e
  STDERR.puts "validate-risk-classification-yaml: parse error: #{e.message}"
  exit 2
end

unless data.is_a?(Hash)
  STDERR.puts "validate-risk-classification-yaml: root must be a mapping"
  exit 2
end

VALID_CLASS = %w[prohibited high limited minimal]
required = %w[use_case classification source_framework obligations]
errors = []

required.each do |k|
  errors << "missing required field: #{k}" unless data.key?(k)
end

if data["classification"] && !VALID_CLASS.include?(data["classification"])
  errors << "classification must be one of [#{VALID_CLASS.join(", ")}], got: #{data["classification"]}"
end

if data["source_framework"] && data["source_framework"] != "eu-ai-act"
  errors << "source_framework must be eu-ai-act, got: #{data["source_framework"]}"
end

if data["obligations"] && !data["obligations"].is_a?(Array)
  errors << "obligations must be an array (got: #{data["obligations"].class})"
end

if errors.any?
  errors.each { |e| STDERR.puts "validate-risk-classification-yaml: #{e}" }
  exit 2
end

STDERR.puts "validate-risk-classification-yaml: ok (use_case=#{data["use_case"]} class=#{data["classification"]})"
exit 0
'
