#!/usr/bin/env bash
# commands/frontier-eval.sh - H-16 frontier-model pre-release governance readiness checklist
# (v1.18 EO amendment §28.1; contract §2.32).
#
# Emits an operator-readable readiness SCAFFOLD for an org choosing to engage the EO Sec. 3
# voluntary framework: a cyber-capability self-assessment checklist plus the four EO-named
# pre-release control families -- confidentiality, cybersecurity, insider_risk, ip_protection --
# each slot grounded (cite-or-decline) in NIST AI RMF (S-54). It is a GOVERNANCE CHECKLIST, NOT a
# model evaluator: it emits no determination, sets no threshold, and records the EO Sec. 1
# no-mandatory-licensing disclaimer in its header. A control with no grounding source is marked
# needs_grounding (mirrors the S-8/S-26 decline contract). Covers the up-to-30-day pre-release window.
#
# CLI: --emit md|json [--window-days <n>] [--control <name>]
# stderr: per family `frontier-eval control=<name> grounded=<cite|needs_grounding>`;
#         summary `frontier-eval families=4 window_days=<n> voluntary=true status=<ready|needs_grounding>`
# Exit: 0 ok | 2 usage/unknown-control.
set -uo pipefail
EMIT="md"; WINDOW=30; CONTROL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --emit) EMIT="${2-}"; shift 2 ;;
    --window-days) WINDOW="${2-}"; shift 2 ;;
    --control) CONTROL="${2-}"; shift 2 ;;
    -h|--help) echo "Usage: frontier-eval.sh --emit md|json [--window-days <n>] [--control <name>]" >&2; exit 0 ;;
    *) echo "frontier-eval: unknown arg: $1" >&2; exit 2 ;;
  esac
done
case "$EMIT" in md|json) : ;; *) echo "frontier-eval: unknown emit format: $EMIT" >&2; exit 2 ;; esac

# the four EO Sec. 3 control families, each grounded in NIST AI RMF (S-54). A control absent from the
# grounding map is needs_grounding (cite-or-decline). An unknown --control is a usage error.
EMIT="$EMIT" WINDOW="$WINDOW" CONTROL="$CONTROL" node -e '
  const families=[
    {name:"confidentiality", cite:"nist-ai-rmf:GOVERN-1", desc:"Protect model weights + training data confidentiality during pre-release access."},
    {name:"cybersecurity",   cite:"nist-ai-rmf:MANAGE-2", desc:"Harden the pre-release environment against extraction + intrusion."},
    {name:"insider_risk",    cite:"nist-ai-rmf:GOVERN-2", desc:"Limit + log insider access to frontier model artifacts."},
    {name:"ip_protection",   cite:"nist-ai-rmf:MAP-1",    desc:"Protect American ingenuity / IP per the EO during the window."},
  ];
  const known=new Set(families.map(f=>f.name));
  if(process.env.CONTROL && !known.has(process.env.CONTROL)){ process.stderr.write(`frontier-eval: unknown control: ${process.env.CONTROL}\n`); process.exit(2); }
  const sel = process.env.CONTROL ? families.filter(f=>f.name===process.env.CONTROL) : families;
  let needs=0;
  const slots=sel.map(f=>{ const grounded = !!f.cite; if(!grounded)needs++;
    process.stderr.write(`frontier-eval control=${f.name} grounded=${grounded?f.cite:"needs_grounding"}\n`);
    return {control:f.name, grounded, source:grounded?f.cite:null, status:grounded?"ok":"needs_grounding", description:f.desc}; });
  const disclaimer="EO Sec. 1: voluntary -- no mandatory licensing or compliance determination. Advisory governance checklist only.";
  const window=parseInt(process.env.WINDOW,10)||30;
  const self_assessment=["cyber-capability self-assessment","extraction-resistance review","misuse red-team (W-13)","pre-release access log"];
  const status = needs>0 ? "needs_grounding" : "ready";
  process.stderr.write(`frontier-eval families=${sel.length} window_days=${window} voluntary=true status=${status}\n`);
  if(process.env.EMIT==="json"){
    process.stdout.write(JSON.stringify({voluntary:true, disclaimer, window_days:window, self_assessment, controls:slots}));
  } else {
    let md=`# Frontier-model pre-release readiness checklist (voluntary)\n\n> ${disclaimer}\n\nPre-release access window: up to ${window} days.\n\n## Cyber-capability self-assessment\n`;
    for(const s of self_assessment) md+=`- [ ] ${s}\n`;
    md+=`\n## EO Sec. 3 control families\n`;
    for(const s of slots) md+=`- [ ] **${s.control}** (${s.status}${s.source?", "+s.source:""}) -- ${s.description}\n`;
    process.stdout.write(md);
  }
'
