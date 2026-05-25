#!/usr/bin/env bash
# §2.19 Compliance source contract validator (two-tier). Validates
# operator-facing COMPLIANCE-URLS.yaml and plugin-internal
# compliance/sources/<name>.yaml files. Mode auto-detected from
# --registry basename or explicit --tier {operator|plugin|plugin-internal}.

REG=""; TIER=""; CHECK=""; EMIT=""; OUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --registry) REG="${2-}"; shift 2 ;;
    --tier)     TIER="${2-}"; shift 2 ;;
    --check)    CHECK="${2-}"; shift 2 ;;
    --emit)     EMIT="${2-}"; shift 2 ;;
    --out)      OUT="${2-}"; shift 2 ;;
    -h|--help) echo "Usage: validate-source-contract.sh --registry <path> [--tier operator|plugin] [--check paywalled] [--emit json --out <path>]" >&2; exit 0 ;;
    *) echo "validate-source-contract: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$REG" ]; then echo "validate-source-contract: --registry required" >&2; exit 2; fi
if [ ! -f "$REG" ]; then echo "validate-source-contract: file not found: $REG" >&2; exit 2; fi

if [ -z "$TIER" ]; then
  case "$REG" in
    *COMPLIANCE-URLS.yaml) TIER="operator" ;;
    *compliance/sources/*) TIER="plugin-internal" ;;
    *)                     TIER="operator" ;;
  esac
fi
[ "$TIER" = "plugin" ] && TIER="plugin-internal"

REG_PATH="$REG" TIER_MODE="$TIER" CHECK_MODE="$CHECK" EMIT_MODE="$EMIT" OUT_PATH="$OUT" ruby - <<'RUBY'
require 'yaml'
require 'json'

data    = YAML.unsafe_load_file(ENV['REG_PATH']) || {}
sources = data.is_a?(Hash) ? (data['sources'] || []) : []
# Raw file text — used to detect literal `\n` escape sequences in
# why_authoritative source strings (YAML folds real newlines in
# flow-style scalars, so the parsed value is single-line either way).
raw_file = File.read(ENV['REG_PATH'])
tier    = ENV['TIER_MODE'].to_s
check   = ENV['CHECK_MODE'].to_s
emit    = ENV['EMIT_MODE'].to_s
out_path = ENV['OUT_PATH'].to_s

OPERATOR_REQUIRED = %w[
  id name url authoritative_publisher jurisdiction applicable_to
  identifier_scheme why_authoritative fetch_frequency legal_review_required paywalled
].freeze
PLUGIN_INTERNAL_ADDITIONAL = %w[
  fetcher identifier_pattern edition edition_date authority_tier
  fragility_tier origin added_by added_at license_handling
].freeze
VALID_FRAGILITY = %w[high medium low].freeze

errors = []
seen_ids = {}

sources.each_with_index do |s, i|
  unless s.is_a?(Hash)
    errors << "entry[#{i}] is not an object"; next
  end

  OPERATOR_REQUIRED.each do |f|
    errors << "missing required field: #{f} in source[#{i}]" unless s.key?(f)
  end

  if tier == 'plugin-internal'
    PLUGIN_INTERNAL_ADDITIONAL.each do |f|
      errors << "missing plugin-internal field: #{f} in source[#{i}]" unless s.key?(f)
    end
  end

  if s.key?('id')
    sid = s['id']
    if seen_ids[sid]
      errors << "duplicate_id=#{sid}"
    else
      seen_ids[sid] = true
    end
  end

  if s.key?('paywalled') && s['paywalled'] != true && s['paywalled'] != false
    errors << "invalid_paywalled=#{s['paywalled']} (must be boolean)"
  end

  if s.key?('why_authoritative')
    v = s['why_authoritative'].to_s
    # Inspect the raw source for the why_authoritative scalar — count
    # both literal \n escapes and real newline bytes inside the matched
    # value, plus block-style continuation lines. Max across styles
    # is the semantic line count.
    quoted = raw_file.scan(/why_authoritative:\s*"((?:[^"\\]|\\.)*)"/m).map { |m| m[0] }
    flow_break_count = quoted.sum { |q| q.scan(/\\n/).size + q.count("\n") }
    block_lines = raw_file.scan(/why_authoritative:\s*\|\s*\n((?:\s+\S.*\n)+)/m).flat_map { |m| m[0].lines }.reject { |ln| ln.strip.empty? }.size
    real_lines  = v.split("\n").reject { |ln| ln.strip.empty? }.size
    line_count = [real_lines, flow_break_count + 1, block_lines].max
    if line_count < 3
      errors << "why_authoritative_too_short lines=#{line_count} lines_required>=3"
    end
  end

  if s.key?('fragility_tier') && !VALID_FRAGILITY.include?(s['fragility_tier'])
    errors << "invalid_fragility_tier=#{s['fragility_tier']} allowed=#{VALID_FRAGILITY.join('|')}"
  end

  # --check paywalled: a paywalled=true entry must also carry
  # document_url and attribution_note for credible non-bypass citation.
  if check == 'paywalled' && s['paywalled'] == true
    errors << "paywalled_missing_document_url id=#{s['id']}"    unless s.key?('document_url')
    errors << "paywalled_missing_attribution_note id=#{s['id']}" unless s.key?('attribution_note')
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
  all_present = sources.all? { |s|
    s.is_a?(Hash) && PLUGIN_INTERNAL_ADDITIONAL.all? { |f| s.key?(f) }
  }
  STDERR.write("plugin_internal_fields_present=#{all_present}\n")
end
STDERR.write("valid=#{valid}\n")
exit(valid ? 0 : 1)
RUBY
