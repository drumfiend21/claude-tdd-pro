#!/usr/bin/env bash
# commands/classify-path.sh — §28.63 development-PATH tagging. When a rule is tagged with the four-axis
# canonical kind (classify-rule.sh), it is ALSO tagged with the development path(s) it governs — `iac`
# (the IaC/cloud build flow), `fullstack` (the application-code build flow), or BOTH. Derived
# deterministically from the four-axis `applies_to` + the rule id; every rule resolves to >=1 path, and a
# cross-cutting rule (universal/secret/dependency/prose/ambiguous-config) is tagged `both` so it enforces
# on EVERY artifact CTP generates across both build flows.
#
# Derivation:
#   iac        <- iac_dialects OR k8s_gvks present, OR an IaC language (hcl) in linguist_aliases
#   fullstack  <- an application language (typescript/javascript/tsx/jsx/python/go/java/groovy/...) in linguist_aliases
#   both       <- applies_to_prose (design governs both); a universal/secret/license/dependency/supply-chain
#                 rule (cross-cutting); ambiguous config/markup (yaml/json/markdown) with no specific path;
#                 or an unknown rule with no axis (safe default: enforced on everything)
#   namespace fallback (untagged rule): g-node-/g-react-/g-ts-/g-js- -> fullstack;
#                 g-aws-/g-gcp-/g-azure-/g-k8s-/g-hashicorp-/g-cfn- -> iac
#
# CLI:
#   --rule-id <id> --applies-to <json> [--prose]   classify ONE rule -> development_paths on stdout
#   --audit [--json]                                classify EVERY corpus rule; exit 1 if any unpathed
# stderr (audit): per cross-flow rule none; summary
#                 `classify-path total=<n> iac=<n> fullstack=<n> both=<n> unpathed=<n>`
# Exit: 0 ok | 1 audit found an unpathed rule | 2 usage.
set -uo pipefail
RID=""; AT=""; PROSE=0; AUDIT=0; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --rule-id)    RID="${2-}"; shift 2 ;;
    --applies-to) AT="${2-}"; shift 2 ;;
    --prose)      PROSE=1; shift ;;
    --audit)      AUDIT=1; shift ;;
    --json)       JSON=1; shift ;;
    -h|--help) echo "Usage: classify-path.sh (--rule-id <id> --applies-to <json> [--prose] | --audit) [--json]" >&2; exit 0 ;;
    *) echo "classify-path: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ "$AUDIT" -eq 0 ] && [ -z "$RID" ] && { echo "classify-path: --rule-id or --audit required" >&2; exit 2; }
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"

RID="$RID" AT="$AT" PROSE="$PROSE" AUDIT="$AUDIT" JSON="$JSON" PLUGIN_ROOT="$PLUGIN_ROOT" node -e '
  const fs=require("fs"), path=require("path");
  const IAC_LANGS=new Set(["hcl"]);
  const APP_LANGS=new Set(["typescript","javascript","tsx","jsx","groovy","python","go","java","ruby","rust","php","csharp","swift","kotlin","c","cpp","scala","elixir"]);
  const AMBIG=new Set(["yaml","json","markdown","toml","ini"]);
  const XCUT=/universal|secret|license|dependenc|supply-chain|provenance/;
  function classify(id, at, prose){
    at = at || {};
    const ling = at.linguist_aliases||[], iac=at.iac_dialects||[], k8s=at.k8s_gvks||[];
    const p=new Set();
    if(iac.length || k8s.length) p.add("iac");
    if(ling.some(l=>IAC_LANGS.has(l))) p.add("iac");
    if(ling.some(l=>APP_LANGS.has(l))) p.add("fullstack");
    if(prose){ p.add("iac"); p.add("fullstack"); }                 // design/arch governs both
    if(XCUT.test(id)){ p.add("iac"); p.add("fullstack"); }          // cross-cutting -> both
    if(p.size===0 && ling.some(l=>AMBIG.has(l))){ p.add("iac"); p.add("fullstack"); } // shared config/markup
    if(p.size===0){                                                // namespace fallback (untagged)
      if(/-node-|-react-|-ts-|-js-|-vue-|-angular-/.test(id)) p.add("fullstack");
      else if(/-aws-|-gcp-|-azure-|-k8s-|-hashicorp-|-cfn-|-terraform-/.test(id)) p.add("iac");
      else { p.add("iac"); p.add("fullstack"); }                   // unknown -> both (enforced on everything)
    }
    return [...p].sort();
  }
  const plugin=process.env.PLUGIN_ROOT;
  if(process.env.AUDIT!=="1"){
    let at={}; try{ at=JSON.parse(process.env.AT||"{}"); }catch(e){}
    const paths=classify(process.env.RID, at, process.env.PROSE==="1");
    process.stderr.write(`classify-path rule=${process.env.RID} development_paths=${paths.join(",")}\n`);
    if(process.env.JSON==="1") process.stdout.write(JSON.stringify({rule:process.env.RID, development_paths:paths}));
    process.exit(0);
  }
  // audit the whole corpus
  let yaml; try{ yaml=require(path.join(plugin,"node_modules","js-yaml")); }catch(e){ yaml=null; }
  // parse YAML via ruby fallback if js-yaml absent
  const cp=require("child_process");
  const rules=JSON.parse(cp.execSync(`ruby -ryaml -rjson -e '\''res=[]; Dir[%q{${plugin}/generated-code-quality-standards/*/*.yaml}].each{|f| d=(YAML.unsafe_load_file(f) rescue nil); next unless d.is_a?(Hash); (d[%q{rules}]||[]).each{|r| next unless r[%q{id}]; res<<{id:r[%q{id}], applies_to:r[%q{applies_to}], prose:r[%q{applies_to_prose}]==true} } }; print JSON.generate(res)'\''`,{maxBuffer:1<<26}).toString());
  let iac=0, fs2=0, both=0, unpathed=0; const out={};
  for(const r of rules){
    const at=(r.applies_to && typeof r.applies_to==="object")?r.applies_to:{};
    const p=classify(r.id, at, r.prose===true);
    out[r.id]=p;
    if(p.length===0){ unpathed++; continue; }
    if(p.includes("iac")&&p.includes("fullstack")) both++;
    else if(p.includes("iac")) iac++;
    else fs2++;
  }
  process.stderr.write(`classify-path total=${rules.length} iac=${iac} fullstack=${fs2} both=${both} unpathed=${unpathed}\n`);
  if(process.env.JSON==="1") process.stdout.write(JSON.stringify(out));
  process.exit(unpathed>0?1:0);
'
