#!/usr/bin/env bash
# validate-eslint-compliance.sh — G-13 verification.
#
# Verifies every rule in a source-folder YAML file carries the full
# E-8 metadata set (per §2.1 rubric rule schema) and that the file
# could be expressed as an ESLint plugin's recommended config.
#
# Architecture: §17 G-13 in docs/architecture-v1.9.md.
#
# Usage:
#   bash validate-eslint-compliance.sh <path-to-source-file.yaml>
#   bash validate-eslint-compliance.sh <path-to-source-file.yaml> --emit-eslint-config
#
# Without --emit-eslint-config:
#   exit 0 → every rule has full E-8 metadata (success printed to stderr if a
#            caller appends && echo ok 1>&2)
#   exit 2 → one or more rules fail metadata checks (errors on stderr, one per line)
#   exit 1 → tooling error (file missing, ruby missing, parse failure)
#
# With --emit-eslint-config:
#   exit 0 → emits the ESLint-equivalent config as JSON to stderr.
#            Shape: { "rules": { "<rule-id>": "<severity-string>", ... } }.
#            severity mapping: P0 -> "error", P1 -> "warn", P2 -> "warn".
#   exit 2 → file fails metadata check; no config emitted.

set -uo pipefail

if [[ $# -lt 1 ]]; then
  echo "validate-eslint-compliance: usage: validate-eslint-compliance.sh <file.yaml> [--emit-eslint-config]" >&2
  exit 1
fi

SOURCE_FILE="$1"
EMIT_CONFIG=0
CHECK_DEPRECATION_WINDOW=0
PLUGIN_VERSION=""
RULE_DEPRECATED_SINCE=""
shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --emit-eslint-config) EMIT_CONFIG=1; shift ;;
    --check-deprecation-window) CHECK_DEPRECATION_WINDOW=1; shift ;;
    --plugin-version) PLUGIN_VERSION="$2"; shift 2 ;;
    --rule-deprecated-since) RULE_DEPRECATED_SINCE="$2"; shift 2 ;;
    *)
      echo "validate-eslint-compliance: unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

# E-10: --check-deprecation-window enforces "deprecated >=1 minor version
# before removal". Removal allowed only when plugin_version >=
# rule_deprecated_since's minor + 1.
if [[ "$CHECK_DEPRECATION_WINDOW" -eq 1 ]]; then
  PLUGIN_VERSION="$PLUGIN_VERSION" RULE_DEPRECATED_SINCE="$RULE_DEPRECATED_SINCE" node -e '
    const pv = (process.env.PLUGIN_VERSION || "0.0.0").split(".").map(Number);
    const rs = (process.env.RULE_DEPRECATED_SINCE || "0.0.0").split(".").map(Number);
    // Required minor delta: pv.minor must be >= rs.minor + 1 (when major equal).
    if (pv[0] === rs[0] && pv[1] < rs[1] + 1) {
      process.stderr.write(`deprecation window: rule deprecated since ${rs.join(".")} but plugin_version ${pv.join(".")} has not advanced by 1 minor version yet\n`);
      process.exit(2);
    }
    process.exit(0);
  '
  exit $?
fi

if [[ ! -f "$SOURCE_FILE" ]]; then
  echo "validate-eslint-compliance: file not found: $SOURCE_FILE" >&2
  exit 1
fi

if ! command -v ruby >/dev/null 2>&1; then
  echo "validate-eslint-compliance: ruby is required for YAML parsing" >&2
  exit 1
fi

