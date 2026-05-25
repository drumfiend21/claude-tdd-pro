#!/usr/bin/env bash
# §2.8 AI Provenance Manifest validator. Validates a per-commit
# .claude-tdd-pro/provenance/<commit-sha>.json document against the §2.8
# contract. Subcheck modes return targeted key=value telemetry for
# downstream tooling (compliance auditing, cost-rollup reports).
#
# CLI surface:
#   --manifest PATH   manifest JSON file (required)
#   --check MODE      compliance-state | cost-telemetry | decision-provenance
#                     | pr-corpus-state | signature | freshness-enum
#
# Exit codes:
#   0  valid
#   1  invalid
#   2  usage error

MANIFEST=""
CHECK=""

while [ $# -gt 0 ]; do
  case "$1" in
    --manifest) MANIFEST="${2-}"; shift 2 ;;
    --check)    CHECK="${2-}";    shift 2 ;;
    -h|--help)
      echo "Usage: validate-provenance-manifest.sh --manifest <path> [--check <mode>]" >&2
      exit 0
      ;;
    *) echo "validate-provenance-manifest: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$MANIFEST" ]; then
  echo "validate-provenance-manifest: --manifest required" >&2
  exit 2
fi
if [ ! -f "$MANIFEST" ]; then
  echo "validate-provenance-manifest: file not found: $MANIFEST" >&2
  exit 2
fi

MANIFEST_PATH="$MANIFEST" CHECK_MODE="$CHECK" ruby - <<'RUBY'
require 'json'

begin
  data = JSON.parse(File.read(ENV['MANIFEST_PATH']))
rescue => e
  STDERR.write("validate-provenance-manifest: parse error: #{e.message}\n")
  exit 1
end

check = ENV['CHECK_MODE'].to_s

def emit(s); STDERR.write("#{s}\n"); end

VALID_FRESHNESS = %w[
  fresh-within-fetch-frequency
  stale-warn-degraded
  offline-cached
  operator-bypass
].freeze

if check == 'compliance-state' || check == 'compliance'
  cs = data['compliance_state'] || {}
  cs.each do |fw, blk|
    blk ||= {}
    emit("framework=#{fw}")
    emit("controls_consulted_count=#{(blk['controls_consulted'] || []).size}")
    emit("legal_review_status_count=#{(blk['legal_review_status_for_consulted'] || []).size}")
  end
  emit("frameworks_count=#{cs.size}")
  exit 0

elsif check == 'cost-telemetry'
  ct = data['cost_telemetry'] || {}
  %w[tokens_in tokens_out model duration_ms monetary_estimate_usd].each do |k|
    emit("#{k}=#{ct[k]}")
  end
  exit 0

elsif check == 'decision-provenance'
  dp = data['decision_provenance'] || {}
  adrs = dp['adrs'] || []
  refs = dp['decisions_referenced'] || []
  emit("adrs_count=#{adrs.size}")
  emit("architect_session_id=#{dp['architect_session_id']}")
  emit("decisions_referenced_count=#{refs.size}")
  exit 0

elsif check == 'pr-corpus-state' || check == 'pr-corpus'
  pcs = data['pr_corpus_state'] || {}
  pcs.each do |src, blk|
    blk ||= {}
    emit("source=#{src}")
    emit("patterns_consulted_count=#{(blk['patterns_consulted'] || []).size}")
    emit("evidence_count_used=#{blk['evidence_count_used']}")
  end
  emit("sources_count=#{pcs.size}")
  exit 0

elsif check == 'signature'
  sig = data['signature'].to_s
  if sig.start_with?('sha256:') && sig.length > 'sha256:'.length
    emit("signature_valid=true")
    exit 0
  else
    emit("invalid_signature_format=#{sig}")
    emit("expected_prefix=sha256:")
    exit 1
  end

elsif check == 'freshness-enum'
  errors = []
  found = []
  %w[standards_state pr_corpus_state compliance_state].each do |block_key|
    block = data[block_key] || {}
    block.each do |_, blk|
      blk ||= {}
      v = blk['freshness_at_generation']
      next if v.nil?
      if VALID_FRESHNESS.include?(v)
        found << v
      else
        errors << "invalid_freshness=#{v}"
      end
    end
  end
  found.each { |v| emit("freshness_value=#{v} valid=true") }
  if errors.empty?
    exit 0
  else
    errors.each { |e| emit(e) }
    emit("allowed=#{VALID_FRESHNESS.join('|')}")
    exit 1
  end
end

# Full validation: minimum required = commit.
errors = []
unless data['commit'].is_a?(String) && !data['commit'].empty?
  errors << "missing required field: commit"
end

if errors.empty?
  emit("valid=true")
  exit 0
else
  errors.each { |e| emit(e) }
  exit 1
end
RUBY
