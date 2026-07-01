#!/usr/bin/env bash
# rubric/group-findings-by-rule.sh — per-rule enforcement-output grouping (the single-config-surface
# Layer-1 reporting substrate; composes the §28.29 SARIF bus). Captures every enforcement finding
# emitted by any tool OR CTP native detector, PRESERVES each tool's own reporting id, and GROUPS the
# findings under the rule they belong to so output "bubbles up" per rule:
#
#   * a CTP native finding (ruleId like g-*) groups under that CTP rule id directly;
#   * a tool finding (driver=checkov, ruleId=CKV_K8S_16) is namespaced <tool>/<reporting-id> and is
#     its own first-class rule key (ESLint-plugin style), UNLESS an --alias map ties that reporting
#     id to a CTP rule, in which case it rolls up under the CTP rule.
#
# This is what makes the single config surface effective on the routed path WITHOUT a hand-built
# correlation table: the SARIF ruleId IS the config key; the 4-axis registry already did the routing.
#
# CLI:
#   --dir <dir>        ingest every *.sarif / *.sarif.json under <dir>
#   --in <file>        ingest one SARIF document (repeatable)
#   --alias <map.json> optional { "<tool>/<id>"|"<id>": "<ctp-rule-id>" } to roll tool checks up to a CTP rule
#   --json             emit the grouped report to stdout
# stdout (--json): {"rules":{"<rule-key>":{"ctp_rule","tools":[],"reporting_ids":[],"count","level","messages":[]}}}
# stderr: per rule `group rule=<key> tools=<csv> count=<n> level=<lvl>`; summary `group-by-rule rules=<r> findings=<f>`
# Exit: 0 ok | 2 usage.
set -uo pipefail

DIR=""; ALIAS=""; JSON=0; INS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dir)   DIR="${2-}"; shift 2 ;;
    --in)    INS+=("${2-}"); shift 2 ;;
    --alias) ALIAS="${2-}"; shift 2 ;;
    --json)  JSON=1; shift ;;
    -h|--help) echo "Usage: group-findings-by-rule.sh (--dir <dir> | --in <file>...) [--alias <map.json>] [--json]" >&2; exit 0 ;;
    *) echo "group-findings-by-rule: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$DIR" ] && [ "${#INS[@]}" -eq 0 ] && { echo "group-findings-by-rule: --dir or --in required" >&2; exit 2; }

# collect SARIF file list (newline-delimited) for node
FILELIST=""
if [ -n "$DIR" ]; then
  [ -d "$DIR" ] || { echo "group-findings-by-rule: not a directory: $DIR" >&2; exit 2; }
  FILELIST="$(find "$DIR" -type f \( -name '*.sarif' -o -name '*.sarif.json' \) 2>/dev/null)"
fi
for f in "${INS[@]:-}"; do [ -n "$f" ] && FILELIST="$FILELIST
$f"; done

OUT="$(FILELIST="$FILELIST" ALIAS="$ALIAS" JSON="$JSON" node -e '
  const fs=require("fs");
  const files=(process.env.FILELIST||"").split("\n").map(s=>s.trim()).filter(Boolean);
  let alias={};
  if(process.env.ALIAS){ try{ alias=JSON.parse(fs.readFileSync(process.env.ALIAS,"utf8")); }catch(e){ alias={}; } }
  const sev={error:3,warning:2,note:1,none:0};
  const groups={}; let findings=0;
  for(const f of files){
    let doc; try{ doc=JSON.parse(fs.readFileSync(f,"utf8")); }catch(e){ continue; }
    for(const run of (doc.runs||[])){
      const driver=(run.tool&&run.tool.driver&&run.tool.driver.name)||"";
      for(const r of (run.results||[])){
        findings++;
        const rid=(r.ruleId!=null?String(r.ruleId):"(none)");
        // namespaced reporting id: CTP-native ids (g-*) keep their id; tool ids are <driver>/<id>
        const isCtp=/^g-/.test(rid);
        const nsId=isCtp?rid:(driver?driver+"/"+rid:rid);
        // the rule this finding bubbles up to: alias target > namespaced id (or CTP id)
        const ctpRule=alias[nsId]||alias[rid]||nsId;
        const g=groups[ctpRule]||(groups[ctpRule]={ctp_rule:ctpRule,tools:new Set(),reporting_ids:new Set(),count:0,_lvl:0,messages:[]});
        if(driver)g.tools.add(driver);
        g.reporting_ids.add(nsId);
        g.count++;
        const lv=String((r.level!=null?r.level:"warning"));
        if((sev[lv]||0)>g._lvl)g._lvl=sev[lv]||0;
        const msg=(r.message&&r.message.text)?String(r.message.text):"";
        if(msg&&g.messages.length<5)g.messages.push(msg.slice(0,200));
      }
    }
  }
  const lvName=["none","note","warning","error"];
  const rules={};
  const keys=Object.keys(groups).sort();
  for(const k of keys){const g=groups[k];rules[k]={ctp_rule:g.ctp_rule,tools:[...g.tools].sort(),reporting_ids:[...g.reporting_ids].sort(),count:g.count,level:lvName[g._lvl],messages:g.messages};}
  // stderr lines
  for(const k of keys){const g=rules[k];process.stderr.write(`group rule=${k} tools=${g.tools.join(",")||"-"} count=${g.count} level=${g.level}\n`);}
  process.stderr.write(`group-by-rule rules=${keys.length} findings=${findings}\n`);
  if(process.env.JSON==="1")process.stdout.write(JSON.stringify({rules}));
' 2>/tmp/_gfbr.$$)"
ec=$?
cat /tmp/_gfbr.$$ >&2; rm -f /tmp/_gfbr.$$
[ "$JSON" -eq 1 ] && printf '%s' "$OUT"
exit 0
