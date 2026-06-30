// evals/dep-hash.js — scoped eval-cache dependency hashing (§28.53).
//
// Computes, for each spec, a hash over the TRANSITIVE CLOSURE of the substrate it depends on, so a
// test is invalidated only when a function it (transitively) exercises changes — not on every
// substrate edit. Unit tests reference a narrow entrypoint -> narrow closure -> stay cached across
// unrelated CLs. Integration tests reference the whole engine -> broad closure -> invalidate widely
// (correct: they exercise everything).
//
// CORRECTNESS BIAS = OVER-INCLUSION. A missed dependency would be a false green, so extraction errs
// toward including too much: it follows $PLUGIN_ROOT/ paths AND bare substrate dir/file tokens (e.g.
// enforce-file.sh globs the corpus via the string literal "generated-code-quality-standards"). A
// spec with no resolvable substrate reference emits "GLOBAL" -> the runner falls back to the
// whole-tree hash (today's conservative behavior).
//
// Usage: node dep-hash.js <plugin_root> <specs_dir> <out_dir>
// Out:   one file <out_dir>/<spec_name> containing the dep hash (or "GLOBAL"), for O(1) worker lookup.
const fs = require("fs"), path = require("path"), crypto = require("crypto");
const ROOT = process.argv[2], SPECS_DIR = process.argv[3], OUT = process.argv[4];
const DIRS = ["rubric","commands","agents","skills","hooks","profiles","schemas","compliance",
  "generated-code-quality-standards","templates","scripts","space","seed","migrations","standards",
  "design-tokens","prompts","pr-corpus","lsp","scaffolds","vscode-tdd-pro","community","community-shared"];

// 1) enumerate substrate files + per-file content sha
const fileSha = {};
(function init(){
  function walk(d){ let es; try{es=fs.readdirSync(path.join(ROOT,d),{withFileTypes:true})}catch(e){return}
    for(const e of es){ const rp=d+"/"+e.name;
      if(e.isDirectory()) walk(rp);
      else if(e.isFile()){ try{ fileSha[rp]=crypto.createHash("sha256").update(fs.readFileSync(path.join(ROOT,rp))).digest("hex"); }catch(e){} } } }
  for(const d of DIRS) walk(d);
})();
const ALL = Object.keys(fileSha);
const filesUnder = (p)=> ALL.filter(r=> r===p || r.startsWith(p+"/"));

// 2) per-substrate-file references.
//    (a) explicit path tokens "<dir>/<path>" -> the specific file (or all files if it's a dir path).
//    (b) WHOLESALE-READ COLLECTIONS: dirs a script reads in bulk by glob or dispatches by name, where
//        a bare mention is a real whole-dir dependency -> include all files under them. These are the
//        corpus (enforce-file/audit glob every rule) and rubric/detectors (detectors run by name from
//        the rule's `detector` field). A bare mention pulls the whole collection (safe over-inclusion);
//        a bare mention of an ORDINARY dir (e.g. "rubric") does NOT (that would collapse all scoping).
const dirAlt = DIRS.map(d=>d.replace(/[-]/g,"\\-")).join("|");
const PATH_RE = new RegExp("(?:"+dirAlt+")\\/[A-Za-z0-9_.\\/-]+","g");
const COLLECTIONS = [
  { token: /generated-code-quality-standards/, dir: "generated-code-quality-standards" },
  { token: /(^|[^A-Za-z0-9_./-])detectors([^A-Za-z0-9_./-]|$)/, dir: "rubric/detectors" },
];
const clean = (p)=> p.replace(/[.'")\\,:;]+$/,"");
function refsOf(rel){
  let txt=""; try{txt=fs.readFileSync(path.join(ROOT,rel),"utf8")}catch(e){return new Set()}
  const refs=new Set(); let m;
  while((m=PATH_RE.exec(txt))){ const p=clean(m[0]); if(fileSha[p]) refs.add(p); else filesUnder(p).forEach(x=>refs.add(x)); }
  for(const c of COLLECTIONS){ if(c.token.test(txt)) filesUnder(c.dir).forEach(x=>refs.add(x)); }
  return refs;
}
const DREF = {}; for(const r of ALL) DREF[r]=refsOf(r);

// 3) per-spec closure -> dep hash
try{ fs.mkdirSync(OUT,{recursive:true}); }catch(e){}
const specs = fs.readdirSync(SPECS_DIR).filter(f=>f.endsWith(".json"));
let total=0, scoped=0;
for(const sf of specs){
  const name=sf.replace(/\.json$/,""); total++;
  const write=(v)=>{ try{ fs.writeFileSync(path.join(OUT,name), v); }catch(e){} };
  let j; try{j=JSON.parse(fs.readFileSync(path.join(SPECS_DIR,sf),"utf8"))}catch(e){ write("GLOBAL"); continue; }
  const text=(j.command||"")+"\n"+((j.setup||[]).join("\n"));
  const seeds=new Set(); let m;
  const PR=/\$\{?CLAUDE_PLUGIN_ROOT\}?\/([A-Za-z0-9_.\/-]+)/g;
  while((m=PR.exec(text))){ const p=clean(m[1]); if(fileSha[p])seeds.add(p); else filesUnder(p).forEach(x=>seeds.add(x)); }
  let mm; const P2=new RegExp(PATH_RE.source,"g");
  while((mm=P2.exec(text))){ const p=clean(mm[0]); if(fileSha[p])seeds.add(p); else filesUnder(p).forEach(x=>seeds.add(x)); }
  for(const c of COLLECTIONS){ if(c.token.test(text)) filesUnder(c.dir).forEach(x=>seeds.add(x)); }
  if(seeds.size===0){ write("GLOBAL"); continue; }
  const closure=new Set(seeds), stack=[...seeds];
  while(stack.length){ const f=stack.pop(); for(const r of (DREF[f]||[])) if(!closure.has(r)){ closure.add(r); stack.push(r); } }
  const h=crypto.createHash("sha256");
  for(const f of [...closure].sort()) h.update(f+":"+fileSha[f]+"\n");
  write(h.digest("hex")); scoped++;
}
process.stderr.write(`dep-hash: specs=${total} scoped=${scoped} global_fallback=${total-scoped} substrate_files=${ALL.length}\n`);
