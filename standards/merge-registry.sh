#!/usr/bin/env bash
# standards/merge-registry.sh — S-12 registry merge per §2.6:
# combines plugin-shipped standards/sources.yaml (plugin-internal
# schema) with operator-edited .claude-tdd-pro/STANDARDS-URLS.yaml
# (operator-facing schema). Operator entries win on overlapping ids;
# operator-only entries gain origin: operator + class:
# operator-curated; bundled entries cannot be deleted via operator
# edit (only override).
#
# Usage:
#   merge-registry.sh --catalog <plugin.yaml> --operator <operator.yaml>
#                     --emit <merged.yaml> [--preserve-comments]

set -uo pipefail

CATALOG=""
OPERATOR=""
EMIT=""
PRESERVE_COMMENTS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --catalog) CATALOG="$2"; shift 2 ;;
    --operator) OPERATOR="$2"; shift 2 ;;
    --emit) EMIT="$2"; shift 2 ;;
    --preserve-comments) PRESERVE_COMMENTS=1; shift ;;
    *) echo "merge-registry: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$CATALOG" || -z "$OPERATOR" || -z "$EMIT" ]] && { echo "merge-registry: --catalog, --operator, --emit required" >&2; exit 2; }
[[ ! -f "$CATALOG" ]] && { echo "merge-registry: catalog not found: $CATALOG" >&2; exit 2; }
[[ ! -f "$OPERATOR" ]] && { echo "merge-registry: operator not found: $OPERATOR" >&2; exit 2; }

CATALOG="$CATALOG" OPERATOR="$OPERATOR" EMIT="$EMIT" PRESERVE_COMMENTS="$PRESERVE_COMMENTS" ruby -ryaml -e '
  catalog = YAML.load_file(ENV["CATALOG"]) || []
  operator = YAML.load_file(ENV["OPERATOR"]) || []
  preserve_comments = ENV["PRESERVE_COMMENTS"] == "1"
  comments = []
  if preserve_comments
    File.read(ENV["OPERATOR"]).each_line do |line|
      comments << line.chomp if line.start_with?("#")
    end
  end

  out = catalog.dup
  catalog_ids = catalog.map { |e| e["id"] }
  operator.each do |e|
    next unless e.is_a?(Hash) && e["id"]
    idx = catalog_ids.index(e["id"])
    if idx
      # Operator override of bundled entry: operator-set keys appear
      # FIRST in the merged map (immediately after id) so a "disable:
      # true" marker is visible in a tight grep-with-context. Catalog
      # values are preserved for non-overridden keys.
      orig = out[idx]
      merged = { "id" => orig["id"] }
      e.each_key { |k| merged[k] = e[k] unless k == "id" }
      orig.each_key { |k| merged[k] = orig[k] unless merged.key?(k) }
      out[idx] = merged
    else
      # Operator-only entry: tag with origin + class.
      e["origin"] = "operator"
      e["class"] ||= "operator-curated"
      out << e
    end
  end

  File.open(ENV["EMIT"], "w") do |f|
    if preserve_comments
      comments.each { |c| f.puts c }
    end
    f.puts out.to_yaml.sub(/\A---\n/, "")
  end
'
