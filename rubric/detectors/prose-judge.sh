#!/usr/bin/env bash
# rubric/detectors/prose-judge.sh - semantic-projection detector: enforce ANY rule
# against architectural Markdown PROSE, not only its code-shape (ADR-0007 / §28.24,
# the prose-as-code principle). Generalizes the LLM_JUDGE=1 shell-out pattern from
# no-any.sh / naked-throw.sh into a first-class detector: take a rule body + a prose
# section, return YES (violates) / NO (compatible) / ABSTAIN.
#
# Three tiers (cheapest first):
#   1. keyword tier (deterministic): if the rule forbids a literal token (from the
#      cloud/universal detector manifests) and the prose contains it -> YES. Catches an
#      ADR that says "leave ingress unrestricted (0.0.0.0/0)".
#   2. LLM tier (LLM_JUDGE=1 + rubric/detectors/llm-judge.sh + a model CLI): semantic
#      YES/NO/ABSTAIN on paraphrased intent.
#   3. fallback: a section mentioning the rule's keywords but unjudgeable -> not_enforced
#      (RED, never a silent green). Otherwise compatible.
# Cache by sha256(rule_body)+sha256(section) in .claude-tdd-pro/cache/prose-judge/.
# Output: SARIF 2.1.0 (--json). Exit: 0 green | 1 red (>=1 YES) | 3 incomplete
# (not_enforced, no YES) | 2 usage.
#
# CLI: --rule <id> [--paths <glob>] [--root <dir>] [--json] [--llm-judge]

set -uo pipefail
RULE=""; PATHS=""; ROOT="."; JSON=0; LLMJ="${LLM_JUDGE:-0}"
while [ $# -gt 0 ]; do
  case "$1" in
    --rule)      RULE="${2-}";  shift 2 ;;
    --paths)     PATHS="${2-}"; shift 2 ;;
    --root)      ROOT="${2-}";  shift 2 ;;
    --json)      JSON=1; shift ;;
    --llm-judge) LLMJ=1; shift ;;
    -h|--help) echo "Usage: prose-judge.sh --rule <id> [--paths <glob>] [--root <dir>] [--json] [--llm-judge]" >&2; exit 0 ;;
    *) echo "prose-judge: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$RULE" ] && { echo "prose-judge: --rule <id> required" >&2; exit 2; }

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

