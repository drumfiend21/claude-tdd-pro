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
# Persistence + cache (§28.59): `--persist [--out <file>]` writes the options-VIEW to disk; each rule
# object carries a content `_hash` over (rule id + enforced_by + the rule source content_hash + the
# tool option surfaces). On re-run an unchanged rule reuses its persisted object (cache hit); only a
# rule whose source or mapping changed is re-materialized; if nothing changed the file is byte-identical
# and NOT rewritten (cache-if-no-change, mirrors the S-21 conditional-GET discipline).
#
# CLI:
#   --rule-id <id> --enforced-by <csv>   materialize ONE rule -> config object on stdout
#   --all                                materialize EVERY catalog rule -> single-config rules: map
#   --persist [--out <file>]             persist the options-view (cached; default standards/config-options-view.yaml)
#   --check                              exit 1 if any active rule lacks options for an option-bearing tool
#   [--json]
# stderr: per rule `config-sync rule=<id> tools=<n> options=<n> needs_mapping=<n>`;
#         summary `config-sync rules=<n> materialized=<n> needs_mapping=<n>`;
#         persist `config-sync persisted=<file> total=<n> unchanged=<u> updated=<c> added=<a> removed=<r> wrote=<0|1>`
# Exit: 0 ok | 1 --check gap found | 2 usage.
set -uo pipefail
RID=""; EB=""; ALL=0; CHECK=0; JSON=0; PERSIST=0; OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --rule-id)     RID="${2-}"; shift 2 ;;
    --enforced-by) EB="${2-}"; shift 2 ;;
    --all)         ALL=1; shift ;;
    --check)       CHECK=1; shift ;;
    --persist)     PERSIST=1; shift ;;
    --out)         OUT="${2-}"; shift 2 ;;
    --json)        JSON=1; shift ;;
    -h|--help) echo "Usage: config-sync.sh (--rule-id <id> --enforced-by <csv> | --all | --persist [--out <file>] | --check) [--json]" >&2; exit 0 ;;
    *) echo "config-sync: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ "$ALL" -eq 0 ] && [ "$CHECK" -eq 0 ] && [ "$PERSIST" -eq 0 ] && [ -z "$RID" ] && { echo "config-sync: --rule-id, --all, --persist or --check required" >&2; exit 2; }
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"

RID="$RID" EB="$EB" ALL="$ALL" CHECK="$CHECK" JSON="$JSON" PERSIST="$PERSIST" OUT="$OUT" PLUGIN_ROOT="$PLUGIN_ROOT" ruby -ryaml -rjson -rdigest -e '
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

  # --all / --check / --persist over the whole catalog. Capture per-rule the enforced_by tools AND the
  # source content_hash (G-2 header) so the persisted view re-materializes only when a source changes.
  rules={}; chash={}
  Dir[File.join(plugin,"generated-code-quality-standards","*","*.yaml")].each do |f|
    d=(YAML.unsafe_load_file(f) rescue nil); next unless d.is_a?(Hash)
    src_hash=(d["source"].is_a?(Hash) ? d["source"]["content_hash"].to_s : "")
    (d["rules"]||[]).each do |r|
      next unless r.is_a?(Hash) && r["id"]
      tools=Array(r["enforced_by"]).map{|b|(b.is_a?(Hash)? b["tool"]:b).to_s}.reject(&:empty?)
      rules[r["id"]]=tools
      chash[r["id"]]=src_hash
    end
  end

  # §28.59 cache key: changes iff the rule mapping, its source content_hash, or a mapped tool surface changes.
  surf_sig = lambda do |tools|
    tools.sort.map { |t| s=surf[t]||{}; [t, s["render"], s["examples"]] }
  end
  rule_hash = lambda do |rid, tools|
    Digest::SHA256.hexdigest(JSON.generate([rid, tools.sort, chash[rid].to_s, surf_sig.call(tools)]))
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

  if ENV["PERSIST"]=="1"
    outfile = ENV["OUT"].empty? ? File.join(plugin,"standards","config-options-view.yaml") : ENV["OUT"]
    prev = (File.exist?(outfile) ? (YAML.unsafe_load_file(outfile) rescue nil) : nil)
    prev_rules = (prev.is_a?(Hash) ? (prev["rules"]||{}) : {})
    merged={}; unchanged=0; updated=0; added=0
    rules.each do |rid,tools|
      h = rule_hash.call(rid,tools)
      po = prev_rules[rid]
      if po.is_a?(Hash) && po["_hash"]==h
        merged[rid]=po; unchanged+=1                 # cache hit: source + mapping unchanged -> reuse
      else
        obj=out[rid].dup; obj["_hash"]=h; merged[rid]=obj
        prev_rules.key?(rid) ? updated+=1 : added+=1 # source/mapping changed -> re-materialize
      end
    end
    removed = (prev_rules.keys - rules.keys).size
    new_doc = {"rules"=>merged}
    new_yaml = YAML.dump(new_doc)
    old_yaml = (File.exist?(outfile) ? File.read(outfile) : nil)
    wrote=0
    if new_yaml != old_yaml
      require "fileutils"; FileUtils.mkdir_p(File.dirname(outfile))
      File.write(outfile, new_yaml); wrote=1                 # cache-if-no-change: write only on a delta
    end
    STDERR.puts "config-sync persisted=#{outfile} total=#{rules.size} unchanged=#{unchanged} updated=#{updated} added=#{added} removed=#{removed} wrote=#{wrote}"
    exit 0
  end

  print YAML.dump({"rules"=>out}) unless ENV["JSON"]=="1"
  print JSON.pretty_generate({"rules"=>out}) if ENV["JSON"]=="1"
'
