#!/usr/bin/env bash
# rubric/detectors/md-structure.sh - deterministic Markdown structural lint (ADR-0007
# §28.24, Wave 1). Rule-id-driven (like cloud-guidance-rule.sh) so enforce.sh dispatches
# it via --rule/--root. Closes the .md enforcement dead-zone for syntactic rules; no LLM.
# Grounds in CommonMark 0.31.2 + markdownlint MD0xx (provenance in the rule file).
#
# Rules:
#   g-md-fenced-code-language-declared  (MD040) - every ``` fence declares a language
#   g-md-single-h1                      (MD025) - exactly one top-level # H1
#
# CLI: --rule <id> --root <dir> [--paths <glob>] [--json]
# stderr: per finding `md-structure file=<f> rule=<id>`; summary `md-structure rule=<id> status=<green|red> findings=<n>`
# Exit: 0 clean | 1 findings | 2 usage.

set -uo pipefail
RULE=""; ROOT="."; PATHS=""; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --rule)  RULE="${2-}";  shift 2 ;;
    --root)  ROOT="${2-}";  shift 2 ;;
    --paths) PATHS="${2-}"; shift 2 ;;
    --json)  JSON=1; shift ;;
    -h|--help) echo "Usage: md-structure.sh --rule <id> --root <dir> [--paths <glob>] [--json]" >&2; exit 0 ;;
    *) echo "md-structure: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$RULE" ] && { echo "md-structure: --rule <id> required" >&2; exit 2; }

RULE="$RULE" ROOT="$ROOT" PATHS="$PATHS" JSON="$JSON" ruby -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  rule=ENV["RULE"]; root=ENV["ROOT"]; want_json=ENV["JSON"]=="1"
  unless %w[g-md-fenced-code-language-declared g-md-single-h1].include?(rule)
    STDERR.puts "md-structure: unknown rule #{rule}"; exit 2
  end
  globs = ENV["PATHS"].to_s.empty? ? [File.join(root,"**","*.md")] : ENV["PATHS"].split(",")
  files = globs.flat_map { |g| Dir.glob(g) }.uniq.select { |f| File.file?(f) }

  findings=[]
  files.each do |f|
    lines=(File.read(f).lines rescue [])
    case rule
    when "g-md-fenced-code-language-declared"
      infence=false
      lines.each_with_index do |ln,i|
        if ln =~ /\A```/
          if !infence
            lang = ln.strip.sub(/\A```/,"").strip
            findings << [f,i+1] if lang.empty?     # opening fence with no language
            infence=true
          else
            infence=false                          # closing fence
          end
        end
      end
    when "g-md-single-h1"
      h1 = lines.count { |ln| ln =~ /\A#\s+\S/ }
      findings << [f,1] if h1 != 1                  # must be exactly one H1
    end
  end

  if want_json
    sarif={ "version"=>"2.1.0",
      "$schema"=>"https://docs.oasis-open.org/sarif/sarif/v2.1.0/errata01/os/schemas/sarif-schema-2.1.0.json",
      "runs"=>[{"tool"=>{"driver"=>{"name"=>"md-structure","version"=>"1.0.0","rules"=>[{"id"=>rule}]}},
        "results"=>findings.map{|f,l| {"ruleId"=>rule,"level"=>"warning",
          "message"=>{"text"=>"#{rule} violation"},
          "locations"=>[{"physicalLocation"=>{"artifactLocation"=>{"uri"=>f},"region"=>{"startLine"=>l}}}]}}}]}
    puts JSON.generate(sarif)
  end
  findings.each { |f,l| STDERR.puts "md-structure file=#{f} line=#{l} rule=#{rule}" }
  STDERR.puts "md-structure rule=#{rule} status=#{findings.empty? ? "green":"red"} findings=#{findings.size}"
  exit(findings.empty? ? 0 : 1)
'
