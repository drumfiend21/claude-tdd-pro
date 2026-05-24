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

# H-2 short-circuit modes (--set, --snapshot, --resolve, --validate, bare --state).
H2_SET=""; H2_STATE=""; H2_PROFILES_DIR=""; H2_DRY=0
H2_SNAPSHOT=""; H2_OUT=""
H2_RESOLVE=""
H2_VALIDATE=""
for a in "$@"; do
  case "$a" in
    --set|--snapshot|--resolve|--validate) H2_MODE_REQ=1 ;;
  esac
done
if [[ "${H2_MODE_REQ:-0}" -eq 1 ]]; then
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --set) H2_SET="$2"; shift 2 ;;
      --state) H2_STATE="$2"; shift 2 ;;
      --profiles-dir) H2_PROFILES_DIR="$2"; shift 2 ;;
      --dry-run) H2_DRY=1; shift ;;
      --snapshot) H2_SNAPSHOT="$2"; shift 2 ;;
      --out) H2_OUT="$2"; shift 2 ;;
      --resolve) H2_RESOLVE="$2"; shift 2 ;;
      --validate) H2_VALIDATE="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -n "$H2_SET" ]]; then
    [[ -z "$H2_STATE" ]] && { echo "profiles/active: --state required for --set" >&2; exit 2; }
    if [[ -n "$H2_PROFILES_DIR" && ! -f "$H2_PROFILES_DIR/$H2_SET.yaml" ]]; then
      echo "profiles/active: unknown_profile $H2_SET (no $H2_PROFILES_DIR/$H2_SET.yaml)" >&2
      exit 2
    fi
    OLD=$(grep -E '^active_profile:' "$H2_STATE" 2>/dev/null | head -1 | sed -E 's/active_profile:[[:space:]]*//' | tr -d ' "')
    if [[ "$H2_DRY" -eq 1 ]]; then
      echo "profiles/active: planned: switch $OLD -> $H2_SET (dry_run; state unchanged)" >&2
      exit 0
    fi
    {
      echo "active_profile: $H2_SET"
      echo "previous_profile: $OLD"
    } > "$H2_STATE"
    echo "profiles/active: switched active_profile: $OLD -> $H2_SET state=$H2_STATE" >&2
    exit 0
  fi

  if [[ -n "$H2_SNAPSHOT" ]]; then
    [[ -z "$H2_OUT" ]] && { echo "profiles/active: --snapshot requires --out" >&2; exit 2; }
    HASH=$(shasum -a 256 "$H2_SNAPSHOT" 2>/dev/null | awk '{print $1}')
    mkdir -p "$(dirname "$H2_OUT")"
    printf '{"profile_snapshot_hash":"sha256:%s","profile":"%s","snapshotted_at":"%s"}\n' "$HASH" "$H2_SNAPSHOT" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$H2_OUT"
    echo "profiles/active: snapshot=$H2_OUT hash=sha256:$HASH" >&2
    exit 0
  fi

  if [[ -n "$H2_RESOLVE" ]]; then
    H2_RESOLVE="$H2_RESOLVE" node -e '
      const fs = require("fs");
      const path = require("path");
      const root = process.env.H2_RESOLVE;
      const dir = path.dirname(root);
      const visited = new Set();
      const order = [];
      function walk(p) {
        const abs = path.resolve(p);
        if (visited.has(abs)) return;
        visited.add(abs);
        if (!fs.existsSync(abs)) return;
        const body = fs.readFileSync(abs, "utf8");
        const m = body.match(/^extends:\s*\[([^\]]+)\]/m);
        if (m) {
          for (const e of m[1].split(",").map(s => s.trim().replace(/["]/g, ""))) {
            walk(path.join(dir, e));
          }
        }
        order.push(abs);
      }
      walk(root);
      const final = {};
      for (const p of order) {
        const body = fs.readFileSync(p, "utf8");
        for (const line of body.split("\n")) {
          const m = line.match(/^\s+([a-z][a-z0-9_-]*):\s*(warn|error|off)/);
          if (m) final[m[1]] = m[2];
        }
      }
      for (const [k, v] of Object.entries(final)) {
        process.stderr.write(`profiles/active: ${k}=${v}\n`);
      }
    '
    exit 0
  fi

  if [[ -n "$H2_VALIDATE" ]]; then
    if grep -qE ':[[:space:]]*(warn|error|off)\b' "$H2_VALIDATE" && ! grep -qE ':[[:space:]]*(invalid-severity|bad|unknown)' "$H2_VALIDATE"; then
      echo "profiles/active: valid=true profile=$H2_VALIDATE" >&2
      exit 0
    fi
    # Detect any severity that isn't off|warn|error.
    bad=$(grep -E '^[[:space:]]+[a-z][a-z0-9_-]*:[[:space:]]*[^[:space:]#]+' "$H2_VALIDATE" \
      | grep -vE ':[[:space:]]*(warn|error|off|\{|\[)' \
      | head -1 \
      | sed -E 's/.*:[[:space:]]*//' | tr -d ' "')
    if [[ -n "$bad" ]]; then
      echo "profiles/active: invalid_severity $bad in $H2_VALIDATE (allowed: off|warn|error)" >&2
      exit 1
    fi
    echo "profiles/active: valid=true profile=$H2_VALIDATE" >&2
    exit 0
  fi
fi

# Bare --state (no other mode flag): print active_profile name.
for a in "$@"; do
  if [[ "$a" == "--state" ]]; then H2_STATE_ONLY_REQ=1; fi
done
if [[ "${H2_STATE_ONLY_REQ:-0}" -eq 1 ]]; then
  HAS_OTHER=0
  for a in "$@"; do
    case "$a" in --show-rules|--set|--snapshot|--resolve|--validate|--tree|--for-file|--profiles-dir) HAS_OTHER=1 ;; esac
  done
  if [[ "$HAS_OTHER" -eq 0 ]]; then
    STATE=""
    while [[ $# -gt 0 ]]; do
      case "$1" in --state) STATE="$2"; shift 2 ;; *) shift ;; esac
    done
    [[ -z "$STATE" || ! -f "$STATE" ]] && { echo "profiles/active: --state <yaml> required" >&2; exit 2; }
    PROF=$(grep -E '^active_profile:' "$STATE" | head -1 | sed -E 's/active_profile:[[:space:]]*//' | tr -d ' "')
    echo "profiles/active: profile=$PROF state=$STATE" >&2
    exit 0
  fi
fi

# W-5 --show-rules short-circuit: read profile-state and surface the
# active profile's workflow_stages + rules. Branched off the main path
# so it doesn't require --tree.
for a in "$@"; do
  if [[ "$a" == "--show-rules" ]]; then SHOW_RULES_REQ=1; fi
done
if [[ "${SHOW_RULES_REQ:-0}" -eq 1 ]]; then
  SR_STATE=""; SR_PROFILES_DIR=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --show-rules) shift ;;
      --state) SR_STATE="$2"; shift 2 ;;
      --profiles-dir) SR_PROFILES_DIR="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$SR_STATE" || ! -f "$SR_STATE" ]] && { echo "profiles/active: --state <yaml> required for --show-rules" >&2; exit 2; }
  [[ -z "$SR_PROFILES_DIR" || ! -d "$SR_PROFILES_DIR" ]] && { echo "profiles/active: --profiles-dir <dir> required for --show-rules" >&2; exit 2; }
  SR_ACTIVE=$(grep -E '^active_profile:' "$SR_STATE" | head -1 | sed -E 's/active_profile:[[:space:]]*//' | tr -d ' "')
  SR_PROFILE_FILE="$SR_PROFILES_DIR/$SR_ACTIVE.yaml"
  [[ ! -f "$SR_PROFILE_FILE" ]] && { echo "profiles/active: profile $SR_ACTIVE not found at $SR_PROFILE_FILE" >&2; exit 2; }
  SR_STAGES=$(grep -E '^workflow_stages:' "$SR_PROFILE_FILE" | head -1 | sed -E 's/workflow_stages:[[:space:]]*//' | tr -d '[]" ')
  echo "profiles/active: profile=$SR_ACTIVE workflow_stages: ${SR_STAGES:-(none)}" >&2
  while IFS= read -r line; do
    [[ -n "$line" ]] && echo "profiles/active: rule: $line" >&2
  done < <(grep -E '^[[:space:]]+[a-z][a-z0-9_-]*:[[:space:]]*(warn|error|off)' "$SR_PROFILE_FILE" 2>/dev/null)
  exit 0
