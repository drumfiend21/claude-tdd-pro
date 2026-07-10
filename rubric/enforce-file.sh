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
# §28.57 universal native enforcer: a rule that applies to the file but has NO runnable deterministic
# detector -- a scraped rule whose only enforced_by is an (absent) 3rd-party tool, or a rule whose
# detector file cannot be found -- is enforced by the universal semantic detector (prose-judge.sh)
# against the file content instead of being silently skipped. So the native enforcer is capable of
# enforcing ANY software-engineering / software-architecture rule when a 3rd-party tool cannot be
# found; no applicable rule is ever left unenforced (an unjudgeable rule surfaces as not_enforced).
#
# CLI:  --file <path> [--root <dir>] [--profile <profile.yaml>] [--extra-rules <yaml>] [--quiet]
#   --extra-rules <yaml>  merge additional ad-hoc rules ({rules:[{id,description,severity,applies,mode,
#                         token[,detector]}]}) into the catalog (operator/test affordance; detector-less
#                         rules exercise the §28.57 universal native enforcer).
# stderr: per finding `enforce-file file=<f> rule=<id> verdict=<fail|not_enforced>`;
#         summary `enforce-file file=<f> status=<green|red|incomplete> fail=<n> not_enforced=<n>`
# Exit: 0 clean / 1 >=1 fail / 3 no fail but >=1 not_enforced / 2 usage.

set -uo pipefail
FILE=""; ROOT=""; QUIET=0; PROFILE=""; EXTRA=""; APPCODE=0; SINGLEFILE=0; PROJECT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --file)             FILE="${2-}"; shift 2 ;;
    --root)             ROOT="${2-}"; shift 2 ;;
    --profile)          PROFILE="${2-}"; shift 2 ;;
    --extra-rules)      EXTRA="${2-}"; shift 2 ;;
    --project)          PROJECT="${2-}"; shift 2 ;;
    --include-app-code) APPCODE=1; shift ;;
    --single-file-gate) SINGLEFILE=1; shift ;;
    --quiet)            QUIET=1; shift ;;
    -h|--help) echo "Usage: enforce-file.sh --file <path> [--root <dir>] [--profile <profile.yaml>] [--extra-rules <yaml>] [--quiet]" >&2; exit 0 ;;
    *) echo "enforce-file: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$FILE" ] && { echo "enforce-file: --file <path> required" >&2; exit 2; }
[ ! -f "$FILE" ] && { echo "enforce-file: not a file: $FILE" >&2; exit 2; }

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

# Auto-discover the single config surface (ctp.config.yaml, a §2.5 profile) when no --profile was
# given — ESLint-style: walk up from the file's directory to a repo (.git) boundary. Default-
# preserving: if none is found, PROFILE stays empty and enforcement is byte-identical to before.
if [ -z "$PROFILE" ]; then
  _d="$(cd "$(dirname "$FILE")" 2>/dev/null && pwd -P)"; _lim=0
  while [ -n "$_d" ] && [ "$_lim" -lt 30 ]; do
    if [ -f "$_d/ctp.config.yaml" ]; then PROFILE="$_d/ctp.config.yaml"; break; fi
    [ -d "$_d/.git" ] && break
    [ "$_d" = "/" ] && break
    _d="$(dirname "$_d")"; _lim=$((_lim + 1))
  done
fi

