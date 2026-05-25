#!/usr/bin/env bash
# §2.16 ADR validator. Walks docs/adr/<date>-<slug>.md files and
# validates each against the §2.16 schema: filename pattern
# ^[0-9]{4}-[a-z0-9-]+\.md$, MADR status enum, required fields
# (deciders, status, context, considered_options, decision_outcome,
# profile_active, architect_session, decision_id).
#
# CLI:
#   --adr-dir PATH    directory containing ADR files (required)
#   --check MODE      filename (default) | deciders | status | context |
#                     options | outcome | profile | architect-session
#
# Exit codes:
#   0  all valid
#   1  validation failed
#   2  usage error

ADR_DIR=""
CHECK=""

while [ $# -gt 0 ]; do
  case "$1" in
    --adr-dir) ADR_DIR="${2-}"; shift 2 ;;
    --check)   CHECK="${2-}";   shift 2 ;;
    -h|--help) echo "Usage: validate-naming.sh --adr-dir <dir> [--check filename|deciders|status|context|options|outcome|profile|architect-session]" >&2; exit 0 ;;
    *) echo "validate-naming: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$ADR_DIR" ]; then echo "validate-naming: --adr-dir required" >&2; exit 2; fi
if [ ! -d "$ADR_DIR" ]; then echo "validate-naming: dir not found: $ADR_DIR" >&2; exit 2; fi

ADR_PATH="$ADR_DIR" CHECK_MODE="$CHECK" ruby - <<'RUBY'
require 'pathname'

adr_dir = ENV['ADR_PATH']
check   = ENV['CHECK_MODE'].to_s

VALID_STATUS = %w[proposed accepted deprecated superseded rejected].freeze
NAME_RX = /\A\d{4}-[a-z0-9][a-z0-9-]*\.md\z/

files = Dir.glob(File.join(adr_dir, "*.md")).sort

def emit(s); STDERR.write("#{s}\n"); end

errors = []

case check
when '', 'filename'
  files.each do |f|
    bn = File.basename(f)
    unless bn =~ NAME_RX
      errors << "invalid_name=#{bn} expected_pattern=^[0-9]{4}-[a-z0-9-]+\\.md$"
    end
  end
  if errors.empty?
    emit("all_naming_valid=true")
    emit("files_checked=#{files.size}")
    exit 0
  else
    errors.each { |e| emit(e) }
    exit 1
  end

when 'deciders'
  files.each do |f|
    text = File.read(f)
    unless text =~ /^deciders:\s*\[?\s*[a-zA-Z]/
      errors << "missing required field: deciders in #{File.basename(f)}"
    end
  end

when 'status'
  files.each do |f|
    text = File.read(f)
    if m = text.match(/^status:\s*(\S+)/)
      v = m[1].strip
      if VALID_STATUS.include?(v)
        emit("status=#{v} valid=true file=#{File.basename(f)}")
      else
        errors << "invalid_status=#{v} allowed=#{VALID_STATUS.join('|')}"
      end
    else
      errors << "missing required field: status in #{File.basename(f)}"
    end
  end

when 'context'
  files.each do |f|
    text = File.read(f)
    m = text.match(/^##\s+Context\s*\n+([^\n#].{20,})/m)
    if m
      body = m[1]
      emit("context_present=true file=#{File.basename(f)}")
      emit("context_length>=20 actual=#{body.length}")
    else
      errors << "missing or trivial context section in #{File.basename(f)}"
    end
  end

when 'options'
  files.each do |f|
    text = File.read(f)
    if m = text.match(/^##\s+Considered options\s*\n+((?:-\s+.+\n)+)/i)
      count = m[1].lines.count
      emit("options_count=#{count} file=#{File.basename(f)}")
    else
      errors << "missing or empty considered options section in #{File.basename(f)}"
    end
  end

when 'outcome'
  files.each do |f|
    text = File.read(f)
    m = text.match(/^##\s+Decision outcome\s*\n+(.{20,})/m)
    if m && m[1] =~ /(rationale|because|chose|decided)/i
      body = m[1]
      emit("outcome_present=true file=#{File.basename(f)}")
      emit("outcome_with_rationale=true")
      emit("rationale_length>=20 actual=#{body.length}")
    else
      errors << "missing decision outcome with rationale in #{File.basename(f)}"
    end
  end

when 'profile'
  files.each do |f|
    text = File.read(f)
    if m = text.match(/^profile_active:\s*(\S+)/)
      emit("profile_active=#{m[1].strip} file=#{File.basename(f)}")
    else
      errors << "missing profile_active reference in #{File.basename(f)}"
    end
  end

when 'architect-session'
  files.each do |f|
    text = File.read(f)
    sess = text.match(/^architect_session:\s*(\S+)/)
    did  = text.match(/^decision_id:\s*(\S+)/)
    if sess && did
      emit("architect_session=#{sess[1].strip} decision_id=#{did[1].strip} file=#{File.basename(f)}")
    else
      errors << "missing architect_session or decision_id in #{File.basename(f)}"
    end
  end
end

if errors.empty?
  exit 0
else
  errors.each { |e| emit(e) }
  exit 1
end
RUBY
