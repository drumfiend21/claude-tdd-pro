#!/usr/bin/env bash
# rubric/enforce-file.sh - enforce the applicable CTP rules against a SINGLE file
# (§28.27). This is the write-time / generation-time projection of the §28.17 enforce.sh
# contract: given one file (just written by Edit/Write, or just emitted by /architect),
# discover every rule whose `applies` glob matches it and run that rule's detector against
# only that file. Architecture & ADR prose additionally runs the §28.24 prose-as-code
# rules (applies_to_prose) through prose-judge.sh, so a design that violates a rule
# red-flags at the moment it is written.
#
# Rule discovery (no per-call config): rules come from the SAME catalog +
# cloud/config manifests that enforce.sh uses, so write-time and tree-time enforce the
# identical rule set.
#
# The §16 config plane (E-1 severity / enable-disable, E-3 glob overrides) is OPTIONAL and
# threaded via --profile <profile.yaml>: when given, the effective per-file config is resolved
# through profiles/active.sh --emit-resolved (the §2.5 resolver) and applied BEFORE enforcement --
# a rule resolved to `off`/`false` is skipped (disabled); `error`/`warn` force the grade. When
# --profile is ABSENT, behaviour is byte-identical to before (every catalog rule active at its
# native severity), so the config plane is purely additive and cannot regress existing verdicts.
#
# CLI:  --file <path> [--root <dir>] [--profile <profile.yaml>] [--quiet]
# stderr: per finding `enforce-file file=<f> rule=<id> verdict=<fail|not_enforced>`;
#         summary `enforce-file file=<f> status=<green|red|incomplete> fail=<n> not_enforced=<n>`
# Exit: 0 clean / 1 >=1 fail / 3 no fail but >=1 not_enforced / 2 usage.

set -uo pipefail
FILE=""; ROOT=""; QUIET=0; PROFILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --file)    FILE="${2-}"; shift 2 ;;
    --root)    ROOT="${2-}"; shift 2 ;;
    --profile) PROFILE="${2-}"; shift 2 ;;
    --quiet)   QUIET=1; shift ;;
    -h|--help) echo "Usage: enforce-file.sh --file <path> [--root <dir>] [--profile <profile.yaml>] [--quiet]" >&2; exit 0 ;;
    *) echo "enforce-file: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$FILE" ] && { echo "enforce-file: --file <path> required" >&2; exit 2; }
[ ! -f "$FILE" ] && { echo "enforce-file: not a file: $FILE" >&2; exit 2; }

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

