#!/usr/bin/env bash
# Q-1 SPACE config validator.
set -uo pipefail
CONFIG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG="$2"; shift 2 ;;
    -h|--help) echo "Usage: validate-config.sh --config <path>"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$CONFIG" || ! -f "$CONFIG" ]] && { echo "validate-config: --config <path> required" >&2; exit 2; }

CONFIG="$CONFIG" LANG="${LANG:-en_US.UTF-8}" ruby -ryaml -e '# coding: utf-8
Encoding.default_external = Encoding::UTF_8
data = YAML.load_file(ENV["CONFIG"]) rescue nil
unless data.is_a?(Hash)
  STDERR.puts "validate-config: not a mapping"; exit 2
end
VALID_DIMS = %w[satisfaction performance activity collaboration efficiency_and_flow]
errors = []
dims = data["dimensions"] || {}
dims.each_key do |k|
  errors << "unknown dimension key: #{k} (valid: #{VALID_DIMS.join(", ")})" unless VALID_DIMS.include?(k)
end
if data["retention_days"] && data["retention_days"].to_i < 0
  errors << "retention_days must be >= 0 (got: #{data["retention_days"]})"
end
if data["share"] == "never" && data.key?("share_endpoint")
  errors << "share=never but share_endpoint set: remove share_endpoint or change share"
end
if errors.empty?
  STDERR.puts "validate-config: ok dimensions=#{dims.size}"
  exit 0
else
  errors.each { |e| STDERR.puts "validate-config: #{e}" }
  exit 2
end
'
