#!/usr/bin/env bash
# §2.7 Lock file validator. Validates .claude-tdd-pro/lock.json against
# the §2.7 sectioned-advisory-lock contract: 15 registered section names,
# _locks.<section> entries with {holder, expires}, expires enforced as
# upper-bound on lock-holding.
#
# CLI:
#   --lock PATH    lock.json file (required)
#   --check MODE   expired-locks | locks-format | section-names | sections
#   --now ISO      current time (required when --check expired-locks)
#
# Exit codes:
#   0  valid
#   1  invalid
#   2  usage error

LOCK=""
CHECK=""
NOW=""

while [ $# -gt 0 ]; do
  case "$1" in
    --lock)  LOCK="${2-}";  shift 2 ;;
    --check) CHECK="${2-}"; shift 2 ;;
    --now)   NOW="${2-}";   shift 2 ;;
    -h|--help)
      echo "Usage: validate-lock.sh --lock <path> [--check <mode>] [--now <iso>]" >&2
      exit 0
      ;;
    *) echo "validate-lock: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$LOCK" ]; then
  echo "validate-lock: --lock required" >&2
  exit 2
fi
if [ ! -f "$LOCK" ]; then
  echo "validate-lock: file not found: $LOCK" >&2
  exit 2
fi

LOCK_PATH="$LOCK" CHECK_MODE="$CHECK" NOW_ISO="$NOW" ruby - <<'RUBY'
require 'json'
require 'time'

begin
  data = JSON.parse(File.read(ENV['LOCK_PATH']))
rescue => e
  STDERR.write("validate-lock: parse error: #{e.message}\n")
  exit 1
end

check = ENV['CHECK_MODE'].to_s
now_iso = ENV['NOW_ISO'].to_s

def emit(s); STDERR.write("#{s}\n"); end

REGISTERED_SECTIONS = %w[
  rubric detectors standards compliance prompts models pr_corpus profile
  verify workflow_state standards_freshness pr_corpus_freshness
  compliance_freshness rule_cache quality_standards_directory
].freeze

if check == 'expired-locks'
  if now_iso.empty?
    emit("validate-lock: --now required for --check expired-locks")
    exit 2
  end
  begin
    now = Time.parse(now_iso)
  rescue => e
    emit("validate-lock: bad --now timestamp: #{e.message}")
    exit 2
  end
  locks = data['_locks'] || {}
  expired = []
  locks.each do |section, entry|
    entry ||= {}
    exp = entry['expires']
    next if exp.nil?
    begin
      if Time.parse(exp) < now
        expired << section
        emit("expired_lock=#{section} holder=#{entry['holder']} expires=#{exp}")
      end
    rescue
      # malformed timestamps surface as expired (defensive)
      expired << section
      emit("expired_lock=#{section} reason=malformed_expires")
    end
  end
  if expired.empty?
    emit("expired_count=0")
    exit 0
  else
    emit("expired_count=#{expired.size}")
    exit 1
  end

elsif check == 'locks-format'
  locks = data['_locks'] || {}
  locks.each do |section, entry|
    entry ||= {}
    emit("section=#{section}")
    emit("holder=#{entry['holder']}")
    emit("expires=#{entry['expires']}")
  end
  emit("locks_count=#{locks.size}")
  exit 0

elsif check == 'section-names'
  locks = data['_locks'] || {}
  unknown = locks.keys - REGISTERED_SECTIONS
  if unknown.empty?
    emit("section_names_valid=true")
    exit 0
  else
    unknown.each { |s| emit("unknown_section=#{s}") }
    emit("allowed=#{REGISTERED_SECTIONS.join('|')}")
    exit 1
  end

elsif check == 'sections'
  sections = ((data['_meta'] || {})['sections']) || []
  emit("sections_count=#{sections.size}")
  emit("expected=15")
  if sections.size == 15 && (REGISTERED_SECTIONS - sections).empty?
    emit("sections_match=true")
    exit 0
  else
    missing = REGISTERED_SECTIONS - sections
    extra = sections - REGISTERED_SECTIONS
    missing.each { |s| emit("missing_section=#{s}") }
    extra.each   { |s| emit("extra_section=#{s}") }
    exit 1
  end
end

# Full validation: minimum required = plugin_version.
errors = []
unless data['plugin_version'].is_a?(String) && !data['plugin_version'].empty?
  errors << "missing required field: plugin_version"
end

if errors.empty?
  emit("valid=true")
  exit 0
else
  errors.each { |e| emit(e) }
  exit 1
end
RUBY
