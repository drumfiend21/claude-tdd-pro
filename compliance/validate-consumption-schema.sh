#!/usr/bin/env bash
# §2.18 Generation-time consumption schema validator. Validates the
# C-3 manifest's standards_state, pr_corpus_state, compliance_state
# blocks against the §2.18 contract (which cross-cuts §2.8).
#
# CLI:
#   --manifest PATH         provenance manifest JSON (required)
#   --check MODE            controls-array | patterns-array | freshness-enum
#                           | standards | pr-corpus | compliance | cross-cut
#   --require-consumption   error if all three state blocks are absent
#   --emit json             emit structured JSON
#   --out PATH              output for --emit json
#
# Exit codes: 0 valid, 1 invalid, 2 usage error.

MANIFEST=""
CHECK=""
CROSS_CHECK=""
REQUIRE_CONSUMPTION=0
EMIT=""
OUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --manifest)             MANIFEST="${2-}";    shift 2 ;;
    --check)                CHECK="${2-}";       shift 2 ;;
    --cross-check)          CROSS_CHECK="${2-}"; shift 2 ;;
    --require-consumption)  REQUIRE_CONSUMPTION=1; shift ;;
    --emit)                 EMIT="${2-}";        shift 2 ;;
    --out)                  OUT="${2-}";         shift 2 ;;
    -h|--help) echo "Usage: validate-consumption-schema.sh --manifest <path> [--check <mode>] [--cross-check section-2-8] [--require-consumption] [--emit json --out <path>]" >&2; exit 0 ;;
    *) echo "validate-consumption-schema: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$MANIFEST" ]; then echo "validate-consumption-schema: --manifest required" >&2; exit 2; fi
if [ ! -f "$MANIFEST" ]; then echo "validate-consumption-schema: file not found: $MANIFEST" >&2; exit 2; fi

MANIFEST_PATH="$MANIFEST" CHECK_MODE="$CHECK" CROSS_CHECK_MODE="$CROSS_CHECK" \
REQ="$REQUIRE_CONSUMPTION" EMIT_MODE="$EMIT" OUT_PATH="$OUT" ruby - <<'RUBY'
require 'json'

data    = JSON.parse(File.read(ENV['MANIFEST_PATH']))
check   = ENV['CHECK_MODE'].to_s
require_consumption = ENV['REQ'] == '1'
emit    = ENV['EMIT_MODE'].to_s
out_path = ENV['OUT_PATH'].to_s

VALID_FRESHNESS = %w[
  fresh-within-fetch-frequency stale-warn-degraded offline-cached operator-bypass
].freeze

def emit(s); STDERR.write("#{s}\n"); end

errors = []

# Per-check modes (§2.18 cross-cuts §2.8 enum + array-shape invariants).
case check
when 'controls-array'
  (data['compliance_state'] || {}).each do |fw, blk|
    blk ||= {}
    if blk.key?('controls_consulted') && !blk['controls_consulted'].is_a?(Array)
      errors << "invalid_controls_consulted_type=#{blk['controls_consulted'].class.name.downcase} framework=#{fw}"
    end
  end

when 'patterns-array'
  (data['pr_corpus_state'] || {}).each do |src, blk|
    blk ||= {}
    if blk.key?('patterns_consulted') && !blk['patterns_consulted'].is_a?(Array)
      errors << "invalid_patterns_consulted_type=#{blk['patterns_consulted'].class.name.downcase} source=#{src}"
    end
  end

when 'freshness-enum'
  %w[standards_state pr_corpus_state compliance_state].each do |block|
    (data[block] || {}).each do |id, blk|
      blk ||= {}
      v = blk['freshness_at_generation']
      next if v.nil?
      unless VALID_FRESHNESS.include?(v)
        errors << "invalid_freshness=#{v} block=#{block} id=#{id}"
      end
    end
  end

when 'standards-state'
  if data.key?('standards_state')
    emit("standards_state_present=true")
    emit("sources_count=#{(data['standards_state']||{}).size}")
  else
    errors << "standards_state block missing"
  end

when 'pr-corpus-state'
  if data.key?('pr_corpus_state')
    emit("pr_corpus_state_present=true")
    emit("sources_count=#{(data['pr_corpus_state']||{}).size}")
  else
    errors << "pr_corpus_state block missing"
  end

when 'compliance-state'
  if data.key?('compliance_state')
    emit("compliance_state_present=true")
    emit("frameworks_count=#{(data['compliance_state']||{}).size}")
  else
    errors << "compliance_state block missing"
  end

when 'standards', 'pr-corpus', 'compliance', 'cross-cut'
  # Block-presence summaries plus §2.8 cross-cut conformance.
  emit("standards_count=#{(data['standards_state']||{}).size}")
  emit("pr_corpus_count=#{(data['pr_corpus_state']||{}).size}")
  emit("compliance_count=#{(data['compliance_state']||{}).size}")
  emit("cross_cut=section-2-8")
end

# --cross-check section-2-8: confirms the three blocks all exist (even
# if empty) — i.e., the manifest is structurally compliant with §2.8.
cross = ENV['CROSS_CHECK_MODE'].to_s
if cross == 'section-2-8'
  ok = %w[standards_state pr_corpus_state compliance_state].all? { |k| data.key?(k) }
  if ok
    emit("cross_check_section_2_8=pass")
  else
    missing = %w[standards_state pr_corpus_state compliance_state].reject { |k| data.key?(k) }
    errors << "cross_check_section_2_8=fail missing=#{missing.join(',')}"
  end
end

# --require-consumption: at least one block must be present.
if require_consumption
  has_any = %w[standards_state pr_corpus_state compliance_state].any? { |k|
    data[k].is_a?(Hash) && !data[k].empty?
  }
  unless has_any
    errors << "no_consumption_blocks_present"
  end
end

valid = errors.empty?

if emit == 'json' && !out_path.empty?
  rec = {
    "valid" => valid,
    "commit" => data['commit'],
    "standards_count"  => (data['standards_state']  || {}).size,
    "pr_corpus_count"  => (data['pr_corpus_state']  || {}).size,
    "compliance_count" => (data['compliance_state'] || {}).size,
    "errors" => errors,
  }
  File.write(out_path, JSON.generate(rec))
end

errors.each { |e| emit(e) }
emit("valid=#{valid}")
exit(valid ? 0 : 1)
RUBY
