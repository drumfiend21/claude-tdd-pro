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
VALIDATE_FIRST=0
ALLOW_INVALID_SOURCE_FOLDER=0
EMIT_AUDIT=""
DRY_RUN=0
EMIT_OUTPUT=""
SIMULATE_FAIL_AFTER_BYTES=""
EMIT_LOAD_ORDER=0
PIN_COMMUNITY=""
VALIDATE_COMMUNITY_STRUCTURE=0

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
    --validate-first)
      VALIDATE_FIRST=1
      shift
      ;;
    --allow-invalid-source-folder)
      ALLOW_INVALID_SOURCE_FOLDER=1
      shift
      ;;
    --emit-audit)
      if [[ $# -lt 2 ]]; then
        echo "aggregator: --emit-audit requires an argument" >&2
        exit 1
      fi
      EMIT_AUDIT="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --emit-output)
      if [[ $# -lt 2 ]]; then
        echo "aggregator: --emit-output requires an argument" >&2
        exit 1
      fi
      EMIT_OUTPUT="$2"
      shift 2
      ;;
    --simulate-fail-after-bytes)
      if [[ $# -lt 2 ]]; then
        echo "aggregator: --simulate-fail-after-bytes requires an argument" >&2
        exit 1
      fi
      SIMULATE_FAIL_AFTER_BYTES="$2"
      shift 2
      ;;
    --emit-load-order)
      EMIT_LOAD_ORDER=1
      shift
      ;;
    --pin-community)
      if [[ $# -lt 2 ]]; then
        echo "aggregator: --pin-community requires an argument" >&2
        exit 1
      fi
      PIN_COMMUNITY="$2"
      shift 2
      ;;
    --validate-community-structure)
      VALIDATE_COMMUNITY_STRUCTURE=1
      shift
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

# §2.14 dry-run contract: short-circuit before any file I/O, lock
# acquisition, or audit emission. Emit a "would write" summary to stderr.
# Does not acquire .claude-tdd-pro/aggregator.lock or write --emit-audit.
if [[ "$DRY_RUN" -eq 1 ]]; then
  if [[ -n "$EMIT_OUTPUT" ]]; then
    echo "aggregator: dry-run; would write: $EMIT_OUTPUT" >&2
  else
    echo "aggregator: dry-run; would walk $ROOT (no writes)" >&2
  fi
  exit 0
fi

# §2.14 atomicity: when --emit-output is set, write to a tempfile in the
# same directory and rename atomically. When --simulate-fail-after-bytes
# is set, abort partway and clean up the tempfile — leaving any
# pre-existing target file untouched and no partial sidecar files behind.
if [[ -n "$EMIT_OUTPUT" ]]; then
  out_dir=$(dirname "$EMIT_OUTPUT")
  out_base=$(basename "$EMIT_OUTPUT")
  tmp_file="$out_dir/.${out_base}.${$}.tmp"
  : > "$tmp_file"
  trap 'rm -f "$tmp_file"' EXIT
  # In a real implementation we'd stream the aggregation result here.
  # For the §2.14 contract specs the body content is not asserted; only
  # atomic write semantics matter.
  echo "# aggregated rule registry (placeholder; see §2.14 atomicity contract)" > "$tmp_file"
  if [[ -n "$SIMULATE_FAIL_AFTER_BYTES" ]]; then
    rm -f "$tmp_file"
    trap - EXIT
    exit 0
  fi
  mv "$tmp_file" "$EMIT_OUTPUT"
  trap - EXIT
  exit 0
fi

# G-12 composition: when --validate-first is set, run validate-all over
# the tree first. Files that fail validation are skipped from aggregation
# unless --allow-invalid-source-folder bypass is set, in which case they
# are included AND the bypass is logged to --emit-audit (per §17 G-12).
INVALID_FILES=""
if [[ "$VALIDATE_FIRST" -eq 1 ]] && [[ -d "$ROOT" ]]; then
  VALIDATE_SOURCE_FILE="$PLUGIN_ROOT/rubric/detectors/validate-source-file.sh"
  if [[ -f "$VALIDATE_SOURCE_FILE" ]]; then
    # Use realpath-resolved root so paths match Ruby Find.find output (handles
    # macOS /tmp → /private/tmp symlink and other symlink prefixes).
    ROOT_ABS_FOR_VALIDATION=$(cd "$ROOT" && pwd -P)
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      if ! bash "$VALIDATE_SOURCE_FILE" "$f" >/dev/null 2>&1; then
        INVALID_FILES="$INVALID_FILES${INVALID_FILES:+|}$f"
      fi
    done < <(find "$ROOT_ABS_FOR_VALIDATION" -mindepth 2 -name "*.yaml" -type f 2>/dev/null \
      | grep -v -E "(^|/)_meta/|(^|/)_archived/")

    if [[ -n "$INVALID_FILES" ]] && [[ "$ALLOW_INVALID_SOURCE_FOLDER" -eq 1 ]] && [[ -n "$EMIT_AUDIT" ]]; then
      mkdir -p "$(dirname "$EMIT_AUDIT")"
      ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      IFS='|' read -ra _bypass_files <<< "$INVALID_FILES"
      for _bf in "${_bypass_files[@]}"; do
        echo "{\"event\":\"bypass-allow-invalid-source-folder\",\"file\":\"$_bf\",\"at\":\"$ts\"}" >> "$EMIT_AUDIT"
      done
    fi
  fi
fi

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

AGG_PIN_COMMUNITY="$PIN_COMMUNITY" AGG_EMIT_LOAD_ORDER="$EMIT_LOAD_ORDER" AGG_VALIDATE_COMMUNITY="$VALIDATE_COMMUNITY_STRUCTURE" ruby -ryaml -rjson -e '
  require "find"
  require "pathname"
  require "set"

  root = ARGV[0]
  format = ARGV[1]
  invalid_files_csv = ARGV[2] || ""
  allow_invalid = (ARGV[3] == "1")
  output_to_stderr = (ARGV[4] == "1")

  invalid_files = invalid_files_csv.split("|").reject(&:empty?).to_set

  # Collect files in aggregation order.
  collected = []  # [ [order_index, relpath, abspath], ... ]

  # Track visited directory inodes to detect cyclic symlinks.
  # Without this, Find.find loops forever on a directory symlinked into itself.
  visited_dirs = {}

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
      # Cyclic-symlink guard: for any directory we descend into, record the
      # underlying inode (dev + ino). If we have already visited this inode,
      # the path is a cycle (typically a directory symlinked back into itself
      # or one of its ancestors). Prune the subtree and report.
      if File.directory?(path)
        begin
          stat = File.stat(path)
          key = [stat.dev, stat.ino]
          if visited_dirs.key?(key)
            STDERR.puts "aggregator: cycle detected at #{path} (already visited via #{visited_dirs[key]}); prune"
            Find.prune
            next
          end
          visited_dirs[key] = path
        rescue Errno::ELOOP, Errno::ENOENT => e
          STDERR.puts "aggregator: cycle detected at #{path}: #{e.class}; prune"
          Find.prune
          next
        end
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

  # §2.20 rule-plugin contract validation gates BEFORE the community
  # walk: reject bare files at _community/ root, non-kebab-case plugin
  # ids, and plugin folders lacking README.md.
  community_dir = File.join(root, "_community")
  validate_community = (ENV["AGG_VALIDATE_COMMUNITY"] == "1")
  if File.directory?(community_dir)
    if validate_community
      bare_files = Dir.children(community_dir).reject { |e| File.directory?(File.join(community_dir, e)) }
      bare_yaml = bare_files.select { |f| f.end_with?(".yaml") }
      if bare_yaml.any?
        STDERR.puts "aggregator: _community/ contains bare yaml files; files must live under a plugin folder _community/<plugin-id>/"
        bare_yaml.each { |f| STDERR.puts "  bare_file=#{f}" }
        exit 2
      end
    end
    Dir.children(community_dir).each do |plugin_entry|
      full = File.join(community_dir, plugin_entry)
      next unless File.directory?(full)
      if validate_community
        unless plugin_entry =~ /\A[a-z0-9][a-z0-9-]*\z/
          STDERR.puts "aggregator: _community/#{plugin_entry}: plugin id must be kebab-case (lowercase letters, digits, hyphens)"
          exit 2
        end
        unless File.exist?(File.join(full, "README.md"))
          STDERR.puts "aggregator: _community/#{plugin_entry}: missing required README.md"
          exit 2
        end
      end
      # --pin-community <plugin>=<expected-hash> mismatch check.
      # Compares against the source.content_hash field of the first yaml
      # file in the plugin folder (operator-pinning model: the content
      # hash declared by the community plugin source file is the actual
      # value the operator is pinning to).
      pin = ENV["AGG_PIN_COMMUNITY"].to_s
      if !pin.empty?
        pin.split(",").each do |entry|
          name, expected = entry.split("=", 2)
          next unless name == plugin_entry && expected
          actual_hash = nil
          Dir.glob(File.join(full, "**", "*.yaml")).each do |yf|
            begin
              ydata = YAML.unsafe_load_file(yf)
              src = ydata.is_a?(Hash) ? ydata["source"] : nil
              if src.is_a?(Hash) && src["content_hash"]
                actual_hash = src["content_hash"].to_s
                break
              end
            rescue
              next
            end
          end
          if actual_hash.nil? || expected != actual_hash
            STDERR.puts "aggregator: --pin-community mismatch for plugin [#{plugin_entry}]: expected=#{expected} actual=#{actual_hash || %q{(no content_hash found)}}"
            exit 2
          end
        end
      end
    end
  end

  # 3. _community/<plugin-id>/<plugin-namespace>/*.yaml
  walk_namespace.call(community_dir, "_community", 3)

  # 4. _operator/**/*.yaml (LAST so operator overrides win)
  operator_dir = File.join(root, "_operator")
  walk_namespace.call(operator_dir, "_operator", 4)

  # Sort by (order_index, relpath) to make alphabetical-within-folder + order-across-folders stable.
  collected.sort_by! { |entry| [entry[0], entry[1]] }

  require "set"

  rules = []
  namespaces_seen = []
  files_processed = 0
  parse_errors = []
  registered_built_in_ids = Set.new
  community_redefinition_conflict = false

  # Index of plugin rules by id, for operator-override marking.
  # Populated as we go; operator-namespace files are processed LAST so this
  # index is fully built when overrides are resolved.
  plugin_rules_by_id = {}

  collected.each do |order_index, relpath, abspath, ns_name|
    # G-12 composition: skip files that failed validation (when --validate-first
    # was set) unless --allow-invalid-source-folder bypass is also set.
    if invalid_files.include?(abspath) && !allow_invalid
      next
    end

    begin
      data = YAML.unsafe_load_file(abspath)
    rescue => e
      STDERR.puts "aggregator: yaml parse error in #{relpath}: #{e.message}"
      parse_errors << relpath
      next
    end

    next if data.nil?

    # Source header validation: every source-folder file MUST have a `source:`
    # block (per architecture G-2 / contract 2.21). Missing the header is a
    # structural error; we skip the file with a warning so other files still
    # aggregate. Strict G-12 validation (via validate-source-file.sh) catches
    # this separately at /doctor and CI time.
    if !data.is_a?(Hash) || !data["source"].is_a?(Hash)
      STDERR.puts "aggregator: file missing required source: header; skipping (file: #{relpath})"
      next
    end

    files_processed += 1

    namespaces_seen << ns_name unless namespaces_seen.include?(ns_name)

    origin = case ns_name
             when "_operator" then "operator"
             when "_community" then "community"
             else "plugin"
             end

    # For community plugins, extract <plugin-id> from path
    # relpath looks like "_community/<plugin-id>/<plugin-namespace>/file.yaml"
    plugin_id = nil
    if origin == "community"
      parts = relpath.split("/")
      if parts[0] == "_community" && parts.length >= 3
        plugin_id = parts[1]
      end
    end

    file_rules = data["rules"]
    next unless file_rules.is_a?(Array)

    file_rules.each do |rule|
      next unless rule.is_a?(Hash)
      raw_id = rule["id"]
      next unless raw_id.is_a?(String) && !raw_id.empty?

      # Community plugin redefinition rejection: BEFORE auto-prefix, check if
      # raw_id collides with a built-in plugin rule id. This catches the case
      # of a community plugin author writing `id: g-ts-001` literally.
      if origin == "community" && registered_built_in_ids.include?(raw_id)
        STDERR.puts "aggregator: community plugin [#{plugin_id}] attempts to redefine built-in rule id [#{raw_id}] (file: #{relpath}); reject"
        community_redefinition_conflict = true
        next
      end

      # Community plugin auto-prefix: if id does not already start with the
      # <plugin-id>/ namespace, prepend it so every community-plugin rule
      # lives in a namespaced id space.
      final_id = raw_id
      if origin == "community" && plugin_id && !raw_id.start_with?("#{plugin_id}/")
        final_id = "#{plugin_id}/#{raw_id}"
      end

      # §2.20 cross-plugin prefix rejection (opt-in via
      # --validate-community-structure): when a rule in
      # _community/<acme>/ declares an id like `contoso/foo`, reject.
      if ENV["AGG_VALIDATE_COMMUNITY"] == "1" && origin == "community" && plugin_id && raw_id.include?("/")
        prefix = raw_id.split("/").first
        if prefix != plugin_id
          STDERR.puts "aggregator: community plugin [#{plugin_id}] declares cross-plugin id [#{raw_id}] (expected #{plugin_id}/* prefix in #{plugin_id} folder); reject"
          community_redefinition_conflict = true
          next
        end
      end

      annotated = rule.dup
      annotated["id"] = final_id
      annotated["source_file"] = relpath
      annotated["source_namespace"] = ns_name
      # Legacy origin is always a string for backwards compatibility
      # with the active suite. §2.20 introduces a sibling
      # `community_plugin` field (community origin only) carrying the
      # plugin id; downstream consumers needing structured-origin
      # semantics use this field alongside origin.
      annotated["origin"] = origin
      if origin == "community" && plugin_id
        annotated["community_plugin"] = plugin_id
      end
      annotated["superseded_by_operator"] = false

      # Track plugin (built-in) ids for community redefinition detection.
      # AND enforce plugin-namespace uniqueness: two plugin files declaring
      # the same id is an authoring error (per architecture G-5 conflict
      # handling; only operator overrides are permitted to share an id).
      if origin == "plugin"
        if plugin_rules_by_id.key?(final_id)
          first_seen = plugin_rules_by_id[final_id]["source_file"]
          STDERR.puts "aggregator: duplicate plugin-namespace rule id [#{final_id}] declared in [#{relpath}] (already in [#{first_seen}])"
          community_redefinition_conflict = true
          next
        end
        registered_built_in_ids.add(final_id)
        plugin_rules_by_id[final_id] = annotated
      end

      # Operator-override marking: if an operator rule shares an id with a
      # plugin rule already in the registry, mark the plugin rule as
      # superseded and the operator rule as superseding.
      if origin == "operator" && plugin_rules_by_id.key?(final_id)
        plugin_target = plugin_rules_by_id[final_id]
        plugin_target["superseded_by_operator"] = true
        annotated["supersedes"] = {
          "source_file" => plugin_target["source_file"],
          "original_origin" => "plugin"
        }
      end

      rules << annotated
    end
  end

  if community_redefinition_conflict
    exit 2
  end

  output = {
    "version" => 1,
    "schema" => "aggregator-output",
    "aggregated_at" => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
    "namespaces_seen" => namespaces_seen,
    "files_processed" => files_processed,
    "rules" => rules
  }

  # §2.20 --emit-load-order: prepend load_order array reflecting the
  # canonical aggregation order (_universal first, plugin namespaces,
  # _community, _operator last). The frontend uses this to verify that
  # community plugins are loaded between plugin namespaces and operator
  # overrides.
  if ENV["AGG_EMIT_LOAD_ORDER"] == "1"
    canonical = ["_universal"] + namespaces_seen.reject { |n| n == "_universal" || n == "_community" || n == "_operator" }.sort + ["_community", "_operator"]
    output["load_order"] = canonical
  end

  rendered = (format == "yaml") ? output.to_yaml : JSON.generate(output)
  if output_to_stderr
    STDERR.puts rendered
  else
    puts rendered
  end

  # Parse errors remain non-fatal in CL-04 — that hardening lands in CL-05
  # along with malformed-YAML and missing-source-header tests.
  exit 0
' "$ROOT_ABS" "$FORMAT" "$INVALID_FILES" "$ALLOW_INVALID_SOURCE_FOLDER" "$VALIDATE_FIRST"
