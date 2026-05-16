#!/usr/bin/env bash
# L-17 regenerates the sources block in the registry from shipped defaults.
# Operator namespace block is preserved verbatim.
set -uo pipefail
REG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --registry) REG="$2"; shift 2 ;;
    -h|--help) echo "Usage: regenerate-defaults.sh --registry <yaml>"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$REG" || ! -f "$REG" ]] && { echo "regenerate-defaults: --registry <yaml> required" >&2; exit 2; }
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
DEFAULTS="$SCRIPT_DIR/sources/PR-SOURCES.defaults.yaml"
[[ ! -f "$DEFAULTS" ]] && { echo "regenerate-defaults: shipped defaults missing at $DEFAULTS" >&2; exit 2; }

REG="$REG" DEFAULTS="$DEFAULTS" LANG="${LANG:-en_US.UTF-8}" ruby -ryaml -e '
Encoding.default_external = Encoding::UTF_8
defaults = YAML.load_file(ENV["DEFAULTS"]) rescue {}
existing = YAML.load_file(ENV["REG"]) rescue {}
op_ns = existing["operator_namespace"] || []
merged = { "sources" => (defaults["sources"] || []), "operator_namespace" => op_ns }
File.write(ENV["REG"], YAML.dump(merged))
STDERR.puts "regenerate-defaults: sources_replaced=#{(defaults["sources"]||[]).length} operator_namespace_preserved=#{op_ns.length}"
'