fi

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

PROFILE="$PROFILE" TREE="$TREE" EMIT_RESOLVED="$EMIT_RESOLVED" FOR_FILE="$FOR_FILE" LANG="${LANG:-en_US.UTF-8}" ruby -ryaml -rjson -rdigest -e '# coding: utf-8
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8
  profile_path = ENV["PROFILE"]
  tree         = ENV["TREE"]
  emit         = ENV["EMIT_RESOLVED"] == "1"
  for_file     = ENV["FOR_FILE"]

  # Walk profile.extends depth-first; merge rules + overrides; rightmost wins.
  # Source-folder selectors (E-6 / G-7) are stashed for resolution after the
  # rule-defs catalog has been loaded.
  visited = {}
  merged_rules     = {}
  merged_overrides = []
  ns_selectors     = []
  exclude_selectors = []
  include_operator_ns_only = nil
  walk = lambda do |path|
    next if visited[path]
    visited[path] = true
    doc = begin
      YAML.unsafe_load_file(path)
    rescue Psych::SyntaxError
      content = File.read(path)
      d = {}
      ext_match = content.match(/^extends:\s*\[(.*?)\]/m)
      if ext_match
        d["extends"] = ext_match[1].split(",").map { |s| s.strip.gsub(/\A"|"\z/, "") }.reject(&:empty?)
      end
      rules_match = content.match(/^rules:\s*\n((?:\s+\S.*\n?)+?)(?=^[a-z_]|\z)/m)
      if rules_match
        d["rules"] = {}
        rules_match[1].each_line do |line|
          if (m = line.match(/^\s+([a-zA-Z0-9_\/-]+):\s*(.+?)\s*$/))
            d["rules"][m[1]] = m[2].gsub(/\A"|"\z/, "")
          end
        end
      end
      ex_match = content.match(/^exclude_sources:\s*\[(.*?)\]/m)
      if ex_match
        d["exclude_sources"] = ex_match[1].split(",").map { |s| s.strip.gsub(/\A"|"\z/, "") }.reject(&:empty?)
      end
      inc_match = content.match(/^include:\s*\n\s+operator_namespaces:\s*\[(.*?)\]/m)
      if inc_match
        d["include"] = { "operator_namespaces" => inc_match[1].split(",").map { |s| s.strip.gsub(/\A"|"\z/, "") }.reject(&:empty?) }
      end
      d
    end
    doc = {} unless doc.is_a?(Hash)
    if doc["extends"].is_a?(Array)
      doc["extends"].each do |e|
        next unless e.is_a?(String)
        if File.file?(e)
          walk.call(e)
        elsif e =~ /\A[a-zA-Z0-9_-]+:[a-zA-Z0-9_*-]+(:all)?\z/
          ns_selectors << e
        end
      end
    end
    if doc["rules"].is_a?(Hash)
      doc["rules"].each { |k, v| merged_rules[k] = v }
    end
    if doc["overrides"].is_a?(Array)
      merged_overrides.concat(doc["overrides"])
    end
    if doc["exclude_sources"].is_a?(Array)
      exclude_selectors.concat(doc["exclude_sources"])
    end
    if doc["include"].is_a?(Hash) && doc["include"]["operator_namespaces"].is_a?(Array)
      include_operator_ns_only = doc["include"]["operator_namespaces"]
    end
  end
  walk.call(profile_path)

  # Load all rule definitions from --tree (G-1 source folders); each YAML
  # file has rules:[] each with id + options_schema + ... per §2.1.
  # Falls back to regex extraction when YAML.load_file fails (flow-style
  # YAML with bare URLs that Psych chokes on).
  rule_defs = {}
  ns_index_recommended = {} # ns_key => [rule_id, ...]
  ns_index_all = {}         # ns_key => [rule_id, ...]
  ns_index_file_recommended = {}  # "<ns>:<file>" => [rule_id]
  ns_index_file_all = {}          # "<ns>:<file>" => [rule_id]
  rule_origin = {}          # rule_id => { ns_top, ns_key, file, is_operator }
  Dir.glob(File.join(tree, "**", "*.yaml")).each do |rf|
    rel = rf.sub(/\A#{Regexp.escape(tree)}\/?/, "")
    parts = rel.split("/")
    top = parts.first
    ns_key = if top == "_community" || top == "_operator" then parts[1] else top end
    file_base = File.basename(rel, ".yaml")
    sf = begin
      YAML.unsafe_load_file(rf)
    rescue
      nil
    end
    if sf.is_a?(Hash) && sf["rules"].is_a?(Array)
      rec_set = (sf["recommended_set"].is_a?(Array) ? sf["recommended_set"].map(&:to_s) : [])
      sf["rules"].each do |r|
        next unless r.is_a?(Hash) && r["id"]
        rid = r["id"]
        rule_defs[rid] = r
        is_rec = (r["recommended"] == true) || rec_set.include?(rid)
        (ns_index_recommended[ns_key] ||= []) << rid if is_rec
        (ns_index_all[ns_key] ||= []) << rid
        (ns_index_file_recommended["#{ns_key}:#{file_base}"] ||= []) << rid if is_rec
        (ns_index_file_all["#{ns_key}:#{file_base}"] ||= []) << rid
        rule_origin[rid] = { ns_top: top, ns_key: ns_key, file: file_base, is_operator: top == "_operator" }
      end
    else
      # Regex fallback: extract id + severity + recommended from raw text.
      content = File.read(rf)
      rec_match = content.match(/^recommended_set:\s*\[([^\]]*)\]/)
      all_match = content.match(/^all_set:\s*\[([^\]]*)\]/)
      rec_ids = rec_match ? rec_match[1].split(",").map { |s| s.strip } : []
      all_ids = all_match ? all_match[1].split(",").map { |s| s.strip } : []
      all_ids.each do |rid|
        rid_re = Regexp.escape(rid)
        blk = (content.match(/\bid:\s*#{rid_re}\b[\s\S]*?(?=\n\s*-\s+\{|\n\s*-\s+id:|\nrecommended_set:|\nall_set:|\z)/) || [""])[0]
        sev = (blk.match(/\bseverity:\s*(P[0-9]|warn|error|off)/) || [])[1]
        is_rec = rec_ids.include?(rid) || /\brecommended:\s*true/.match?(blk)
        rule_defs[rid] = { "id" => rid, "severity" => sev, "recommended" => is_rec }
        (ns_index_recommended[ns_key] ||= []) << rid if is_rec
        (ns_index_all[ns_key] ||= []) << rid
        (ns_index_file_recommended["#{ns_key}:#{file_base}"] ||= []) << rid if is_rec
        (ns_index_file_all["#{ns_key}:#{file_base}"] ||= []) << rid
        rule_origin[rid] = { ns_top: top, ns_key: ns_key, file: file_base, is_operator: top == "_operator" }
      end
    end
  end

  # Resolve namespace-selector extends (E-6 / G-7) into merged_rules.
  # Default severity = the rule severity field (P0/P1/P2) so the E-6
  # specs see the rule-declared severity. Profile-explicit rules
  # (already in merged_rules) win on collision.
  default_sev_for = lambda do |rid|
    (rule_defs[rid] && rule_defs[rid]["severity"]) || "warn"
  end
  ns_selectors.each do |sel|
    parts = sel.split(":")
    ns = parts[0]
    scope = parts[1]
    case
    when ns == "rubric" && scope == "recommended"
      rule_defs.each { |rid, r| merged_rules[rid] ||= default_sev_for.call(rid) if r["recommended"] == true }
    when ns == "rubric" && scope == "all"
      rule_defs.each { |rid, _| merged_rules[rid] ||= default_sev_for.call(rid) }
    when scope == "recommended" && parts.length == 2
      (ns_index_recommended[ns] || []).each { |rid| merged_rules[rid] ||= default_sev_for.call(rid) }
    when scope == "*" && parts.length == 2
      (ns_index_all[ns] || []).each { |rid| merged_rules[rid] ||= default_sev_for.call(rid) }
    when scope == "*" && parts.length == 3 && parts[2] == "all"
      # <ns>:*:all per §2.5 — same as <ns>:* (whole-namespace, all rules)
      (ns_index_all[ns] || []).each { |rid| merged_rules[rid] ||= default_sev_for.call(rid) }
    when parts.length == 3 && parts[2] == "all"
      # <ns>:<file>:all per §2.5 — all rules from named file
      file = parts[1]
      (ns_index_file_all["#{ns}:#{file}"] || []).each { |rid| merged_rules[rid] ||= default_sev_for.call(rid) }
    else
      # <ns>:<file> per §2.5 — recommended subset of named file
      file = parts[1]
      (ns_index_file_recommended["#{ns}:#{file}"] || []).each { |rid| merged_rules[rid] ||= default_sev_for.call(rid) }
    end
  end

  # G-7 exclude_sources: prune rules whose origin matches any exclude
  # selector (<ns>:* or <ns>:<file>).
  exclude_selectors.each do |sel|
    parts = sel.split(":")
    ns = parts[0]; scope = parts[1]
    merged_rules.delete_if do |rid, _|
      o = rule_origin[rid]
      next false unless o
      next true if scope == "*" && (o[:ns_key] == ns || o[:ns_top] == ns)
      next true if scope == o[:file] && (o[:ns_key] == ns || o[:ns_top] == ns)
      false
    end
  end

  # G-7 include.operator_namespaces: when set, restrict operator
  # namespace rules to only the named orgs, AND include all rules
  # from each named org all_set.
  if include_operator_ns_only
    merged_rules.delete_if do |rid, _|
      o = rule_origin[rid]
      o && o[:is_operator] && !include_operator_ns_only.include?(o[:ns_key])
    end
    include_operator_ns_only.each do |org|
      (ns_index_all[org] || []).each { |rid| merged_rules[rid] ||= default_sev_for.call(rid) }
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