RULE="$RULE" PATHS="$PATHS" ROOT="$ROOT" JSON="$JSON" LLMJ="$LLMJ" PLUGIN_ROOT="$PLUGIN_ROOT" ruby -ryaml -rjson -rdigest -e '
  Encoding.default_external = Encoding::UTF_8
  rule=ENV["RULE"]; root=ENV["ROOT"]; plugin=ENV["PLUGIN_ROOT"]; want_json=ENV["JSON"]=="1"; llmj=ENV["LLMJ"]=="1"

  # --- resolve the rule: body (description) + forbidden literal tokens ----------------
  body=nil; forbid_tokens=[]
  Dir[File.join(plugin,"generated-code-quality-standards","*","*.yaml")].each do |f|
    d=(YAML.unsafe_load_file(f) rescue nil); next unless d.is_a?(Hash)
    (d["rules"]||[]).each { |r| body=r["description"].to_s if r.is_a?(Hash) && r["id"]==rule }
  end
  %w[cloud-guidance-rules.json universal-pattern-rules.json].each do |mfn|
    mp=File.join(plugin,"rubric","detectors",mfn); next unless File.exist?(mp)
    s=(JSON.parse(File.read(mp))["rules"]||{})[rule]
    next unless s
    if s["mode"]=="forbid"
      forbid_tokens.concat(Array(s["token"])) if s["token"]
      forbid_tokens.concat(Array(s["patterns"])) if s["patterns"]
    end
    body ||= s["message"].to_s
  end
  if body.nil?
    STDERR.puts "prose-judge: unknown rule #{rule}"; exit 2
  end
  # literal tokens only (skip regex metachar patterns) for the deterministic keyword tier
  literals = forbid_tokens.reject { |t| t =~ /[\\(\[{|+*?^$]/ }

  globs = ENV["PATHS"].to_s.empty? ? [File.join(root,"**","*.md")] : ENV["PATHS"].split(",")
  files = globs.flat_map { |g| Dir.glob(g) }.uniq.select { |f| File.file?(f) }

  cache_dir = File.join(root, ".claude-tdd-pro", "cache", "prose-judge")
  (FileUtils.mkdir_p(cache_dir) rescue (require "fileutils"; FileUtils.mkdir_p(cache_dir))) unless Dir.exist?(cache_dir)
  rule_sha = Digest::SHA256.hexdigest(body + "|" + literals.sort.join(","))

  results = []   # {file, line, verdict, rationale}
  files.each do |f|
    lines = (File.read(f).lines rescue [])
    # split into heading-anchored sections
    sections=[]; cur={line:1, text:""}
    lines.each_with_index do |ln, i|
      if ln =~ /\A\#{1,6}\s+\S/
        sections << cur unless cur[:text].strip.empty?
        cur={line:i+1, text:ln}
      else
        cur[:text] << ln
      end
    end
    sections << cur unless cur[:text].strip.empty?

    sections.each do |sec|
      prose = sec[:text]
      sec_sha = Digest::SHA256.hexdigest(prose)
      cache_f = File.join(cache_dir, "#{rule_sha}-#{sec_sha}.verdict")
      verdict=nil; rationale=""
      if File.exist?(cache_f)
        v=(File.read(cache_f) rescue "").split("\t",2); verdict=v[0]; rationale=(v[1]||"").strip
      else
        # tier 1: deterministic keyword
        hit = literals.find { |t| !t.empty? && prose.downcase.include?(t.downcase) }
        if hit
          verdict="violates"; rationale="prose proposes the forbidden \"#{hit}\""
        elsif llmj && File.exist?(File.join(plugin,"rubric","detectors","llm-judge.sh"))
          # tier 2: semantic LLM judge (best-effort; non-fatal)
          out=`LLM_JUDGE=1 bash #{File.join(plugin,"rubric","detectors","llm-judge.sh")} --rule #{rule} --text #{prose.inspect} 2>/dev/null`
          case out
          when /\bYES\b/i then verdict="violates"; rationale=out.strip[0,160]
          when /\bNO\b/i  then verdict="compatible"
          when /\bABSTAIN\b/i then verdict="abstain"
          else verdict="not_enforced"
          end
        else
          # tier 3: fallback — keyword-ish mention but unjudgeable -> not_enforced
          kw = body.downcase.split(/\W+/).select { |w| w.length>5 }.first(6)
          verdict = (kw.any? { |w| prose.downcase.include?(w) } ? "not_enforced" : "compatible")
        end
        File.write(cache_f, "#{verdict}\t#{rationale}")
      end
      results << { "file"=>f, "line"=>sec[:line], "verdict"=>verdict, "rationale"=>rationale } if %w[violates not_enforced abstain].include?(verdict)
    end
  end

  viol = results.count { |r| r["verdict"]=="violates" }
  unenf = results.count { |r| r["verdict"]=="not_enforced" }

  if want_json
    sarif = { "version"=>"2.1.0",
      "$schema"=>"https://docs.oasis-open.org/sarif/sarif/v2.1.0/errata01/os/schemas/sarif-schema-2.1.0.json",
      "runs"=>[ { "tool"=>{"driver"=>{"name"=>"prose-judge","version"=>"1.0.0","rules"=>[{"id"=>rule}]}},
        "results"=> results.select{|r| r["verdict"]=="violates"}.map { |r|
          { "ruleId"=>rule, "level"=>"error",
            "message"=>{"text"=> (r["rationale"].empty? ? "prose proposes a design that violates #{rule}" : r["rationale"])},
            "locations"=>[{"physicalLocation"=>{"artifactLocation"=>{"uri"=>r["file"]},"region"=>{"startLine"=>r["line"]}}}] } } } ] }
    puts JSON.generate(sarif)
  end
  results.each { |r| STDERR.puts "prose-judge rule=#{rule} file=#{r["file"]} line=#{r["line"]} verdict=#{r["verdict"]}" }
  status = viol.positive? ? "red" : (unenf.positive? ? "incomplete" : "green")
  STDERR.puts "prose-judge rule=#{rule} status=#{status} violations=#{viol} not_enforced=#{unenf}"
  exit(viol.positive? ? 1 : (unenf.positive? ? 3 : 0))
'
