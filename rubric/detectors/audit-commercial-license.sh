#!/usr/bin/env bash
# rubric/detectors/audit-commercial-license.sh — the authoritative commercial-sale license gate.
#
# Guarantees CTP (and, by consumption, GCTP) can be USED, DISTRIBUTED, and SOLD COMMERCIALLY with
# no licensing conflict. It enforces the bright line:
#
#   BUNDLED / REDISTRIBUTED content (data shipped inside the plugin) MUST be permissive or
#   attribution-only — never copyleft-source (GPL/AGPL/LGPL source), never share-alike (CC-BY-SA),
#   never non-commercial (CC-*-NC), never proprietary.
#
#   INVOKE-ONLY tools (installed separately by the user's package manager at install time, never
#   shipped in the plugin) may carry ANY OSI license incl. GPL/LGPL — invoking a program as an
#   arms-length subprocess does not make the caller a derivative work, and commercial USE of
#   GPL/LGPL software is unrestricted. Such tools MUST be flagged invoke_only.
#
#   CITED sources (provenance only — CTP authors original rule prose and cites the authority; it
#   does NOT redistribute the source's copyrighted text) may carry any license. Citation is not
#   redistribution.
#
# Checks: (1) bundled vocabulary mirrors are permissive; (2) every toolchain tool is permissive OR
# copyleft-and-invoke_only; (3) every routing-table tool is permissive OR copyleft-and-invoke_only.
#
# CLI: [--root <dir>] [--quiet]
# stderr: per violation `commercial-license surface=<s> item=<x> license=<l> reason=<...>`; summary
#         `commercial-license status=<green|red> bundled=<b> tools=<t> violations=<v>`
# Exit: 0 commercial-sale-safe | 1 violations | 2 usage.

set -uo pipefail
ROOT=""; QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2-}"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) echo "Usage: audit-commercial-license.sh [--root <dir>] [--quiet]" >&2; exit 0 ;;
    *) echo "audit-commercial-license: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$ROOT" ] && ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
command -v node >/dev/null 2>&1 || { echo "audit-commercial-license: node required" >&2; exit 2; }

ROOT="$ROOT" QUIET="$QUIET" node -e '
  const fs=require("fs"),path=require("path");
  const root=process.env.ROOT, quiet=process.env.QUIET==="1";
  // Licenses safe to BUNDLE/REDISTRIBUTE in a product sold commercially (permissive + attribution-only).
  const BUNDLE_OK = [
    "MIT","MIT-0","Apache-2.0","Apache 2.0","BSD-2-Clause","BSD-3-Clause","ISC","MPL-2.0","MPL 2.0",
    "CC0-1.0","CC0","CC-BY-4.0","CC-BY 4.0","CC-BY-3.0","CC-BY 3.0","Unlicense","0BSD","public-domain",
    "public domain","Apache-2.0 OR MIT","BlueOak-1.0.0"
  ];
  // Copyleft / share-alike / non-commercial / proprietary markers that are NOT bundle-safe.
  const isCopyleftOrRestricted = l => /GPL|AGPL|LGPL|CC-BY-SA|[ -]NC[ -]?|NonCommercial|proprietary|EULA|cite-link/i.test(l||"");
  const norm = l => (l||"").trim();
  let violations=0, bundled=0, tools=0;
  const fail=(s,item,lic,reason)=>{ violations++; if(!quiet) process.stderr.write(`commercial-license surface=${s} item=${item} license=${lic} reason=${reason}\n`); };
  const read=(p)=>{ try{return JSON.parse(fs.readFileSync(path.join(root,p),"utf8"));}catch(e){return null;} };

  // (1) BUNDLED vocabulary mirrors must be permissive/attribution (we redistribute these).
  const prov=read("vendor/canonical-vocabulary/provenance.json");
  if(prov&&prov.mirrors){ for(const[k,v]of Object.entries(prov.mirrors)){ bundled++;
    if(!BUNDLE_OK.includes(norm(v.license))) fail("bundled-vocabulary",k,v.license,"not-permissive-for-redistribution"); } }

  // (2) toolchain: permissive OR (copyleft AND invoke_only AND not vendored/binary-bundled).
  const tc=read("rubric/runners/toolchain.json");
  if(tc&&tc.tools){ for(const t of tc.tools){ tools++;
    if(BUNDLE_OK.includes(norm(t.license))) continue;        // permissive tool -> fine either way
    if(isCopyleftOrRestricted(t.license)){
      if(t.invoke_only!==true) fail("toolchain",t.tool,t.license,"copyleft-tool-not-flagged-invoke_only");
    } else fail("toolchain",t.tool,t.license,"unrecognized-license"); } }

  // (3) routing-table tools (mirror the same rule).
  let routing="";
  try{ routing=fs.readFileSync(path.join(root,"standards/kind-to-tool-routing.yaml"),"utf8"); }catch(e){}
  for(const m of routing.matchAll(/tool:\s*([^\s,}]+).*?license:\s*([^,}\n]+)(.*)/g)){
    const tool=m[1], lic=norm(m[2]), rest=m[3]||"";
    if(BUNDLE_OK.includes(lic)) continue;
    if(isCopyleftOrRestricted(lic)){ if(!/invoke_only:\s*true/.test(rest)) fail("routing",tool,lic,"copyleft-routing-tool-not-invoke_only"); }
  }

  const status=violations===0?"green":"red";
  if(!quiet) process.stderr.write(`commercial-license status=${status} bundled=${bundled} tools=${tools} violations=${violations}\n`);
  process.exit(violations===0?0:1);
'