FILE="$FILE" ROOT="$ROOT" QUIET="$QUIET" PROFILE="$PROFILE" EXTRA="$EXTRA" APPCODE="$APPCODE" SINGLEFILE="$SINGLEFILE" PLUGIN_ROOT="$PLUGIN_ROOT" ENF_PROJECT="$PROJECT" ruby -ryaml -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  file = ENV["FILE"]; plugin = ENV["PLUGIN_ROOT"]; quiet = ENV["QUIET"] == "1"
  profile = ENV["PROFILE"].to_s
  appcode = ENV["APPCODE"] == "1"
  singlefile = ENV["SINGLEFILE"] == "1"
  # §28.68: detectors needing the whole tree (sibling test files etc.) are not decidable on a single
  # proposed file in an isolated scratch — skipped at the per-file write/pre-write gate (audit-time keeps them).
  TREE_LEVEL = ["type-test-coverage.sh"]
  base = File.basename(file)
  # §28.68 language-agnostic application-code glob: derive a file glob from a rule mapping
  # linguist_aliases (any language) to its extension(s). Enables enforce-file to natively enforce the
  # full-stack app-code rule set (g-ts/g-react/g-node/g-python/g-go/...) when --include-app-code is set.
  LING2EXT = {
    "typescript"=>"*.ts","tsx"=>"*.tsx","javascript"=>"*.js","jsx"=>"*.jsx","python"=>"*.py","go"=>"*.go",
    "java"=>"*.java","ruby"=>"*.rb","rust"=>"*.rs","php"=>"*.php","csharp"=>"*.cs","c#"=>"*.cs",
    "kotlin"=>"*.kt","swift"=>"*.swift","scala"=>"*.scala","groovy"=>"*.groovy","elixir"=>"*.ex","c"=>"*.c","cpp"=>"*.cpp",
    "vue"=>"*.vue","svelte"=>"*.svelte"
  }
  aliases_to_glob = lambda { |als| Array(als).map { |a| LING2EXT[a.to_s] }.compact.uniq.join(",") }

  # --- catalog: id -> detector, severity, prose-bound set; plus the detector-LESS (universal) set ----
  # A rule with a runnable deterministic detector goes in `catalog`. A rule WITHOUT one (e.g. enforced
  # only by a 3rd-party tool) goes in `universal` -> §28.57 universal native enforcer (prose-judge).
  catalog = {}; prose = {}; sev = {}; mode = {}; desc = {}; tok = {}; universal = {}; lings = {}
  load_rule = lambda do |r|
    return unless r.is_a?(Hash) && r["id"]
    id = r["id"]
    desc[id] = r["description"].to_s if r["description"] && !r["description"].to_s.empty?
    sev[id]  = r["severity"].to_s if r["severity"]
    mode[id] = r["mode"].to_s if r["mode"]
    prose[id] = true if r["applies_to_prose"] == true
    at = r["applies_to"]
    lings[id] = at["linguist_aliases"] if at.is_a?(Hash) && at["linguist_aliases"].is_a?(Array)
    if r["detector"] && !r["detector"].to_s.empty?
      catalog[id] = r["detector"]
    else
      universal[id] = (r["applies"] || r["applies_glob"]).to_s   # scope glob (may be empty)
      t = Array(r["token"] || r["forbid"]).reject { |x| x.to_s.empty? }
      tok[id] = t.join(",") unless t.empty?
    end
  end
  Dir[File.join(plugin, "generated-code-quality-standards", "*", "*.yaml")].each do |f|
    d = (YAML.unsafe_load_file(f) rescue nil); next unless d.is_a?(Hash)
    (d["rules"] || []).each { |r| load_rule.call(r) }
  end
  # §31 S-62: first-class enforcement of the per-project WORKING overlay, scoped to --project <id>.
  # Loads ONLY _project/<id>/, never another project (blast-radius scoping, §31.4 B4). Without --project,
  # no project rules are loaded (official enforcement is unchanged).
  proj = ENV["ENF_PROJECT"].to_s.strip
  unless proj.empty?
    Dir[File.join(plugin, "generated-code-quality-standards", "_project", proj, "*", "*.yaml")].each do |f|
      d = (YAML.unsafe_load_file(f) rescue nil); next unless d.is_a?(Hash)
      (d["rules"] || []).each { |r| load_rule.call(r) }
    end
  end
  # operator/test affordance: extra ad-hoc rules (including detector-less / tool-only rules).
  unless ENV["EXTRA"].to_s.empty?
    ex = (YAML.unsafe_load_file(ENV["EXTRA"]) rescue nil)
    rules = ex.is_a?(Hash) ? (ex["rules"] || []) : (ex.is_a?(Array) ? ex : [])
    rules.each { |r| load_rule.call(r) }
  end

  # --- applies-globs + severity + mode from the cloud + config manifests ---------------
  applies = {}
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
    # §28.68: when --include-app-code is set, a full-stack rule with no manifest glob derives its glob
    # from its linguist_aliases (any language), so app code (.ts/.py/.go/...) is enforced natively.
    g = aliases_to_glob.call(lings[id]) if (g.nil? || g.to_s.empty?) && appcode && lings[id]
    next if g.nil? || g.empty?
    next if singlefile && TREE_LEVEL.include?(det.to_s)   # tree-context rule -> not decidable per-file
    applicable << [id, det] if matches?(file, base, g)
  end

  pj = File.join(plugin, "rubric", "detectors", "prose-judge.sh")
  # §28.57 universal native enforcer: project an (inline) rule body onto the file via prose-judge.
  # exit 1 = violates (fail), 3 = not_enforced (honest floor), 0 = compatible, other = no body -> floor.
  run_universal = lambda do |id|
    return 3 unless File.exist?(pj)
    b = desc[id].to_s
    return 3 if b.strip.empty?            # no rule body to project -> not_enforced, never a silent skip
    args = ["bash", pj, "--rule", id, "--body", b, "--paths", file]
    args += ["--forbid", tok[id]] if tok[id] && !tok[id].to_s.empty?
    system(*args, out: File::NULL, err: File::NULL)
    $?.exitstatus
  end

  fails = []; unenf = []
  applicable.each do |id, det|
    detp = File.join(plugin, "rubric", "detectors", det)
    if File.exist?(detp)
      system("bash", detp, "--rule", id, "--paths", file, out: File::NULL, err: File::NULL)
      ec = $?.exitstatus
    else
      # the rule detector cannot be found -> universal native enforcer (§28.57), never a silent skip
      ec = run_universal.call(id); det = "prose-judge.sh"
    end
    fails << [id, det] if ec == 1
    unenf << [id, det] if ec == 3
  end

  # --- detector-LESS rules (e.g. enforced only by an absent 3rd-party tool) -> universal enforcer ----
  uni_applied = []
  universal.each do |id, g|
    next if disabled[id]
    glob = g.to_s.empty? ? glob_for(id, nil) : g
    next unless glob.nil? || glob.to_s.empty? || matches?(file, base, glob)   # no scope -> applies
    uni_applied << id
    ec = run_universal.call(id)
    fails << [id, "prose-judge.sh"] if ec == 1
    unenf << [id, "prose-judge.sh"] if ec == 3
  end

  # --- prose-as-code: architectural Markdown also runs the applies_to_prose rules -----
  if base.end_with?(".md")
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
    STDERR.puts "enforce-file file=#{file} status=#{status} rules_checked=#{applicable.size + uni_applied.size} blocking=#{block_fails.size} warn=#{warn_fails.size} not_enforced=#{unenf.size}#{prof}"
  end
  # exit 1 only on a BLOCKING (P0/P1) violation; advisory P2/P3 warnings never block a write.
  exit(block_fails.any? ? 1 : (unenf.any? ? 3 : 0))
'
