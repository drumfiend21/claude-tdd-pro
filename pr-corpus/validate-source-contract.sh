#!/usr/bin/env bash
# §2.12 PR source contract validator. Validates two-tier PR-SOURCES
# files: operator-facing (.claude-tdd-pro/PR-SOURCES.yaml) and
# plugin-internal (pr-corpus/sources/<name>.yaml). Mode auto-detected
# from --registry path basename or --tier flag.
#
# Operator-facing required fields per §2.12: id, name, github,
#   tier (1|2), source_class, applies_to, fetch_frequency.
# Plugin-internal adds: authority_tier, fragility_tier (high|medium|low),
#   local_llm_eligible, filters, budget, attribution.
# github format: <org>/<repo>.
# source_class enum: federal-financial-regulator | fedramp-high |
#   federal-digital-services | federal-infrastructure |
#   financial-industry | financial-industry-consortium |
#   gold-standard-process.
#
# CLI:
#   --registry PATH   YAML file (required)
#   --tier MODE       operator | plugin-internal (auto-detected if omitted)
#   --emit json       emit structured JSON
#   --out PATH        output for --emit json

REG=""
TIER=""
EMIT=""
OUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --registry) REG="${2-}"; shift 2 ;;
    --tier)     TIER="${2-}"; shift 2 ;;
    --emit)     EMIT="${2-}"; shift 2 ;;
    --out)      OUT="${2-}"; shift 2 ;;
    -h|--help) echo "Usage: validate-source-contract.sh --registry <path> [--tier operator|plugin-internal] [--emit json --out <path>]" >&2; exit 0 ;;
    *) echo "validate-source-contract: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$REG" ]; then echo "validate-source-contract: --registry required" >&2; exit 2; fi
if [ ! -f "$REG" ]; then echo "validate-source-contract: file not found: $REG" >&2; exit 2; fi

if [ -z "$TIER" ]; then
  case "$REG" in
    *PR-SOURCES.yaml) TIER="operator" ;;
    *pr-corpus/sources/*) TIER="plugin-internal" ;;
    *) TIER="operator" ;;
  esac
fi
# Accept short tier alias.
case "$TIER" in
  plugin) TIER="plugin-internal" ;;
esac

REG_PATH="$REG" TIER_MODE="$TIER" EMIT_MODE="$EMIT" OUT_PATH="$OUT" ruby - <<'RUBY'
require 'yaml'
require 'json'

begin
  data = YAML.unsafe_load_file(ENV['REG_PATH']) || {}
rescue => e
  STDERR.write("validate-source-contract: yaml parse error: #{e.message}\n")
  exit 1
end

sources = data.is_a?(Hash) ? (data['sources'] || []) : []
tier     = ENV['TIER_MODE'].to_s
emit     = ENV['EMIT_MODE'].to_s
out_path = ENV['OUT_PATH'].to_s

OPERATOR_REQUIRED = %w[id name github tier source_class applies_to fetch_frequency].freeze
PLUGIN_INTERNAL_ADDITIONAL = %w[authority_tier fragility_tier local_llm_eligible filters budget attribution].freeze
VALID_SOURCE_CLASS = %w[
  federal-financial-regulator fedramp-high federal-digital-services
  federal-infrastructure financial-industry financial-industry-consortium
  gold-standard-process
].freeze
VALID_FRAGILITY_TIER = %w[high medium low].freeze
GITHUB_RX = %r{\A[A-Za-z0-9][A-Za-z0-9._\-]*/[A-Za-z0-9._\-]+\z}

errors = []

sources.each_with_index do |s, i|
  unless s.is_a?(Hash)
    errors << "entry[#{i}] is not an object"
    next
  end

  OPERATOR_REQUIRED.each do |f|
    errors << "missing required field: #{f} in source[#{i}]" unless s.key?(f)
  end

  if tier == 'plugin-internal'
    PLUGIN_INTERNAL_ADDITIONAL.each do |f|
      errors << "missing plugin-internal field: #{f} in source[#{i}]" unless s.key?(f)
    end
  end

  if s.key?('tier') && ![1, 2].include?(s['tier'])
    errors << "invalid_tier=#{s['tier']} allowed=1|2"
  end

  if s.key?('source_class') && !VALID_SOURCE_CLASS.include?(s['source_class'])
    errors << "invalid_source_class=#{s['source_class']}"
    errors << "allowed=#{VALID_SOURCE_CLASS.join('|')}"
  end

  if s.key?('github') && !(s['github'].is_a?(String) && s['github'] =~ GITHUB_RX)
    errors << "invalid_github=#{s['github']} expected: <org>/<repo>"
  end

  if s.key?('fragility_tier') && !VALID_FRAGILITY_TIER.include?(s['fragility_tier'])
    errors << "invalid_fragility_tier=#{s['fragility_tier']}"
    errors << "allowed=#{VALID_FRAGILITY_TIER.join('|')}"
  end

  if s.key?('local_llm_eligible') && s['local_llm_eligible'] != true && s['local_llm_eligible'] != false
    errors << "invalid_local_llm_eligible=#{s['local_llm_eligible']}"
  end
end

valid = errors.empty?

if emit == 'json' && !out_path.empty?
  rec = { "valid" => valid, "sources_count" => sources.size, "errors" => errors }
  File.write(out_path, JSON.generate(rec))
end

errors.each { |e| STDERR.write("#{e}\n") }
STDERR.write("sources_count=#{sources.size}\n")
if tier == 'plugin-internal'
  all_internal_present = sources.all? do |s|
    s.is_a?(Hash) && PLUGIN_INTERNAL_ADDITIONAL.all? { |f| s.key?(f) }
  end
  STDERR.write("plugin_internal_fields_present=#{all_internal_present}\n")
end
STDERR.write("valid=#{valid}\n")
exit(valid ? 0 : 1)
RUBY
