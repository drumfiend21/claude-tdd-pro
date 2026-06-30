#!/usr/bin/env bash
# commands/config-sync.sh — ADR-0009 stage 6 (§28.58): materialize the single-config OPTIONS DATA.
#
# The intake step that runs whenever source URLs change and new rule content is scraped (triggered by
# standards-monitor.sh S-10 on a source delta). For each rule it reads enforced_by[] and, for every
# 3rd-party tool the rule is mapped to, SEEDS an options object from standards/tool-option-surfaces.yaml
# (the tool's documented option vocabulary / examples), producing a per-rule config object
#   <rule-id>: { severity: <native>, options: { <tool>: { ...tool-native options... } } }
# so the single config (ctp.config.yaml) carries real, projectable options data for EVERY rule — never
# "capability present, data empty". cite-or-decline: a 3rd-party tool with NO projectable option surface
# is recorded `needs_mapping` and surfaced (never silently omitted).
#
# CLI:
#   --rule-id <id> --enforced-by <csv>   materialize ONE rule -> config object on stdout
#   --all                                materialize EVERY catalog rule -> single-config rules: map
#   --check                              exit 1 if any active rule lacks options for an option-bearing tool
#   [--json]
# stderr: per rule `config-sync rule=<id> tools=<n> options=<n> needs_mapping=<n>`;
#         summary `config-sync rules=<n> materialized=<n> needs_mapping=<n>`
# Exit: 0 ok | 1 --check gap found | 2 usage.
set -uo pipefail
RID=""; EB=""; ALL=0; CHECK=0; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --rule-id)     RID="${2-}"; shift 2 ;;
    --enforced-by) EB="${2-}"; shift 2 ;;
    --all)         ALL=1; shift ;;
    --check)       CHECK=1; shift ;;
    --json)        JSON=1; shift ;;
    -h|--help) echo "Usage: config-sync.sh (--rule-id <id> --enforced-by <csv> | --all | --check) [--json]" >&2; exit 0 ;;
    *) echo "config-sync: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ "$ALL" -eq 0 ] && [ "$CHECK" -eq 0 ] && [ -z "$RID" ] && { echo "config-sync: --rule-id, --all or --check required" >&2; exit 2; }
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"

RID="$RID" EB="$EB" ALL="$ALL" CHECK="$CHECK" JSON="$JSON" PLUGIN_ROOT="$PLUGIN_ROOT" ruby -ryaml -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  plugin=ENV["PLUGIN_ROOT"]
  surf=(YAML.unsafe_load_file(File.join(plugin,"standards","tool-option-surfaces.yaml"))["tools"] rescue {}) || {}

  # For each rule: seed a per-tool options object from the documented tool vocabulary (examples).
  materialize = lambda do |rid, tools|
    obj={"severity"=>"error","options"=>{}}; nmap=[]; nopt=0
    tools.each do |t|
      next if t.to_s.empty?
      if t.end_with?(".sh")            # CTP-native detector -> no 3rd-party options to project
        next
      end
      s=surf[t]
      if s.nil?
        nmap<<t; next
      end
      r=s["render"]
      if !(r.is_a?(Hash) && r["supported"]!=false && (r["fmt"]||r["method"]))
        nmap<<t; next                  # 3rd-party tool with no projectable option surface
      end
      ex=s["examples"]
      obj["options"][t]= (ex.is_a?(Hash) ? ex : {})   # seed options data from the tool vocabulary
      nopt+=1
    end
    [obj, nopt, nmap]
  end

  emit_one = lambda do |rid, tools|
    obj,nopt,nmap = materialize.call(rid, tools)
    STDERR.puts "config-sync rule=#{rid} tools=#{tools.size} options=#{nopt} needs_mapping=#{nmap.size}"
    [obj,nopt,nmap]
  end

  if !ENV["RID"].empty? && ENV["ALL"]=="0" && ENV["CHECK"]=="0"
    tools=ENV["EB"].split(",").map{|t|t.strip}.reject(&:empty?)
    obj,nopt,nmap = emit_one.call(ENV["RID"], tools)
    print JSON.pretty_generate({ENV["RID"]=>obj}) if ENV["JSON"]=="1" || true
    exit 0
  end

  # --all / --check over the whole catalog
  rules={}
  Dir[File.join(plugin,"generated-code-quality-standards","*","*.yaml")].each do |f|
    d=(YAML.unsafe_load_file(f) rescue nil); next unless d.is_a?(Hash)
    (d["rules"]||[]).each do |r|
      next unless r.is_a?(Hash) && r["id"]
      tools=Array(r["enforced_by"]).map{|b|(b.is_a?(Hash)? b["tool"]:b).to_s}.reject(&:empty?)
      rules[r["id"]]=tools
    end
  end
  out={}; total=0; mat=0; needs=0
  rules.each do |rid,tools|
    obj,nopt,nmap = materialize.call(rid,tools)
    total+=1; mat+=1 if nopt>0 || tools.all?{|t|t.end_with?(".sh")}
    needs+=nmap.size
    out[rid]=obj
    STDERR.puts "config-sync rule=#{rid} tools=#{tools.size} options=#{nopt} needs_mapping=#{nmap.size}" if nmap.any?
  end
  STDERR.puts "config-sync rules=#{total} materialized=#{mat} needs_mapping=#{needs}"
  if ENV["CHECK"]=="1"
    exit(needs>0 ? 1 : 0)
  end
  print YAML.dump({"rules"=>out}) unless ENV["JSON"]=="1"
  print JSON.pretty_generate({"rules"=>out}) if ENV["JSON"]=="1"
'
