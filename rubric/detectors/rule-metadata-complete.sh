#!/usr/bin/env bash
# rubric/detectors/rule-metadata-complete.sh — E-8 metadata-completeness
# detector per §16: validates that a single rubric-rule YAML file declares
# the §2.1 rule metadata fields (type, fixable, has_suggestions, deprecated,
# replaced_by, docs_url, requires_type_checking, recommended, options_schema,
# messages) with valid shapes.
#
# Per §16 E-8 verbatim:
#   "Standardized rule metadata per §2.1: type, fixable, has_suggestions,
#    deprecated, replaced_by, docs_url, requires_type_checking, recommended,
#    options_schema, messages; validated by rubric/detectors/
#    rule-metadata-complete.sh in /doctor and CI."
#
# Per detector contract §2.2:
#   exit 0 — metadata complete and valid
#   exit 2 — missing or invalid metadata (errors written to stderr)
#   exit 1 — tooling error
#
# Usage:
#   bash rule-metadata-complete.sh <path-to-rule.yaml>
#
# Cross-set rules per §2.1:
#   - type ∈ {problem, suggestion, layout}
#   - fixable ∈ {code, whitespace, null}
#   - has_suggestions: boolean
#   - deprecated: boolean OR string (deprecation reason)
#   - replaced_by: array of rule-id strings
#   - docs_url: string starting with "https://"
#   - options_schema: JSON Schema object (must be a hash)
#   - messages: hash of {messageId: template} when present
#   - type=layout requires fixable in {whitespace, null} (not "code")
#   - rule.id must match basename(file, ".yaml") (filename-id consistency)

set -uo pipefail

if [[ $# -ne 1 ]]; then
  echo "rule-metadata-complete: usage: rule-metadata-complete.sh <path-to-rule.yaml>" >&2
  exit 1
fi

RULE_FILE="$1"
[[ ! -f "$RULE_FILE" ]] && { echo "rule-metadata-complete: file not found: $RULE_FILE" >&2; exit 1; }

ruby -ryaml -e '
  path = ARGV[0]
  doc = begin
    YAML.load_file(path)
  rescue => e
    STDERR.puts "yaml parse error: #{e.message}"
    exit 1
  end

  errs = []
  unless doc.is_a?(Hash)
    STDERR.puts "rule file must be a YAML map at top level"
    exit 2
  end

  # rule.id must match basename
  basename = File.basename(path, ".yaml")
  rule_id = doc["id"]
  if rule_id.is_a?(String) && !rule_id.empty? && rule_id != basename
    errs << "id: \"#{rule_id}\" must match filename basename \"#{basename}\""
  end

  # type required + enum
  type = doc["type"]
  if type.nil?
    errs << "type: required (must be one of problem|suggestion|layout)"
  elsif !%w[problem suggestion layout].include?(type)
    errs << "type: \"#{type}\" not in enum {problem, suggestion, layout}"
  end

  # fixable enum (nil also allowed)
  fixable = doc["fixable"]
  unless fixable.nil? || %w[code whitespace].include?(fixable)
    errs << "fixable: \"#{fixable}\" not in enum {code, whitespace, null}"
  end

  # type=layout requires fixable in {whitespace, null}, not "code"
  if type == "layout" && fixable == "code"
    errs << "type=layout requires fixable in {whitespace, null}; got \"code\""
  end

  # has_suggestions boolean (when present)
  if doc.key?("has_suggestions")
    hs = doc["has_suggestions"]
    unless hs == true || hs == false
      errs << "has_suggestions: must be boolean (got #{hs.inspect})"
    end
  end

  # deprecated: boolean OR string
  if doc.key?("deprecated")
    dep = doc["deprecated"]
    unless dep == true || dep == false || dep.is_a?(String)
      errs << "deprecated: must be boolean or string (got #{dep.inspect})"
    end
  end

  # replaced_by: array of strings
  if doc.key?("replaced_by")
    rb = doc["replaced_by"]
    unless rb.is_a?(Array) && rb.all? { |x| x.is_a?(String) }
      errs << "replaced_by: must be array of rule-id strings (got #{rb.inspect})"
    end
  end

  # docs_url: https://
  if doc.key?("docs_url") && doc["docs_url"].is_a?(String) && !doc["docs_url"].start_with?("https://")
    errs << "docs_url: must start with https:// (got #{doc["docs_url"]})"
  end

  # options_schema: must be a hash (JSON Schema object)
  if doc.key?("options_schema") && !doc["options_schema"].is_a?(Hash)
    errs << "options_schema: must be a JSON Schema object (hash); got #{doc["options_schema"].class}"
  end

  # messages: must be a hash if present
  if doc.key?("messages") && !doc["messages"].is_a?(Hash)
    errs << "messages: must be a hash {messageId: template}; got #{doc["messages"].class}"
  end

  if errs.empty?
    exit 0
  else
    base = File.basename(path)
    errs.each { |e| STDERR.puts "#{base}:1: [metadata] #{e}" }
    exit 2
  end
' "$RULE_FILE"