FILE="$FILE" ROOT="$ROOT" QUIET="$QUIET" PROFILE="$PROFILE" PLUGIN_ROOT="$PLUGIN_ROOT" ruby -ryaml -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  file = ENV["FILE"]; plugin = ENV["PLUGIN_ROOT"]; quiet = ENV["QUIET"] == "1"
  profile = ENV["PROFILE"].to_s
  base = File.basename(file)

  # --- catalog: id -> detector, severity, and the prose-bound id set -------------------
  catalog = {}; prose = {}; sev = {}
  Dir[File.join(plugin, "generated-code-quality-standards", "*", "*.yaml")].each do |f|
    d = (YAML.unsafe_load_file(f) rescue nil); next unless d.is_a?(Hash)
    (d["rules"] || []).each do |r|
      next unless r.is_a?(Hash) && r["id"] && r["detector"]
      catalog[r["id"]] = r["detector"]
      sev[r["id"]] = r["severity"].to_s
      prose[r["id"]] = true if r["applies_to_prose"] == true
    end
  end

  # --- applies-globs + severity + mode from the cloud + config manifests ---------------
  applies = {}; mode = {}
  %w[cloud-guidance-rules.json config-guidance-rules.json universal-pattern-rules.json].each do |mfn|
    mp = File.join(plugin, "rubric", "detectors", mfn); next unless File.exist?(mp)
    (JSON.parse(File.read(mp))["rules"] || {}).each do |id, s|
      applies[id] = s["applies"].to_s
      mode[id] = s["mode"].to_s
      sev[id] = s["severity"].to_s if sev[id].to_s.empty? && s["severity"]
    end
  end
  # --- §16 config plane (E-1/E-3): resolve effective per-file config via the §2.5 resolver -----
  # disabled[id] => skip the rule entirely (resolved to off/false/0); forced[id] => override the
  # blocking grade (error -> block, warn -> advisory). Empty unless --profile given => no-op.
  disabled = {}; forced = {}
  unless profile.empty?
    tmp = File.join((ENV["TMPDIR"] || "/tmp"), "ef-resolve-#{Process.pid}.json")
    system("bash", File.join(plugin, "profiles", "active.sh"), profile, "--tree",
           File.join(plugin, "generated-code-quality-standards"), "--emit-resolved",
           "--for-file", file, out: File::NULL, err: tmp)
    raw = (File.read(tmp) rescue ""); (File.delete(tmp) rescue nil)
    doc = nil
    raw.each_line { |ln| ln = ln.strip; next unless ln.start_with?("{"); (doc = JSON.parse(ln)) rescue next }
    off_vals  = ["false", "off", "0", "none", "0.0"]
    warn_vals = ["warn", "warning", "1"]
    err_vals  = ["error", "2"]
    ((doc && doc["rules"]) || {}).each do |id, h|
      s = h.is_a?(Hash) ? h["severity"].to_s : h.to_s
      if    off_vals.include?(s)  then disabled[id] = true
      elsif err_vals.include?(s)  then forced[id] = "block"
      elsif warn_vals.include?(s) then forced[id] = "warn"
      end
    end
  end

  # Blocking (error) vs advisory (warning) at write/generation time:
  #   * a violation blocks only when it is P0/P1 AND NOT a `require`-mode rule.
  #   * `require`-mode rules (e.g. "a pod should declare resources:") are presumptive --
  #     glob-applies can match a file that is not the kind the rule targets (a compose
  #     file matched by a k8s *.yml rule), so a require-absent is always advisory, never a
  #     blocking false-positive. forbid/wrapper/prose violations (privileged: true present,
  #     0.0.0.0/0 in an ADR, malformed JSON) are unambiguous and block.
  #   * a §16 profile override wins: forced "block"/"warn" supersedes the native grade.
  blocking = ->(id) {
    return true  if forced[id] == "block"
    return false if forced[id] == "warn"
    %w[P0 P1].include?(sev[id].to_s) && mode[id].to_s != "require"
  }

  def glob_for(id, det)
    # rules with no manifest applies-glob are the Layer-1 wrappers / structural detectors,
    # scoped by id prefix to the file kind they validate.
    case id
    when /^g-json-/ then "*.json"
    when /^g-yaml-/ then "*.yaml,*.yml"
    when /^g-md-/, /^g-doc-/, /^g-arch-/ then "*.md"
    else nil
    end
  end

  def matches?(file, base, glob)
    glob.split(",").any? do |g|
      g = g.strip
      File.fnmatch(g, base, File::FNM_PATHNAME) ||
        File.fnmatch(File.join("**", g), file, File::FNM_PATHNAME) ||
        File.fnmatch(File.join("**", g), File.expand_path(file), File::FNM_PATHNAME)
    end
  end

  # --- which rules apply to THIS file ------------------------------------------------
  applicable = []   # [id, detector]
  catalog.each do |id, det|
    next if disabled[id]          # §16: rule resolved to off/false for this file -> skip
    g = applies[id].to_s.empty? ? glob_for(id, det) : applies[id]
    next if g.nil? || g.empty?
    applicable << [id, det] if matches?(file, base, g)
  end

  fails = []; unenf = []
  applicable.each do |id, det|
    detp = File.join(plugin, "rubric", "detectors", det)
    next unless File.exist?(detp)
    system("bash", detp, "--rule", id, "--paths", file, out: File::NULL, err: File::NULL)
    ec = $?.exitstatus
    fails << [id, det] if ec == 1
    unenf << [id, det] if ec == 3
  end

  # --- prose-as-code: architectural Markdown also runs the applies_to_prose rules -----
  if base.end_with?(".md")
    pj = File.join(plugin, "rubric", "detectors", "prose-judge.sh")
    prose.keys.each do |id|
      next if disabled[id]          # §16: prose rule disabled for this file -> skip
      next unless File.exist?(pj)
      system("bash", pj, "--rule", id, "--paths", file, out: File::NULL, err: File::NULL)
      ec = $?.exitstatus
      fails << [id, "prose-judge.sh"] if ec == 1
      unenf << [id, "prose-judge.sh"] if ec == 3
    end
  end

  fails.uniq!; unenf.uniq! { |x| x[0] }
  block_fails = fails.select { |id, _| blocking.call(id) }
  warn_fails  = fails.reject { |id, _| blocking.call(id) }
  unless quiet
    block_fails.each { |id, det| STDERR.puts "enforce-file file=#{file} rule=#{id} severity=#{sev[id]} detector=#{det} verdict=fail" }
    warn_fails.each  { |id, det| STDERR.puts "enforce-file file=#{file} rule=#{id} severity=#{sev[id]} detector=#{det} verdict=warn" }
    unenf.each       { |id, det| STDERR.puts "enforce-file file=#{file} rule=#{id} detector=#{det} verdict=not_enforced" }
    status = block_fails.any? ? "red" : (unenf.any? ? "incomplete" : (warn_fails.any? ? "advisory" : "green"))
    prof = profile.empty? ? "" : " profile=#{File.basename(profile)} disabled=#{disabled.size}"
    STDERR.puts "enforce-file file=#{file} status=#{status} rules_checked=#{applicable.size} blocking=#{block_fails.size} warn=#{warn_fails.size} not_enforced=#{unenf.size}#{prof}"
  end
  # exit 1 only on a BLOCKING (P0/P1) violation; advisory P2/P3 warnings never block a write.
  exit(block_fails.any? ? 1 : (unenf.any? ? 3 : 0))
'
