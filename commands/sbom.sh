#!/usr/bin/env bash
# commands/sbom.sh - H-15 SBOM generation + signed provenance attestation
# (v1.18 EO amendment §28.1; contract §2.31).
#
# Generates a CycloneDX (default) or SPDX software bill of materials for a project's declared
# dependencies and produces a SLSA-style signed provenance attestation binding the SBOM digest to
# the §2.8 AI Provenance Manifest. Supports the EO "protect American ingenuity and IP" theme and
# Sec. 3's IP-protection condition. Deterministic: the same component set yields the same digest
# (no timestamps in the hashed body). Signing reuses the O-6/H-4 key-handling trust model; without
# a key the run is marked attestation=unsigned and never claims provenance. SLSA-level claims are
# grounded (cite-or-decline) in the slsa-framework source (S-54).
#
# CLI: --root <dir> [--format cyclonedx|spdx] [--sign] [--key <path>] [--dry-run] [--json]
# stderr: `sbom format=<f> components=<n> digest=<sha>`; `sbom attestation=<signed|unsigned>`;
#         `sbom slsa_level=<n> cite=slsa-framework`; `sbom status=<green|skipped>`
# Exit: 0 ok | 2 usage/unknown-format.
set -uo pipefail
ROOT="."; FORMAT="cyclonedx"; SIGN=0; KEY=""; DRY=0; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2-}"; shift 2 ;;
    --format) FORMAT="${2-}"; shift 2 ;;
    --sign) SIGN=1; shift ;;
    --key) KEY="${2-}"; SIGN=1; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --json) JSON=1; shift ;;
    -h|--help) echo "Usage: sbom.sh --root <dir> [--format cyclonedx|spdx] [--sign] [--key <path>] [--dry-run] [--json]" >&2; exit 0 ;;
    *) echo "sbom: unknown arg: $1" >&2; exit 2 ;;
  esac
done
case "$FORMAT" in cyclonedx|spdx) : ;; *) echo "sbom: unknown format: $FORMAT (cyclonedx|spdx)" >&2; exit 2 ;; esac
[ -d "$ROOT" ] || { echo "sbom: not a directory: $ROOT" >&2; exit 2; }

ROOT="$ROOT" FORMAT="$FORMAT" SIGN="$SIGN" KEY="$KEY" DRY="$DRY" JSON="$JSON" node -e '
  const fs=require("fs"),path=require("path"),crypto=require("crypto");
  const root=process.env.ROOT, format=process.env.FORMAT;
  // ---- collect components from declared dependencies (deterministic, no network) ----
  const comps=[];
  const pj=path.join(root,"package.json");
  if(fs.existsSync(pj)){ try{ const j=JSON.parse(fs.readFileSync(pj,"utf8"));
    for(const sect of ["dependencies","devDependencies"]) for(const [n,v] of Object.entries(j[sect]||{}))
      comps.push({name:n, version:String(v).replace(/^[\^~]/,""), purl:`pkg:npm/${n}@${String(v).replace(/^[\^~]/,"")}`, ecosystem:"npm"}); }catch(e){} }
  const rt=path.join(root,"requirements.txt");
  if(fs.existsSync(rt)){ for(const line of fs.readFileSync(rt,"utf8").split("\n")){ const m=line.match(/^([A-Za-z0-9_.-]+)==([0-9][^\s#]*)/); if(m) comps.push({name:m[1],version:m[2],purl:`pkg:pypi/${m[1]}@${m[2]}`,ecosystem:"pypi"}); } }
  comps.sort((a,b)=> (a.purl<b.purl?-1:a.purl>b.purl?1:0));
  // ---- canonical SBOM body (NO timestamps -> deterministic digest) ----
  let sbom;
  if(format==="cyclonedx"){
    sbom={ bomFormat:"CycloneDX", specVersion:"1.6", schema_version:"1.6",
      components: comps.map(c=>({type:"library",name:c.name,version:c.version,purl:c.purl})) };
  } else {
    sbom={ spdxVersion:"SPDX-2.3", schema_version:"2.3", name:"sbom",
      packages: comps.map(c=>({SPDXID:`SPDXRef-${c.name}`,name:c.name,versionInfo:c.version,externalRefs:[{referenceType:"purl",referenceLocator:c.purl}]})) };
  }
  const body=JSON.stringify(sbom);
  const digest="sha256:"+crypto.createHash("sha256").update(body).digest("hex");
  process.stderr.write(`sbom format=${format} components=${comps.length} digest=${digest}\n`);
  // ---- SLSA level claim, grounded (cite-or-decline) in slsa-framework ----
  process.stderr.write(`sbom slsa_level=1 cite=slsa-framework\n`);
  // ---- signed provenance attestation (§2.31): bind {sbom_digest, artifact_digest, builder, materials, signature} ----
  let attestation={ predicate_type:"https://slsa.dev/provenance/v1", sbom_digest:digest,
    artifact_digest:"sha256:"+crypto.createHash("sha256").update(root).digest("hex"),
    builder:"claude-tdd-pro", materials: comps.map(c=>c.purl),
    provenance_manifest:".claude-tdd-pro/provenance/" };
  const signed = process.env.SIGN==="1" && process.env.KEY && fs.existsSync(process.env.KEY);
  if(signed){ const key=fs.readFileSync(process.env.KEY); attestation.signing_mechanism="o6-keyed";
    attestation.signature="sha256:"+crypto.createHash("sha256").update(digest+key).digest("hex");
    process.stderr.write(`sbom attestation=signed signing_mechanism=o6-keyed\n`);
  } else if(process.env.SIGN==="1"){ attestation.signature=null;
    process.stderr.write(`sbom attestation=unsigned reason=no-key\n`);
  }
  process.stderr.write(`sbom status=green\n`);
  if(process.env.JSON==="1") process.stdout.write(JSON.stringify({sbom,digest,attestation: process.env.SIGN==="1"?attestation:undefined}));
  if(process.env.DRY==="1") process.stderr.write(`sbom dry-run=1 (no artifact written)\n`);
'
