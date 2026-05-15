#!/usr/bin/env bash
# validate-prompt-registry.sh — P-1 substrate. Validates a prompts/
# registry.yaml against §2.10 prompt registry contract:
#
#   - id: <prompt-id>
#     versions:
#       - version, file, hash, created, eval_pass_rate, regression_from_prior, status
#         status MUST be one of: active | archived | candidate
#         migration: { from_inline_agent, golden_output_diff, delta_status, validated_inputs }
#           delta_status MUST be one of: zero-delta | justified-delta:<reason>
#           when delta_status=zero-delta, golden_output_diff MUST be non-empty
#           when delta_status=justified-delta, MUST include a reason suffix
#
# Per §2.2 detector contract (exit codes): 0 = valid; 2 = validation
# failure; 1 = tooling error.
#
# Usage:
#   validate-prompt-registry.sh <registry.yaml> [--check-hashes] [--check-files]

set -uo pipefail

REGISTRY="${1:-}"
shift || true
CHECK_HASHES=0
CHECK_FILES=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-hashes) CHECK_HASHES=1; shift ;;
    --check-files) CHECK_FILES=1; shift ;;
    -h|--help)
      echo "Usage: validate-prompt-registry.sh <registry.yaml> [--check-hashes] [--check-files]"
      exit 0
      ;;
    *) echo "validate-prompt-registry: unknown flag: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$REGISTRY" || ! -f "$REGISTRY" ]]; then
  echo "validate-prompt-registry: registry not found: $REGISTRY" >&2
  exit 1
fi

REGISTRY_DIR=$(cd "$(dirname "$REGISTRY")" && pwd -P)

REGISTRY="$REGISTRY" REGISTRY_DIR="$REGISTRY_DIR" CHECK_HASHES="$CHECK_HASHES" CHECK_FILES="$CHECK_FILES" \
LANG="${LANG:-en_US.UTF-8}" ruby -ryaml -rjson -rdigest -e '# coding: utf-8
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

registry = ENV["REGISTRY"]
registry_dir = ENV["REGISTRY_DIR"]
check_hashes = ENV["CHECK_HASHES"] == "1"
check_files  = ENV["CHECK_FILES"] == "1"

begin
  data = YAML.load_file(registry)
rescue => e
  STDERR.puts "validate-prompt-registry: yaml parse error: #{e.message}"
  exit 1
end

unless data.is_a?(Array)
  STDERR.puts "validate-prompt-registry: registry root must be an array of prompt entries"
  exit 2
end

VALID_STATUS = %w[active archived candidate]
VALID_DELTA  = %w[zero-delta justified-delta]

errors = []

data.each_with_index do |entry, idx|
  unless entry.is_a?(Hash) && entry["id"].is_a?(String) && entry["versions"].is_a?(Array)
    errors << "entry[#{idx}]: must have id (string) and versions (array)"
    next
  end

  pid = entry["id"]
  entry["versions"].each_with_index do |v, vidx|
    unless v.is_a?(Hash)
      errors << "prompt #{pid} version[#{vidx}]: must be a mapping"
      next
    end

    %w[version file hash created eval_pass_rate regression_from_prior status].each do |req|
      unless v.key?(req)
        errors << "prompt #{pid} version[#{vidx}]: required field #{req} missing"
      end
    end

    if v.key?("status") && !VALID_STATUS.include?(v["status"])
      errors << "prompt #{pid} v#{v["version"]}: status enum must be one of [#{VALID_STATUS.join(", ")}], got: #{v["status"].inspect}"
    end

    if v.key?("migration")
      m = v["migration"]
      unless m.is_a?(Hash)
        errors << "prompt #{pid} v#{v["version"]}: migration must be a mapping"
        next
      end

      delta = (m["delta_status"] || "").to_s
      delta_kind = delta.split(":", 2).first
      if !VALID_DELTA.include?(delta_kind)
        errors << "prompt #{pid} v#{v["version"]}: migration.delta_status enum must be one of [#{VALID_DELTA.join(", ")}], got: #{delta.inspect}"
        next
      end

      if delta_kind == "zero-delta"
        gold = (m["golden_output_diff"] || "").to_s
        if gold.strip.empty?
          errors << "prompt #{pid} v#{v["version"]}: zero-delta requires non-empty golden_output_diff (cannot be empty string)"
        end
      end

      if delta_kind == "justified-delta"
        reason = delta.split(":", 2)[1].to_s
        if reason.strip.empty?
          errors << "prompt #{pid} v#{v["version"]}: justified-delta requires a reason suffix (e.g. justified-delta:improved-clarity)"
        end
      end
    end

    if check_files && v["file"].is_a?(String)
      file_path = File.join(registry_dir, "..", v["file"])
      unless File.file?(file_path)
        errors << "prompt #{pid} v#{v["version"]}: file does not exist at #{v["file"]}"
      end
    end

    if check_hashes && v["file"].is_a?(String) && v["hash"].is_a?(String)
      file_path = File.join(registry_dir, "..", v["file"])
      if File.file?(file_path)
        expected = v["hash"].sub(/^sha256:/, "")
        actual = Digest::SHA256.hexdigest(File.read(file_path))
        if expected != actual
          errors << "prompt #{pid} v#{v["version"]}: hash mismatch (registry=#{expected[0,12]}... file=#{actual[0,12]}...)"
        end
      end
    end
  end
end

if errors.any?
  errors.each { |e| STDERR.puts e }
  exit 2
end

STDERR.puts "validate-prompt-registry: ok (#{data.length} prompts, #{data.sum { |e| e["versions"].length }} versions)"
exit 0
'
