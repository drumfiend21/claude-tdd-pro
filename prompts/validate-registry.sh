#!/usr/bin/env bash
# §2.10 Prompt registry validator. Validates prompts/registry.yaml against
# the §2.10 contract. Full validation rejects duplicate prompt ids,
# duplicate versions within a prompt, and invalid status enum values.
# Subcheck modes target specific slices for downstream tooling.
#
# CLI:
#   --registry PATH   registry YAML file (required)
#   --check MODE      timestamps | files | hash | migration
#   --emit json       emit structured JSON
#   --out PATH        output path for --emit json
#
# Exit codes:
#   0  valid
#   1  invalid
#   2  usage error

REG=""
CHECK=""
EMIT=""
OUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --registry) REG="${2-}";   shift 2 ;;
    --check)    CHECK="${2-}"; shift 2 ;;
    --emit)     EMIT="${2-}";  shift 2 ;;
    --out)      OUT="${2-}";   shift 2 ;;
    -h|--help)
      echo "Usage: validate-registry.sh --registry <path> [--check <mode>] [--emit json --out <path>]" >&2
      exit 0
      ;;
    *) echo "validate-registry: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$REG" ]; then echo "validate-registry: --registry required" >&2; exit 2; fi
if [ ! -f "$REG" ]; then echo "validate-registry: file not found: $REG" >&2; exit 2; fi

# Resolve registry directory for relative `file:` paths.
REG_DIR=$(cd "$(dirname "$REG")/.." 2>/dev/null && pwd -P)
[ -z "$REG_DIR" ] && REG_DIR="$(pwd -P)"

REG_PATH="$REG" REG_DIR="$REG_DIR" CHECK_MODE="$CHECK" EMIT_MODE="$EMIT" OUT_PATH="$OUT" ruby - <<'RUBY'
require 'yaml'
require 'json'
require 'digest'
require 'time'

reg_path = ENV['REG_PATH'].to_s
reg_dir  = ENV['REG_DIR'].to_s
check    = ENV['CHECK_MODE'].to_s
emit     = ENV['EMIT_MODE'].to_s
out_path = ENV['OUT_PATH'].to_s

begin
  data = YAML.unsafe_load_file(reg_path) || {}
rescue => e
  STDERR.write("validate-registry: yaml parse error: #{e.message}\n")
  exit 1
end

prompts = data['prompts'] || []

def emit(s); STDERR.write("#{s}\n"); end

VALID_STATUS = %w[active archived candidate].freeze

if check == 'timestamps'
  errors = []
  prompts.each do |p|
    (p['versions'] || []).each do |v|
      next unless v.key?('created')
      val = v['created']
      ok = false
      begin
        if val.is_a?(String)
          Time.iso8601(val)
          ok = true
        end
      rescue
      end
      unless ok
        errors << "invalid_iso8601=#{val} prompt_id=#{p['id']} version=#{v['version']}"
      end
    end
  end
  if errors.empty?
    emit("timestamps_valid=true")
    exit 0
  else
    errors.each { |e| emit(e) }
    exit 1
  end

elsif check == 'files'
  errors = []
  prompts.each do |p|
    (p['versions'] || []).each do |v|
      f = v['file']
      next if f.nil?
      abs = File.join(reg_dir, f)
      unless File.exist?(abs) || File.exist?(f)
        errors << "file_not_found path=#{f} prompt_id=#{p['id']} version=#{v['version']}"
      end
    end
  end
  if errors.empty?
    emit("files_valid=true")
    exit 0
  else
    errors.each { |e| emit(e) }
    exit 1
  end

elsif check == 'hash'
  errors = []
  prompts.each do |p|
    (p['versions'] || []).each do |v|
      f = v['file']
      h = v['hash']
      next if f.nil? || h.nil?
      abs = File.exist?(File.join(reg_dir, f)) ? File.join(reg_dir, f) : f
      next unless File.exist?(abs)
      actual = Digest::SHA256.hexdigest(File.read(abs))
      unless actual.start_with?(h) || h == actual
        errors << "hash_mismatch prompt=#{p['id']} version=#{v['version']} declared=#{h} actual=#{actual[0..15]}"
      end
    end
  end
  if errors.empty?
    emit("hash_valid=true")
    exit 0
  else
    errors.each { |e| emit(e) }
    exit 1
  end

elsif check == 'migration'
  errors = []
  found = []
  prompts.each do |p|
    (p['versions'] || []).each do |v|
      m = v['migration']
      next unless m.is_a?(Hash)
      ds = m['delta_status'].to_s
      if ds == 'zero-delta'
        found << "delta_status=zero-delta"
      elsif ds.start_with?('justified-delta:')
        reason = ds.sub(/^justified-delta:/, '')
        if reason.strip.empty?
          errors << "invalid_delta_status=#{ds} (reason missing)"
        else
          found << "delta_status=justified-delta"
          found << "reason=#{reason}"
        end
      else
        errors << "invalid_delta_status=#{ds}"
      end
    end
  end
  found.each { |s| emit(s) }
  if errors.empty?
    exit 0
  else
    errors.each { |e| emit(e) }
    emit("allowed=zero-delta|justified-delta:<reason>")
    exit 1
  end
end

# Full validation: duplicate ids, duplicate versions, status enum.
errors = []
seen_ids = {}
prompts.each do |p|
  pid = p['id']
  if seen_ids[pid]
    errors << "duplicate_id=#{pid}"
  else
    seen_ids[pid] = true
  end
  seen_versions = {}
  (p['versions'] || []).each do |v|
    vid = v['version']
    if seen_versions[vid]
      errors << "duplicate_version=#{vid} prompt_id=#{pid}"
    else
      seen_versions[vid] = true
    end
    if v.key?('status') && !VALID_STATUS.include?(v['status'])
      errors << "invalid_status=#{v['status']} prompt_id=#{pid} version=#{vid}"
      errors << "allowed=#{VALID_STATUS.join('|')}"
    end
  end
end

valid = errors.empty?

if emit == 'json' && !out_path.empty?
  rec = {
    "valid" => valid,
    "prompts_count" => prompts.size,
    "errors" => errors,
  }
  File.write(out_path, JSON.generate(rec))
end

errors.each { |e| emit(e) }
emit("prompts_count=#{prompts.size}")
emit("valid=#{valid}")
exit(valid ? 0 : 1)
RUBY
