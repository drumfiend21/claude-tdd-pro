#!/usr/bin/env bash
# commands/cvd-record.sh - C-23 coordinated vulnerability-disclosure evidence record
# (v1.18 EO amendment §28.1; contract §2.30 record-half).
#
# Produces a clearinghouse-style coordinated-disclosure record from H-14 (vuln-scan) findings -- the
# EO Sec. 2 "find and fix" loop made AUDITABLE. Each record carries
# {advisory_id, severity, component, fixed_in, disclosed_at, remediation_status, source}, is appended
# to the C-4 audit log, and is carried by the §2.24 portable audit-pack so it is exportable for
# government/agency review. remediation_status is an enum: open | in_progress | fixed.
#
# CLI: --findings <json>  (H-14 findings: array of {component,severity,fixed_in,advisory_id,source[,remediation_status]})
#      [--disclosed-at <iso>] [--audit-log <path>] [--json]
# stderr: per record `cvd-record advisory=<id> component=<c> severity=<s> fixed_in=<v> status=<rs>`;
#         summary `cvd-record records=<n> audit_logged=<0|1>`
# Exit: 0 ok | 2 usage.
set -uo pipefail
FINDINGS=""; DISCLOSED=""; AUDITLOG=""; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --findings) FINDINGS="${2-}"; shift 2 ;;
    --disclosed-at) DISCLOSED="${2-}"; shift 2 ;;
    --audit-log) AUDITLOG="${2-}"; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help) echo "Usage: cvd-record.sh --findings <json> [--disclosed-at <iso>] [--audit-log <path>] [--json]" >&2; exit 0 ;;
    *) echo "cvd-record: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$FINDINGS" ] && { echo "cvd-record: --findings <json> required" >&2; exit 2; }
[ -f "$FINDINGS" ] || { echo "cvd-record: not a file: $FINDINGS" >&2; exit 2; }

FINDINGS="$FINDINGS" DISCLOSED="${DISCLOSED:-2026-01-01T00:00:00Z}" AUDITLOG="$AUDITLOG" JSON="$JSON" node -e '
  const fs=require("fs");
  let findings; try{ findings=JSON.parse(fs.readFileSync(process.env.FINDINGS,"utf8")); }catch(e){ process.stderr.write("cvd-record: findings not valid json\n"); process.exit(2); }
  if(!Array.isArray(findings)){ process.stderr.write("cvd-record: findings must be a json array\n"); process.exit(2); }
  const ENUM=new Set(["open","in_progress","fixed"]);
  const records=findings.map(f=>{
    let rs = f.remediation_status;
    if(!ENUM.has(rs)) rs = f.fixed_in ? "fixed" : "open";   // a named fixed_in => the fix was applied
    return { advisory_id: f.advisory_id || ("ADV-"+(f.component||"unknown")),
      severity: f.severity || "unknown", component: f.component || "unknown",
      fixed_in: f.fixed_in || null, disclosed_at: process.env.DISCLOSED,
      remediation_status: rs, source: f.source || "vuln-scan" };
  });
  for(const r of records) process.stderr.write(`cvd-record advisory=${r.advisory_id} component=${r.component} severity=${r.severity} fixed_in=${r.fixed_in||"-"} status=${r.remediation_status}\n`);
  let logged=0;
  if(process.env.AUDITLOG){ try{ for(const r of records) fs.appendFileSync(process.env.AUDITLOG, JSON.stringify({type:"cvd-record", ...r})+"\n"); logged=1; }catch(e){} }
  process.stderr.write(`cvd-record records=${records.length} audit_logged=${logged}\n`);
  if(process.env.JSON==="1") process.stdout.write(JSON.stringify({records, audit_pack_section:"coordinated-disclosure"}));
'
