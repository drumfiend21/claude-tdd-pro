#!/usr/bin/env bash
# PreToolUse hook (§28.60): GOVERN-BEFORE-WRITE. Enforce the CTP rule corpus on the PROPOSED content
# of an Edit/Write/MultiEdit BEFORE it is persisted to disk — governing the generation of content in
# memory. The proposed content is reconstructed from the tool input (Write -> content; Edit/MultiEdit
# -> the current file with the replacement(s) applied), written to an in-memory scratch file, and run
# through rubric/enforce-file.sh. A P0/P1 violation DENIES the tool call (exit 2, surfaced to the model)
# so a violating file is never written; clean content is allowed (exit 0). The PostToolUse
# enforce-standards-on-save.sh remains the after-write backstop (routed tools + bundle + profile).
#
# Fail-open like the other write hooks: any defense-trip / missing dep / unparseable input -> exit 0.
set -uo pipefail

INPUT="$(cat)"
command -v node >/dev/null 2>&1 || exit 0
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
ENFORCER="$PLUGIN_ROOT/rubric/enforce-file.sh"
[ -f "$ENFORCER" ] || exit 0

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH" 2>/dev/null' EXIT

# Reconstruct the proposed content + basename; write it to $SCRATCH/<basename>. Prints the scratch path
# (empty -> nothing to govern / skip). Only the config/markup/IaC kinds the CTP corpus targets are
# governed here (JS/Py stay with lint-on-save's post-write path).
SCRATCH_FILE="$(printf '%s' "$INPUT" | SCRATCH="$SCRATCH" node -e '
  const fs=require("fs"), path=require("path");
  let raw=""; process.stdin.on("data",c=>raw+=c); process.stdin.on("end",()=>{
    let j; try { j=JSON.parse(raw); } catch { process.exit(0); }
    const ti=j.tool_input||{}; const tool=j.tool_name||"";
    const fp=ti.file_path||ti.path||"";
    if(!/^[A-Za-z0-9._/\-~ ]+$/.test(fp)) process.exit(0);
    const base=path.basename(fp);
    if(!/\.(ya?ml|json|md|markdown|tf|bicep|template|sarif|tpl|ts|tsx|js|jsx|mjs|cjs|py|go|rb|rs|java|kt|php|cs|swift|scala|ex)$|(^|\/)(Jenkinsfile)$/i.test(base)) process.exit(0);
    const readCur=()=>{ try { return fs.readFileSync(fp,"utf8"); } catch { return ""; } };
    const applyOne=(s,o,n,all)=>{ if(o===undefined||o==="") return s; if(all) return s.split(o).join(n??"");
      const i=s.indexOf(o); return i<0 ? s : s.slice(0,i)+(n??"")+s.slice(i+o.length); };
    let content=null;
    if(tool==="Write"){ content = ti.content!=null ? String(ti.content) : ""; }
    else if(tool==="Edit"){ content = applyOne(readCur(), ti.old_string, ti.new_string, !!ti.replace_all); }
    else if(tool==="MultiEdit"){ let c=readCur(); for(const e of (ti.edits||[])) c=applyOne(c, e.old_string, e.new_string, !!e.replace_all); content=c; }
    else process.exit(0);
    if(content==null) process.exit(0);
    const out=path.join(process.env.SCRATCH, base);
    try { fs.writeFileSync(out, content); } catch { process.exit(0); }
    process.stdout.write(out);
  });
' 2>/dev/null)"

[ -z "$SCRATCH_FILE" ] && exit 0
[ -f "$SCRATCH_FILE" ] || exit 0

# §29.6: BOTH development write-time (here) and consult (architect-session) call the SAME shared
# primitive rubric/enforce-write-time.sh for native enforcement of the entire ruleset — so the native
# enforcement is byte-identical across both by construction (one code path; the write-time flag set —
# the single-file gate plus app-code inclusion — is decided in that one script, not duplicated here).
set +e
OUTPUT=$(bash "$PLUGIN_ROOT/rubric/enforce-write-time.sh" "$SCRATCH_FILE" 2>&1)
EC=$?
set -e

# exit 1 from enforce-file = a BLOCKING (P0/P1) violation in the PROPOSED content -> deny the write.
if [ "$EC" -eq 1 ]; then
  {
    echo "[enforce-standards-pre-write] proposed content has blocking CTP rule violation(s) — write denied before save:"
    echo
    printf '%s\n' "$OUTPUT"
    echo
    echo "Revise the content to satisfy the P0/P1 rule(s) above, then retry. (P2/P3 lines are advisory.)"
  } >&2
  exit 2
fi

exit 0
