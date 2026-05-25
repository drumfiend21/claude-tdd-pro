#!/usr/bin/env bash
# §2.21 cross-check: verify that a source-file's registry_link anchor
# (STANDARDS-URLS.yaml#<anchor>) points to an entry whose id actually
# exists in the operator-facing registry. Catches the case where a
# source-file was authored with a typo or against a registry entry
# that has since been removed.
#
# CLI:
#   --source-file PATH    source-folder YAML (required)
#   --registry PATH       operator-facing STANDARDS-URLS.yaml (required)
#
# Exit codes: 0 valid, 2 anchor-not-found / unresolvable, 1 tooling error.

SF=""; REG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --source-file) SF="${2-}"; shift 2 ;;
    --registry)    REG="${2-}"; shift 2 ;;
    -h|--help) echo "Usage: cross-check-source-registry.sh --source-file <path> --registry <path>" >&2; exit 0 ;;
    *) echo "cross-check-source-registry: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$SF" ] || [ -z "$REG" ]; then
  echo "cross-check-source-registry: --source-file and --registry required" >&2
  exit 2
fi
if [ ! -f "$SF" ]; then echo "cross-check-source-registry: source-file not found: $SF" >&2; exit 1; fi
if [ ! -f "$REG" ]; then echo "cross-check-source-registry: registry not found: $REG" >&2; exit 1; fi

SF_PATH="$SF" REG_PATH="$REG" ruby -ryaml -e '
sf = YAML.unsafe_load_file(ENV["SF_PATH"]) || {}
src = sf.is_a?(Hash) ? (sf["source"] || {}) : {}
link = src["registry_link"].to_s
# Anchor parse: everything after the first # is the registry entry id.
# When no anchor present, fall back to source.id.
anchor = link.include?("#") ? link.split("#", 2)[1] : src["id"].to_s

reg = YAML.unsafe_load_file(ENV["REG_PATH"]) || []
# Operator-facing registry is an array per §2.6.
ids = reg.is_a?(Array) ? reg.map { |e| e.is_a?(Hash) ? e["id"] : nil }.compact : []

if anchor.empty?
  STDERR.write("cross-check-source-registry: registry_link is empty and source.id is missing\n")
  exit 2
end
unless ids.include?(anchor)
  STDERR.write("cross-check-source-registry: registry anchor #{anchor} not found in registry (#{ENV["REG_PATH"]})\n")
  STDERR.write("cross-check-source-registry: known ids=#{ids.join(%q{, })}\n")
  exit 2
end
STDERR.write("cross-check-source-registry: ok anchor=#{anchor} registry=#{ENV["REG_PATH"]}\n")
'
