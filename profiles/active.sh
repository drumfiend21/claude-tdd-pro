#!/usr/bin/env bash
# profiles/active.sh — H-2 profile system implementation per §2.5.
# Loads the active profile (with extends), walks --tree of source-folder
# rule YAMLs (G-1), validates per-rule options against rule.options_schema,
# merges defaults from schema, applies overrides[].rules per-file, and
# (with --emit-resolved) writes a resolved-profile JSON snapshot to stderr.
#
# Per §16 E-2 verbatim:
#   "Rule options with JSON schema validation: options_schema per rule;
#    defaults merged; invalid options block profile activation; detectors
#    receive --options <json>."
#
# Per §16 H-2 verbatim:
#   "Profile system implementation profiles/active.sh."
#
# Per §2.5 profile system:
#   rules: { <id>: off | warn | error | 0 | 1 | 2 | ["error", { options }] }
#   overrides: [{ files, rules }]
#
# Exit codes (detector contract §2.2):
#   0 — profile activated successfully
#   2 — validation failed (invalid options, schema mismatch, etc.)
#   1 — tooling error
#
# Usage:
#   bash profiles/active.sh <profile.yaml> --tree <dir> [--emit-resolved] [--for-file <path>]

set -uo pipefail

PROFILE=""
TREE=""
EMIT_RESOLVED=0
FOR_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tree) TREE="$2"; shift 2 ;;
    --emit-resolved) EMIT_RESOLVED=1; shift ;;
    --for-file) FOR_FILE="$2"; shift 2 ;;
    -*) echo "profiles/active: unknown flag: $1" >&2; exit 2 ;;
    *) [[ -z "$PROFILE" ]] && PROFILE="$1" || { echo "profiles/active: unexpected arg: $1" >&2; exit 2; }; shift ;;
  esac
done

[[ -z "$PROFILE" ]] && { echo "profiles/active: usage: profiles/active.sh <profile.yaml> --tree <dir>" >&2; exit 2; }
[[ ! -f "$PROFILE" ]] && { echo "profiles/active: profile not found: $PROFILE" >&2; exit 2; }
[[ -z "$TREE" ]] && { echo "profiles/active: --tree <dir> required" >&2; exit 2; }
[[ ! -d "$TREE" ]] && { echo "profiles/active: tree not found: $TREE" >&2; exit 2; }

