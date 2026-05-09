#!/usr/bin/env bash
# aggregator.sh — walk a source-folder directory tree and emit a single
# aggregated rule registry as JSON.
#
# Usage:
#   bash aggregator.sh [--root <path>] [--format json|yaml]
#
# Defaults:
#   --root   $CLAUDE_PLUGIN_ROOT/generated-code-quality-standards
#   --format json
#
# Aggregation order (per architectural design — source-folder walk):
#   1. _universal/*.yaml                 (cross-cutting baseline)
#   2. plugin namespace folders alphabetically (excluding _universal/_operator/_community/_meta)
#   3. _community/<plugin-id>/<plugin-namespace>/*.yaml  (community plugins)
#   4. _operator/**/*.yaml               (operator additions, processed LAST)
#
# Skipped during walk:
#   - _meta/ directory contents
#   - dotfiles (filename starts with '.')
#   - non-.yaml files
#
# Per-rule annotations added to each rule in the output:
#   - source_file        relative path from root (e.g. "google/tsguide.yaml")
#   - source_namespace   top-level folder under root (e.g. "google", "_operator", "_community")
#   - origin             "plugin" | "operator" | "community"
#
# Output JSON shape:
#   {
#     "version": 1,
#     "schema": "aggregator-output",
#     "namespaces_seen": [...],
#     "files_processed": <int>,
#     "rules": [ ... ]
#   }
#
# Exit codes per detector contract:
#   0 = success
#   1 = tooling error (root missing, ruby/node missing, etc.)
#   2 = aggregation conflict (reserved for subsequent CLs)

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
ROOT="$PLUGIN_ROOT/generated-code-quality-standards"
FORMAT="json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      if [[ $# -lt 2 ]]; then
        echo "aggregator: --root requires an argument" >&2
        exit 1
      fi
      ROOT="$2"
      shift 2
      ;;
    --format)
      if [[ $# -lt 2 ]]; then
        echo "aggregator: --format requires an argument" >&2
        exit 1
      fi
      FORMAT="$2"
      shift 2
      ;;
    -h|--help)
      sed -n '1,40p' "$0" | grep -E '^# ' | sed 's/^# //'
      exit 0
      ;;
    *)
      echo "aggregator: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ ! -d "$ROOT" ]]; then
  echo "aggregator: root directory does not exist: $ROOT" >&2
  exit 1
fi

if [[ "$FORMAT" != "json" && "$FORMAT" != "yaml" ]]; then
  echo "aggregator: --format must be json or yaml (got: $FORMAT)" >&2
  exit 1
fi

if ! command -v ruby >/dev/null 2>&1; then
  echo "aggregator: ruby is required for YAML parsing" >&2
  exit 1
fi

# Ruby does the heavy lifting: walk, parse, aggregate, emit JSON.
# Implementation lives inline so the aggregator is a single script.
ROOT_ABS=$(cd "$ROOT" && pwd -P)

ruby -ryaml -rjson -e '
  require "find"
  require "pathname"

  root = ARGV[0]
  format = ARGV[1]

  # Collect files in aggregation order.
  collected = []  # [ [order_index, relpath, abspath], ... ]

  walk_namespace = lambda do |ns_dir, ns_name, order_index|
    # Find .yaml files in this namespace folder (recursive — supports community plugin sub-namespaces).
    next unless File.directory?(ns_dir)
    Find.find(ns_dir) do |path|
      basename = File.basename(path)
      # Skip dotfiles entirely (including .gitkeep, .DS_Store, etc.)
      if basename.start_with?(".")
        Find.prune if File.directory?(path)
        next
      end
      # Skip _meta within an outer walk (defense-in-depth; we never call walk on _meta directly).
      if File.directory?(path) && basename == "_meta"
        Find.prune
        next
      end
      next unless File.file?(path)
      # Only .yaml files
      next unless basename.end_with?(".yaml")
      relpath = Pathname.new(path).relative_path_from(Pathname.new(root)).to_s
      collected << [order_index, relpath, path, ns_name]
    end
  end

  # 1. _universal/
  universal_dir = File.join(root, "_universal")
  walk_namespace.call(universal_dir, "_universal", 1)

  # 2. plugin namespace folders alphabetically (excluding _ prefixed)
  Dir.children(root).sort.each do |entry|
    next if entry.start_with?("_")  # skip _universal, _operator, _community, _meta
    next if entry.start_with?(".")
    full = File.join(root, entry)
    next unless File.directory?(full)
    walk_namespace.call(full, entry, 2)
  end

  # 3. _community/<plugin-id>/<plugin-namespace>/*.yaml
  community_dir = File.join(root, "_community")
  walk_namespace.call(community_dir, "_community", 3)

  # 4. _operator/**/*.yaml (LAST so operator overrides win)
  operator_dir = File.join(root, "_operator")
  walk_namespace.call(operator_dir, "_operator", 4)

  # Sort by (order_index, relpath) to make alphabetical-within-folder + order-across-folders stable.
  collected.sort_by! { |entry| [entry[0], entry[1]] }

  rules = []
  namespaces_seen = []
  files_processed = 0
  errors = []

  collected.each do |order_index, relpath, abspath, ns_name|
    begin
      data = YAML.load_file(abspath)
    rescue => e
      STDERR.puts "aggregator: yaml parse error in #{relpath}: #{e.message}"
      errors << relpath
      next
    end

    next if data.nil?
    files_processed += 1

    namespaces_seen << ns_name unless namespaces_seen.include?(ns_name)

    origin = case ns_name
             when "_operator" then "operator"
             when "_community" then "community"
             else "plugin"
             end

    file_rules = data["rules"]
    next unless file_rules.is_a?(Array)

    file_rules.each do |rule|
      next unless rule.is_a?(Hash)
      annotated = rule.dup
      annotated["source_file"] = relpath
      annotated["source_namespace"] = ns_name
      annotated["origin"] = origin
      rules << annotated
    end
  end

  output = {
    "version" => 1,
    "schema" => "aggregator-output",
    "aggregated_at" => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
    "namespaces_seen" => namespaces_seen,
    "files_processed" => files_processed,
    "rules" => rules
  }

  if format == "yaml"
    puts output.to_yaml
  else
    puts JSON.generate(output)
  end

  exit (errors.empty? ? 0 : 0)  # in CL-03, parse errors are non-fatal (CL-05 hardens this)
' "$ROOT_ABS" "$FORMAT"
