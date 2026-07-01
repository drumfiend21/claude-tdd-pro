#!/usr/bin/env bash
# commands/security-posture.sh - Q-13 security-remediation posture metric
# (v1.18 EO amendment §28.8; extends the §2.11 SPACE metric schema).
#
# Extends the SPACE metric schema with a LOCAL-ONLY (Q-6 privacy-by-default; no upload) security
# dimension that makes the EO Sec. 2 "find and fix" loop measurable:
#   - mttr_to_remediate           : mean time from an H-14 finding to its C-23 remediation_status=fixed
#   - vulnerability_density       : findings per 1k dependencies
#   - percent_deps_fix_applied    : share of findings whose known fix has been applied
#   - threat_model_coverage       : share of findings carrying a grounded source (§28.9 refinement)
#   - trend                       : delta vs a prior snapshot (§28.9 refinement)
# Derives entirely from H-14 + C-23 outputs; computes locally and never uploads.
#
# CLI: --findings <json> --deps <n> [--prior <json>] [--json]
# stderr: `security-posture density=<d> percent_fixed=<p> mttr_hours=<h> coverage=<c> local_only=true`
# Exit: 0 ok | 2 usage.
set -uo pipefail
FINDINGS=""; DEPS=""; PRIOR=""; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --findings) FINDINGS="${2-}"; shift 2 ;;
    --deps) DEPS="${2-}"; shift 2 ;;
    --prior) PRIOR="${2-}"; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help) echo "Usage: security-posture.sh --findings <json> --deps <n> [--prior <json>] [--json]" >&2; exit 0 ;;
    *) echo "security-posture: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$FINDINGS" ] && { echo "security-posture: --findings <json> required" >&2; exit 2; }
[ -f "$FINDINGS" ] || { echo "security-posture: not a file: $FINDINGS" >&2; exit 2; }
[ -z "$DEPS" ] && { echo "security-posture: --deps <n> required" >&2; exit 2; }

FINDINGS="$FINDINGS" DEPS="$DEPS" PRIOR="$PRIOR" JSON="$JSON" node -e '
  const fs=require("fs");
  let f; try{ f=JSON.parse(fs.readFileSync(process.env.FINDINGS,"utf8")); }catch(e){ process.stderr.write("security-posture: findings not valid json\n"); process.exit(2); }
  if(!Array.isArray(f)){ process.stderr.write("security-posture: findings must be an array\n"); process.exit(2); }
  const deps=Math.max(0,parseInt(process.env.DEPS,10)||0);
  const n=f.length;
  const density = deps>0 ? +(n/deps*1000).toFixed(2) : 0;
  const fixed = f.filter(x=>x.remediation_status==="fixed").length;
  const percent_fixed = n>0 ? +(fixed/n*100).toFixed(1) : 100;
  // mttr: mean (remediated_at - disclosed_at) over fixed findings that carry both timestamps.
  const durs=f.filter(x=>x.remediation_status==="fixed"&&x.disclosed_at&&x.remediated_at)
    .map(x=>(Date.parse(x.remediated_at)-Date.parse(x.disclosed_at))/3600000).filter(h=>h>=0);
  const mttr_hours = durs.length ? +(durs.reduce((a,b)=>a+b,0)/durs.length).toFixed(1) : null;
  const grounded = f.filter(x=>x.source||(x.grounded&&x.grounded.length)).length;
  const threat_model_coverage = n>0 ? +(grounded/n*100).toFixed(1) : 100;
  let trend=null;
  if(process.env.PRIOR){ try{ const p=JSON.parse(fs.readFileSync(process.env.PRIOR,"utf8")); if(typeof p.vulnerability_density==="number") trend = +(density - p.vulnerability_density).toFixed(2); }catch(e){} }
  process.stderr.write(`security-posture density=${density} percent_fixed=${percent_fixed} mttr_hours=${mttr_hours===null?"-":mttr_hours} coverage=${threat_model_coverage} local_only=true\n`);
  const metric={ space_dimension:"security", local_only:true, upload:false,
    findings:n, dependencies:deps,
    vulnerability_density:density, percent_deps_fix_applied:percent_fixed,
    mttr_to_remediate_hours:mttr_hours, threat_model_coverage:threat_model_coverage, trend,
    posture: density===0 ? "clean" : (percent_fixed>=100 ? "remediated" : "open") };
  if(process.env.JSON==="1") process.stdout.write(JSON.stringify(metric));
'
