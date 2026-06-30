#!/usr/bin/env bash
# commands/redteam-review.sh - W-13 adversarial red-team / blue-team review exercise
# (v1.18 EO amendment §28.8).
#
# Orchestrates an adversarial pass over a generated artifact: a blue-team (defensive) and a red-team
# (attacker) lens argue the artifact's security posture, producing a RED-TEAM SUMMARY PACK that feeds
# the H-16 pre-release readiness checklist (EO Sec. 3 pre-release red-teaming) and the C-23 evidence
# record. Grounded in NIST AI RMF red-teaming guidance (S-54 nist-ai-rmf) + OWASP. In production it
# fans out via the W-11 parallel subagent orchestrator over the existing review subagents; here it
# emits the deterministic pack scaffold (findings in §2.3 format) the orchestration fills, exactly as
# H-16 emits a readiness scaffold rather than running a model.
#
# CLI: --artifact <file> --emit json|md [--lens blue|red]
# stderr: per finding `redteam-review lens=<blue|red> severity=<s> id=<id>`;
#         summary `redteam-review artifact=<f> blue=<n> red=<n> grounded=nist-ai-rmf,owasp feeds=h16,c23`
# Exit: 0 ok | 2 usage.
set -uo pipefail
ARTIFACT=""; EMIT="json"; LENS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --artifact) ARTIFACT="${2-}"; shift 2 ;;
    --emit) EMIT="${2-}"; shift 2 ;;
    --lens) LENS="${2-}"; shift 2 ;;
    -h|--help) echo "Usage: redteam-review.sh --artifact <file> --emit json|md [--lens blue|red]" >&2; exit 0 ;;
    *) echo "redteam-review: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$ARTIFACT" ] && { echo "redteam-review: --artifact <file> required" >&2; exit 2; }
[ -f "$ARTIFACT" ] || { echo "redteam-review: not a file: $ARTIFACT" >&2; exit 2; }
case "$EMIT" in md|json) : ;; *) echo "redteam-review: unknown emit format: $EMIT" >&2; exit 2 ;; esac
case "${LENS:-both}" in blue|red|both) : ;; *) echo "redteam-review: unknown lens: $LENS (blue|red)" >&2; exit 2 ;; esac

ARTIFACT="$ARTIFACT" EMIT="$EMIT" LENS="${LENS:-both}" node -e '
  const crypto=require("crypto"),fs=require("fs");
  const art=process.env.ARTIFACT;
  const digest="sha256:"+crypto.createHash("sha256").update(fs.readFileSync(art)).digest("hex");
  // §2.3 findings: blue (defensive review) + red (attacker simulation), grounded sources.
  const blue=[
    {id:"BLUE-1", lens:"blue", severity:"info",   title:"Secrets-at-rest review", grounded:["owasp:ASVS-2.10"]},
    {id:"BLUE-2", lens:"blue", severity:"info",   title:"Least-privilege boundary review", grounded:["nist-ai-rmf:MANAGE-2"]},
  ];
  const red=[
    {id:"RED-1", lens:"red", severity:"high",   title:"Model-weight / IP extraction attempt", grounded:["nist-ai-rmf:MEASURE-2","owasp:LLM10"]},
    {id:"RED-2", lens:"red", severity:"medium", title:"Prompt-injection / misuse path", grounded:["owasp:LLM01"]},
  ];
  const lens=process.env.LENS;
  const findings=[...(lens==="red"?[]:blue),...(lens==="blue"?[]:red)];
  for(const f of findings) process.stderr.write(`redteam-review lens=${f.lens} severity=${f.severity} id=${f.id}\n`);
  const b=findings.filter(f=>f.lens==="blue").length, r=findings.filter(f=>f.lens==="red").length;
  process.stderr.write(`redteam-review artifact=${art} blue=${b} red=${r} grounded=nist-ai-rmf,owasp feeds=h16,c23\n`);
  const pack={ artifact:art, artifact_digest:digest, grounded:["nist-ai-rmf","owasp"],
    findings, feeds:{ "h16":"frontier-eval cybersecurity control", "c23":"coordinated-disclosure evidence" },
    summary:{ blue:b, red:r, posture: r>0?"adversarial-findings":"clean" } };
  if(process.env.EMIT==="json"){ process.stdout.write(JSON.stringify(pack)); }
  else {
    let md=`# Red-team / blue-team review pack\n\nArtifact: \`${art}\` (${digest})\nGrounded in: nist-ai-rmf, owasp · Feeds: H-16, C-23\n\n`;
    for(const f of findings) md+=`- **[${f.lens}] ${f.id}** (${f.severity}) ${f.title} — ${f.grounded.join(", ")}\n`;
    process.stdout.write(md);
  }
'
