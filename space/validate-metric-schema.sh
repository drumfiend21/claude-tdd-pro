#!/usr/bin/env bash
# §2.11 SPACE metric schema validator. Validates space/metrics.yaml
# (top-level `metrics:` key wrapping an array of metric definitions)
# against §2.11 contract: required {id, dimension, source, unit,
# reporting_window, privacy, opt_in}; dimension must be in the
# five-value enum; privacy must be `local-only`; opt_in must be boolean;
# reporting_window must be a recognized duration shape (Nd|Nh|Nw|Nm).
#
# CLI:
#   --metrics PATH   metrics YAML file (required)
#   --emit json      emit structured JSON to --out
#   --out PATH       output path for --emit json
#
# Exit codes:
#   0  valid
#   1  invalid
#   2  usage error

METRICS=""
EMIT=""
OUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --metrics) METRICS="${2-}"; shift 2 ;;
    --emit)    EMIT="${2-}";    shift 2 ;;
    --out)     OUT="${2-}";     shift 2 ;;
    -h|--help) echo "Usage: validate-metric-schema.sh --metrics <path> [--emit json --out <path>]" >&2; exit 0 ;;
    *) echo "validate-metric-schema: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$METRICS" ]; then echo "validate-metric-schema: --metrics required" >&2; exit 2; fi
if [ ! -f "$METRICS" ]; then echo "validate-metric-schema: file not found: $METRICS" >&2; exit 2; fi

METRICS_PATH="$METRICS" EMIT_MODE="$EMIT" OUT_PATH="$OUT" ruby - <<'RUBY'
require 'yaml'
require 'json'

begin
  data = YAML.unsafe_load_file(ENV['METRICS_PATH']) || {}
rescue => e
  STDERR.write("validate-metric-schema: yaml parse error: #{e.message}\n")
  exit 1
end

metrics = data.is_a?(Hash) ? (data['metrics'] || []) : []
emit     = ENV['EMIT_MODE'].to_s
out_path = ENV['OUT_PATH'].to_s

REQUIRED = %w[id dimension source unit reporting_window privacy opt_in].freeze
VALID_DIMENSION = %w[satisfaction performance activity collaboration efficiency-and-flow].freeze
VALID_PRIVACY   = %w[local-only].freeze
DURATION_RX = /\A\d+(s|m|h|d|w|mo|y)\z/

errors = []
seen_ids = {}

metrics.each_with_index do |m, i|
  unless m.is_a?(Hash)
    errors << "entry[#{i}] is not an object"
    next
  end
  REQUIRED.each do |f|
    errors << "missing required field: #{f} in metric[#{i}]" unless m.key?(f)
  end
  if m.key?('id')
    mid = m['id']
    if seen_ids[mid]
      errors << "duplicate_id=#{mid}"
    else
      seen_ids[mid] = true
    end
  end
  if m.key?('dimension') && !VALID_DIMENSION.include?(m['dimension'])
    errors << "invalid_dimension=#{m['dimension']}"
    errors << "allowed=#{VALID_DIMENSION.join('|')}"
  end
  if m.key?('privacy') && !VALID_PRIVACY.include?(m['privacy'])
    errors << "invalid_privacy=#{m['privacy']}"
    errors << "required_value=local-only"
  end
  if m.key?('opt_in') && m['opt_in'] != true && m['opt_in'] != false
    errors << "invalid_opt_in=#{m['opt_in']}"
  end
  if m.key?('source') && (!m['source'].is_a?(String) || m['source'].empty?)
    errors << "empty_source in metric[#{i}]"
  end
  if m.key?('unit') && (!m['unit'].is_a?(String) || m['unit'].empty?)
    errors << "empty_unit in metric[#{i}]"
  end
  if m.key?('reporting_window')
    v = m['reporting_window'].to_s
    unless v =~ DURATION_RX
      errors << "invalid_reporting_window=#{v}"
      errors << "allowed_format=<N>s|<N>m|<N>h|<N>d|<N>w|<N>mo|<N>y (e.g. 7d, 24h, 1w, 30d)"
    end
  end
end

valid = errors.empty?

if emit == 'json' && !out_path.empty?
  rec = {
    "valid" => valid,
    "metrics_count" => metrics.size,
    "errors" => errors,
  }
  File.write(out_path, JSON.generate(rec))
end

errors.each { |e| STDERR.write("#{e}\n") }
STDERR.write("metrics_count=#{metrics.size}\n")
STDERR.write("valid=#{valid}\n")
exit(valid ? 0 : 1)
RUBY
