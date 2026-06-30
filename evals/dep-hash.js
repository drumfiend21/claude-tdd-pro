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
// Usage: node dep-hash.js <plugin_root> <specs_dir> <out_dir> [runner_sha tree_sha cache_dir]
// Out:   per spec, <out_dir>/<spec_name> contains the resolved cache KEY (or the dep hash when the
//        optional cache args are omitted). When the cache args are given it ALSO computes the full
//        cache key the worker would compute and, if that marker already exists, creates a
//        <out_dir>/<spec_name>.hit sentinel so the runner can skip the spec WITHOUT spawning a worker
//        (this is what makes a warm full-suite run fast). Falls back to tree_sha for GLOBAL specs.
const fs = require("fs"), path = require("path"), crypto = require("crypto");
const ROOT = process.argv[2], SPECS_DIR = process.argv[3], OUT = process.argv[4];
const RUNNER_SHA = process.argv[5] || "", TREE_SHA = process.argv[6] || "", CACHE_DIR = process.argv[7] || "";
const PLAN = !!(RUNNER_SHA && TREE_SHA && CACHE_DIR);
const sha = (s)=> crypto.createHash("sha256").update(s).digest("hex");
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
let total=0, scoped=0, hits=0;
function depHashOf(text){
  const seeds=new Set(); let m;
  const PR=/\$\{?CLAUDE_PLUGIN_ROOT\}?\/([A-Za-z0-9_.\/-]+)/g;
  while((m=PR.exec(text))){ const p=clean(m[1]); if(fileSha[p])seeds.add(p); else filesUnder(p).forEach(x=>seeds.add(x)); }
  let mm; const P2=new RegExp(PATH_RE.source,"g");
  while((mm=P2.exec(text))){ const p=clean(mm[0]); if(fileSha[p])seeds.add(p); else filesUnder(p).forEach(x=>seeds.add(x)); }
  for(const c of COLLECTIONS){ if(c.token.test(text)) filesUnder(c.dir).forEach(x=>seeds.add(x)); }
  if(seeds.size===0) return null;            // -> GLOBAL
  const closure=new Set(seeds), stack=[...seeds];
  while(stack.length){ const f=stack.pop(); for(const r of (DREF[f]||[])) if(!closure.has(r)){ closure.add(r); stack.push(r); } }
  const h=crypto.createHash("sha256");
  for(const f of [...closure].sort()) h.update(f+":"+fileSha[f]+"\n");
  return h.digest("hex");
}
for(const sf of specs){
  const name=sf.replace(/\.json$/,""); total++;
  const specPath=path.join(SPECS_DIR,sf);
  let raw; try{ raw=fs.readFileSync(specPath); }catch(e){ try{fs.writeFileSync(path.join(OUT,name),"GLOBAL")}catch(_){}; continue; }
  let j; try{ j=JSON.parse(raw.toString("utf8")); }catch(e){ try{fs.writeFileSync(path.join(OUT,name),"GLOBAL")}catch(_){}; continue; }
  const text=(j.command||"")+"\n"+((j.setup||[]).join("\n"));
  const dh=depHashOf(text);
  const effHash = dh===null ? (PLAN ? TREE_SHA : "GLOBAL") : dh;
  if(dh!==null) scoped++;
  if(!PLAN){ try{ fs.writeFileSync(path.join(OUT,name), effHash); }catch(e){} continue; }
  // cache PLAN: compute the exact key the worker computes, and pre-check the marker.
  const specSha = sha(raw);                                  // == sha256sum of the spec file
  const key = sha(specSha+"\n"+effHash+"\n"+RUNNER_SHA+"\n"); // == worker's printf '%s\n%s\n%s\n' | sha256sum
  try{ fs.writeFileSync(path.join(OUT,name), key); }catch(e){}
  if(fs.existsSync(path.join(CACHE_DIR, key+".passed"))){ try{ fs.writeFileSync(path.join(OUT,name+".hit"), ""); }catch(e){} hits++; }
}
process.stderr.write(`dep-hash: specs=${total} scoped=${scoped} global_fallback=${total-scoped}`+(PLAN?` cache_hits=${hits}`:``)+` substrate_files=${ALL.length}\n`);