PROFILE="$PROFILE" TREE="$TREE" EMIT_RESOLVED="$EMIT_RESOLVED" FOR_FILE="$FOR_FILE" ruby -ryaml -rjson -rdigest -e '
  profile_path = ENV["PROFILE"]
  tree         = ENV["TREE"]
  emit         = ENV["EMIT_RESOLVED"] == "1"
  for_file     = ENV["FOR_FILE"]

  # Walk profile.extends depth-first; merge rules + overrides; rightmost wins.
  visited = {}
  merged_rules     = {}
  merged_overrides = []
  walk = lambda do |path|
    next if visited[path]
    visited[path] = true
    doc = YAML.load_file(path)
    doc = {} unless doc.is_a?(Hash)
    if doc["extends"].is_a?(Array)
      doc["extends"].each { |e| walk.call(e) if e.is_a?(String) && File.file?(e) }
    end
    if doc["rules"].is_a?(Hash)
      doc["rules"].each { |k, v| merged_rules[k] = v }
    end
    if doc["overrides"].is_a?(Array)
      merged_overrides.concat(doc["overrides"])
    end
  end
  walk.call(profile_path)

  # Load all rule definitions from --tree (G-1 source folders); each YAML
  # file has rules:[] each with id + options_schema + ... per §2.1.
  rule_defs = {}
  Dir.glob(File.join(tree, "**", "*.yaml")).each do |rf|
    sf = YAML.load_file(rf)
    next unless sf.is_a?(Hash) && sf["rules"].is_a?(Array)
    sf["rules"].each do |r|
      next unless r.is_a?(Hash) && r["id"]
      rule_defs[r["id"]] = r
    end
  end

  # Minimal JSON Schema validator supporting the subset used by §2.1
  # options_schema declarations: type (object|integer|string|boolean),
  # properties, required, additionalProperties, recursive.
  type_ok = lambda do |val, t|
    case t
    when "object"  then val.is_a?(Hash)
    when "integer" then val.is_a?(Integer)
    when "string"  then val.is_a?(String)
    when "boolean" then val == true || val == false
    when "array"   then val.is_a?(Array)
    when "number"  then val.is_a?(Numeric)
    else true
    end
  end

  validate = lambda do |val, schema, path_str|
    errs = []
    return errs unless schema.is_a?(Hash)
    if schema["type"] && !type_ok.call(val, schema["type"])
      errs << "schema mismatch at #{path_str}: expected type #{schema["type"]}, got #{val.class.name.downcase}"
      return errs
    end
    if schema["type"] == "object" && val.is_a?(Hash)
      props = schema["properties"] || {}
      req   = schema["required"]   || []
      addl  = schema["additionalProperties"]
      req.each do |k|
        unless val.key?(k)
          errs << "schema mismatch at #{path_str}: required property \"#{k}\" missing"
        end
      end
      val.each do |k, v|
        if props.key?(k)
          errs.concat(validate.call(v, props[k], "#{path_str}.#{k}"))
        elsif addl == false
          errs << "schema mismatch at #{path_str}: additionalProperties=false rejects key \"#{k}\""
        end
      end
    end
    errs
  end

  # Merge schema defaults into options object (additive: only fills missing keys).
  merge_defaults = lambda do |opts, schema|
    return opts unless schema.is_a?(Hash) && schema["type"] == "object"
    out = opts.is_a?(Hash) ? opts.dup : {}
    (schema["properties"] || {}).each do |k, v|
      if v.is_a?(Hash) && v.key?("default") && !out.key?(k)
        out[k] = v["default"]
      end
    end
    out
  end

  # fnmatch glob match for overrides[].files
  glob_match = lambda do |patterns, file|
    Array(patterns).any? { |p| File.fnmatch?(p, file, File::FNM_PATHNAME | File::FNM_EXTGLOB) }
  end

  resolved = {}
  errors   = []

  # Resolve each rule from merged_rules.
  merged_rules.each do |rid, conf|
    sev    = conf
    opts   = nil
    if conf.is_a?(Array)
      if conf.length != 2
        errors << "rule #{rid}: array_length=#{conf.length} expected_length=2"
        next
      end
      sev  = conf[0]
      opts = conf[1]
    end

    rdef = rule_defs[rid]
    if opts && opts.is_a?(Hash) && !opts.empty?
      unless rdef
        errors << "rule #{rid}: options provided but rule not found in --tree"
        next
      end
      schema = rdef["options_schema"]
      if schema.nil? || (schema.is_a?(Hash) && schema.empty?)
        errors << "rule #{rid}: options provided but rule has no options_schema (required for [severity, options] form)"
        next
      end
      verrs = validate.call(opts, schema, rid)
      if !verrs.empty?
        verrs.each { |e| errors << "rule #{rid}: options invalid: #{e}" }
        next
      end
      resolved[rid] = { "severity" => sev.to_s, "options" => merge_defaults.call(opts, schema) }
    elsif rdef && rdef["options_schema"].is_a?(Hash)
      # No explicit options; still merge defaults from schema.
      resolved[rid] = { "severity" => sev.to_s, "options" => merge_defaults.call({}, rdef["options_schema"]) }
    else
      resolved[rid] = { "severity" => sev.to_s, "options" => {} }
    end
  end

  # Apply overrides[] for the requested file (if any).
  if !for_file.nil? && !for_file.empty?
    merged_overrides.each do |ov|
      next unless ov.is_a?(Hash)
      next unless glob_match.call(ov["files"], for_file)
      next unless ov["rules"].is_a?(Hash)
      ov["rules"].each do |rid, conf|
        sev = conf
        opts = nil
        if conf.is_a?(Array) && conf.length == 2
          sev  = conf[0]
          opts = conf[1]
        end
        existing = resolved[rid] || { "severity" => sev.to_s, "options" => {} }
        merged = existing["options"].dup
        if opts.is_a?(Hash)
          opts.each { |k, v| merged[k] = v }
        end
        resolved[rid] = { "severity" => sev.to_s, "options" => merged }
      end
    end
  end

  if !errors.empty?
    errors.each { |e| STDERR.puts e }
    exit 2
  end

  if emit
    # Cache key per E-12 — sha256 over (rule-id + resolved-options) to
    # demonstrate that options participate in invalidation. Rule version
    # / plugin version layered in by E-12 substrate proper.
    out = { "rules" => {} }
    resolved.keys.sort.each do |rid|
      r = resolved[rid]
      sorted_opts = r["options"].sort.to_h
      key_input = JSON.generate([rid, sorted_opts])
      out["rules"][rid] = {
        "severity" => r["severity"],
        "options"  => sorted_opts,
        "cache_key" => "sha256:" + Digest::SHA256.hexdigest(key_input)
      }
    end
    STDERR.puts JSON.generate(out)
  end

  exit 0
'