ruby -ryaml -rjson -e '# coding: utf-8
  source_file = ARGV[0]
  emit_config = ARGV[1] == "1"

  # Pre-process YAML to quote URLs / ISO timestamps / sha hashes in flow-style
  # maps (Ruby 2.6 Psych chokes on unquoted colon-containing plain scalars in
  # inline maps). Input-side normalization only; semantic content preserved.
  raw = File.read(source_file)
  raw = raw.gsub(/(\burl:\s+)(https?:\/\/[^\s,\}]+)/, "\\1\"\\2\"")
  raw = raw.gsub(/(\bauthoritative_url:\s+)(https?:\/\/[^\s,\}]+)/, "\\1\"\\2\"")
  raw = raw.gsub(/(\bdocs_url:\s+)(https?:\/\/[^\s,\}]+)/, "\\1\"\\2\"")
  raw = raw.gsub(/(\bfetched_at:\s+)(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z?)/, "\\1\"\\2\"")
  raw = raw.gsub(/(\bcontent_hash:\s+)(sha256:[A-Za-z0-9_\-]+)/, "\\1\"\\2\"")

  begin
    data = YAML.load(raw)
  rescue => e
    STDERR.puts "validate-eslint-compliance: yaml parse error: #{e.message}"
    exit 1
  end

  rules = (data && data["rules"]) || []
  errors = []

  # Required E-8 metadata fields per §2.1 rubric rule schema. Order chosen to
  # surface the most diagnostic field first; reporting is field-name-keyed so
  # callers can grep regardless of order.
  REQUIRED_FIELDS = %w[
    id name description detector type fixable has_suggestions deprecated
    replaced_by docs_url requires_type_checking recommended options_schema
    messages severity version semver rule_state provenance
  ]

  TYPE_ENUM     = %w[problem suggestion layout]
  FIXABLE_ENUM  = ["code", "whitespace", nil]    # null permitted
  SEVERITY_MAP  = { "P0" => "error", "P1" => "warn", "P2" => "warn" }

  rules.each_with_index do |rule, idx|
    rule_id = (rule.is_a?(Hash) && rule["id"]) ? rule["id"] : "<index #{idx}>"

    unless rule.is_a?(Hash)
      errors << "rule[#{idx}]: must be a mapping"
      next
    end

    # Required-field presence checks
    REQUIRED_FIELDS.each do |field|
      unless rule.key?(field)
        errors << "rule #{rule_id}: field #{field} is required"
      end
    end

    # type ∈ enum (only check if present)
    if rule.key?("type") && !TYPE_ENUM.include?(rule["type"])
      errors << "rule #{rule_id}: type must be one of the enum [#{TYPE_ENUM.join(", ")}], got: #{rule["type"].inspect}"
    end

    # fixable ∈ {code, whitespace, null}
    if rule.key?("fixable") && !FIXABLE_ENUM.include?(rule["fixable"])
      errors << "rule #{rule_id}: fixable must be one of the enum [code, whitespace, null], got: #{rule["fixable"].inspect}"
    end

    # has_suggestions must be boolean
    if rule.key?("has_suggestions") && rule["has_suggestions"] != true && rule["has_suggestions"] != false
      errors << "rule #{rule_id}: has_suggestions must be boolean, got: #{rule["has_suggestions"].inspect}"
    end

    # replaced_by must be an array
    if rule.key?("replaced_by") && !rule["replaced_by"].is_a?(Array)
      errors << "rule #{rule_id}: replaced_by must be an array of rule ids, got: #{rule["replaced_by"].inspect}"
    end

    # docs_url must be https://
    if rule.key?("docs_url") && rule["docs_url"].is_a?(String) && !rule["docs_url"].start_with?("https://")
      errors << "rule #{rule_id}: docs_url must use https:// scheme (got: #{rule["docs_url"].inspect})"
    end

    # options_schema must be a valid JSON Schema (i.e. a hash/object — top-level
    # JSON Schema is always an object).
    if rule.key?("options_schema") && !rule["options_schema"].is_a?(Hash)
      errors << "rule #{rule_id}: options_schema must be a valid json schema object, got: #{rule["options_schema"].class}"
    end

    # messages must be a hash with at least one key (E-13 messageIds for i18n)
    if rule.key?("messages") && (!rule["messages"].is_a?(Hash) || rule["messages"].empty?)
      errors << "rule #{rule_id}: messages must be a non-empty mapping of messageId -> template"
    end
  end

  if !errors.empty?
    errors.each { |e| STDERR.puts e }
    exit 2
  end

  if emit_config
    out_rules = {}
    rules.each do |rule|
      sev_label = SEVERITY_MAP[rule["severity"]] || "warn"
      out_rules[rule["id"]] = sev_label
    end
    STDERR.puts JSON.pretty_generate({ "rules" => out_rules })
  end

  exit 0
' "$SOURCE_FILE" "$EMIT_CONFIG"
