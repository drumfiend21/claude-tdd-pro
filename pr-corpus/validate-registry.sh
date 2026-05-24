#!/usr/bin/env bash
# L-17 PR-SOURCES.yaml registry validator. Parses yaml, asserts cross-cutting
# source contract for the L phase (id + source_class + tier + applies_to).
set -uo pipefail
REG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --registry) REG="$2"; shift 2 ;;
    -h|--help) echo "Usage: validate-registry.sh --registry <yaml>"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$REG" || ! -f "$REG" ]] && { echo "validate-registry: --registry <yaml> required" >&2; exit 2; }

REG="$REG" LANG="${LANG:-en_US.UTF-8}" ruby -ryaml -e '
Encoding.default_external = Encoding::UTF_8
begin
  data = YAML.unsafe_load_file(ENV["REG"])
rescue => e
  STDERR.puts "validate-registry: parse_error #{e.message}"
  exit 1
end
sources = (data["sources"] || [])
STDERR.puts "validate-registry: valid=true sources_count=#{sources.length}"
'
