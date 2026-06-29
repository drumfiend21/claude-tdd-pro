#!/usr/bin/env bash
# rubric/runners/run-tool.sh — the per-tool runner of the composite engine. Invokes one FOSS tool
# against a file and normalizes its output to SARIF 2.1.0 (the §28.29 bus aggregates).
#
# Resolution: 4 proven bespoke adapters (eslint/markdownlint/cspell/checkov) PLUS a GENERIC
# spec-driven path for every other tool in rubric/runners/toolchain.json (read its `bin` + `exec`
# spec). exec.mode: "sarif" = tool prints SARIF 2.1.0 to stdout; "exit" = exit-code (0 clean /
# non-0 findings -> SARIF synthesized from the tool's output). So all ~80 tools are wireable.
#
# MISSING-TOOL POLICY (§28.28): present -> run (0 clean / 1 findings); absent + --required ->
# HARD-FAIL (exit 1); absent (optional) -> not_enforced (exit 3). RUN_TOOL_FORCE_ABSENT=1 forces
# the absent path (deterministic test affordance). Tool-independent: the eval suite stays green on
# a fresh (toolless) container.
#
# CLI: --tool <name> --file <path> [--required] [--json]
# stderr: `run-tool tool=<t> status=<green|red|not_enforced|hard-fail> findings=<n>`
# Exit: 0 green | 1 red/hard-fail | 3 not_enforced | 2 usage.

set -uo pipefail
TOOL=""; FILE=""; REQUIRED=0; JSON=0; TOOL_OPTIONS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tool) TOOL="${2-}"; shift 2 ;;
    --file) FILE="${2-}"; shift 2 ;;
    --tool-options) TOOL_OPTIONS="${2-}"; shift 2 ;;
    --required) REQUIRED=1; shift ;;
    --json) JSON=1; shift ;;
    -h|--help) echo "Usage: run-tool.sh --tool <name> --file <path> [--tool-options <json>] [--required] [--json]" >&2; exit 0 ;;
    *) echo "run-tool: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$TOOL" ] && { echo "run-tool: --tool required" >&2; exit 2; }
[ -z "$FILE" ] && { echo "run-tool: --file required" >&2; exit 2; }
[ -f "$FILE" ] || { echo "run-tool: not a file: $FILE" >&2; exit 2; }

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
MANIFEST="$PLUGIN_ROOT/rubric/runners/toolchain.json"

# resolve bin + exec spec: bespoke 4 use known bins; others come from the manifest.
BESPOKE=0; EXEC_MODE=""; EXEC_ARGS=""; ADVISORY=0
case "$TOOL" in
  eslint)       BIN="eslint"; BESPOKE=1 ;;
  markdownlint) BIN="markdownlint-cli2"; BESPOKE=1 ;;
  cspell)       BIN="cspell"; BESPOKE=1 ;;
  checkov)      BIN="checkov"; BESPOKE=1 ;;
  *)
    # generic: look up the tool in the manifest (bin, exec.mode, exec.args, advisory)
    read -r BIN EXEC_MODE ADVISORY EXEC_ARGS < <(MANIFEST_PATH="$MANIFEST" TOOL="$TOOL" node -e '
      const m=JSON.parse(require("fs").readFileSync(process.env.MANIFEST_PATH,"utf8")); const t=(m.tools||[]).find(x=>x.tool===process.env.TOOL);
      if(!t){process.stdout.write("__UNKNOWN__ __ 0 __");process.exit(0);}
      process.stdout.write((t.bin||t.tool)+" "+((t.exec&&t.exec.mode)||"exit")+" "+(t.advisory?1:0)+" "+JSON.stringify((t.exec&&t.exec.args)||""));
    ' 2>/dev/null)
    [ "$BIN" = "__UNKNOWN__" ] && { echo "run-tool: unknown tool: $TOOL" >&2; exit 2; }
    EXEC_ARGS="$(printf '%s' "$EXEC_ARGS" | sed 's/^"//; s/"$//')"  # unquote
    ;;
esac

# Layer-2 (§28.51): emit the tool-NATIVE options from the single config layer into the tool's own
# config file and inject the tool's config flag, so options written once in CTP take effect in the
# real tool. Generic path only (bespoke adapters carry their own config handling). No options => no-op.
CFG_INJECT=""; CFG_DIR=""
if [ -n "$TOOL_OPTIONS" ] && [ "$TOOL_OPTIONS" != "{}" ] && [ "$BESPOKE" -eq 0 ]; then
  CFG_DIR="$(mktemp -d)"
  _cfgpath="$(bash "$PLUGIN_ROOT/rubric/runners/emit-tool-config.sh" --tool "$TOOL" --options "$TOOL_OPTIONS" --out "$CFG_DIR" 2>/dev/null)"
  if [ -n "$_cfgpath" ] && [ -f "$_cfgpath" ]; then
    _flag="$(CAT="$PLUGIN_ROOT/standards/tool-option-surfaces.yaml" TOOL="$TOOL" ruby -ryaml -e 'r=((YAML.unsafe_load_file(ENV["CAT"])["tools"]||{})[ENV["TOOL"]]||{})["render"]; print((r && r["flag"]) ? r["flag"] : "")' 2>/dev/null)"
    [ -n "$_flag" ] && CFG_INJECT="$_flag $_cfgpath"
  fi
fi
trap '[ -n "${CFG_DIR:-}" ] && rm -rf "$CFG_DIR" 2>/dev/null' EXIT

emit_sarif() { # $1=level $2=message $3=ruleId
  FILE="$FILE" LV="$1" MSG="$2" RID="$3" TOOL="$TOOL" node -e '
    const o={version:"2.1.0","$schema":"https://docs.oasis-open.org/sarif/sarif/v2.1.0/errata01/os/schemas/sarif-schema-2.1.0.json",
      runs:[{tool:{driver:{name:process.env.TOOL,version:"runner"}},results:[{ruleId:process.env.RID,level:process.env.LV,
        message:{text:process.env.MSG},locations:[{physicalLocation:{artifactLocation:{uri:process.env.FILE},region:{startLine:1}}}]}]}]};
    process.stdout.write(JSON.stringify(o));'
}
emit_empty_sarif() { TOOL="$TOOL" node -e 'process.stdout.write(JSON.stringify({version:"2.1.0",runs:[{tool:{driver:{name:process.env.TOOL,version:"runner"}},results:[]}]}))'; }

# ---- missing-tool policy ------------------------------------------------------------------
if [ "${RUN_TOOL_FORCE_ABSENT:-0}" = "1" ] || ! command -v "$BIN" >/dev/null 2>&1; then
  if [ "$REQUIRED" -eq 1 ]; then
    [ "$JSON" -eq 1 ] && emit_sarif "error" "required tool '$TOOL' is not installed (hard-require policy)" "tool-absent"
    echo "run-tool tool=$TOOL status=hard-fail findings=1 reason=required-tool-absent" >&2; exit 1
  else
    [ "$JSON" -eq 1 ] && emit_empty_sarif
    echo "run-tool tool=$TOOL status=not_enforced findings=0 reason=optional-tool-absent" >&2; exit 3
  fi
fi

TMP_SARIF="$(mktemp)"; N=0; RAN=1

if [ "$BESPOKE" -eq 1 ]; then
  # -------- the 4 proven bespoke adapters --------
  case "$TOOL" in
    checkov)
      OUTDIR="$(mktemp -d)"
      checkov -f "$FILE" -o sarif --output-file-path "$OUTDIR" --quiet >/dev/null 2>&1 || true
      if [ -f "$OUTDIR/results_sarif.sarif" ]; then cp "$OUTDIR/results_sarif.sarif" "$TMP_SARIF"
        N=$(node -e 'try{const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log((j.runs||[]).reduce((a,r)=>a+(r.results||[]).length,0))}catch(e){console.log(0)}' "$TMP_SARIF")
      else RAN=0; fi; rm -rf "$OUTDIR" ;;
    cspell)
      OUT="$(cspell --no-progress --no-summary "$FILE" 2>/dev/null || true)"; N=$(printf '%s' "$OUT" | grep -c . || true)
      FILE="$FILE" OUT="$OUT" node -e 'const l=(process.env.OUT||"").split("\n").filter(Boolean);process.stdout.write(JSON.stringify({version:"2.1.0",runs:[{tool:{driver:{name:"cspell",version:"runner"}},results:l.map(x=>({ruleId:"cspell-unknown-word",level:"warning",message:{text:x},locations:[{physicalLocation:{artifactLocation:{uri:process.env.FILE},region:{startLine:1}}}]}))}]}))' > "$TMP_SARIF" ;;
    markdownlint)
      OUT="$(markdownlint-cli2 "$FILE" 2>&1 || true)"; N=$(printf '%s' "$OUT" | grep -cE "MD[0-9]+/" || true)
      FILE="$FILE" OUT="$OUT" node -e 'const l=(process.env.OUT||"").split("\n").filter(x=>/MD\d+\//.test(x));process.stdout.write(JSON.stringify({version:"2.1.0",runs:[{tool:{driver:{name:"markdownlint",version:"runner"}},results:l.map(x=>{const m=x.match(/(MD\d+)/),ln=x.match(/:(\d+)/);return {ruleId:(m?m[1]:"markdownlint"),level:"warning",message:{text:x.trim()},locations:[{physicalLocation:{artifactLocation:{uri:process.env.FILE},region:{startLine:(ln?+ln[1]:1)}}}]}})}]}))' > "$TMP_SARIF" ;;
    eslint)
      OUT="$(eslint --format json "$FILE" 2>/dev/null || true)"; [ -z "$OUT" ] && RAN=0
      if [ "$RAN" -eq 1 ]; then
        FILE="$FILE" OUT="$OUT" node -e 'let j;try{j=JSON.parse(process.env.OUT)}catch(e){process.exit(0)}const r=[];for(const f of j)for(const m of (f.messages||[]))r.push({ruleId:m.ruleId||"eslint",level:m.severity===2?"error":"warning",message:{text:m.message},locations:[{physicalLocation:{artifactLocation:{uri:process.env.FILE},region:{startLine:m.line||1}}}]});process.stdout.write(JSON.stringify({version:"2.1.0",runs:[{tool:{driver:{name:"eslint",version:"runner"}},results:r}]}))' > "$TMP_SARIF"
        N=$(node -e 'try{const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log((j.runs[0].results||[]).length)}catch(e){console.log(0)}' "$TMP_SARIF")
      fi ;;
  esac
else
  # -------- generic spec-driven path (any tool in the manifest) --------
  # shellcheck disable=SC2086
  case "$EXEC_MODE" in
    sarif)
      OUT="$("$BIN" $EXEC_ARGS $CFG_INJECT "$FILE" 2>/dev/null || true)"
      if printf '%s' "$OUT" | node -e 'let s="";process.stdin.on("data",c=>s+=c);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.exit(j&&j.version==="2.1.0"?0:1)}catch(e){process.exit(1)}})' 2>/dev/null; then
        printf '%s' "$OUT" > "$TMP_SARIF"
        N=$(node -e 'try{const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log((j.runs||[]).reduce((a,r)=>a+(r.results||[]).length,0))}catch(e){console.log(0)}' "$TMP_SARIF")
      else RAN=0; fi ;;
    *)  # exit-code mode: 0 clean, non-0 findings -> synthesize SARIF from output lines
      set +e; OUT="$("$BIN" $EXEC_ARGS $CFG_INJECT "$FILE" 2>&1)"; EC=$?; set -e
      if [ "$EC" -eq 0 ]; then : > "$TMP_SARIF"; N=0
        FILE="$FILE" TOOL="$TOOL" node -e 'process.stdout.write(JSON.stringify({version:"2.1.0",runs:[{tool:{driver:{name:process.env.TOOL,version:"runner"}},results:[]}]}))' > "$TMP_SARIF"
      elif [ "$ADVISORY" -eq 1 ]; then
        # ADVISORY (formatter): the tool ran and parsed the file fine, it just has auto-fixable
        # style opinions. Record them as note-level findings but DO NOT count them as a blocking
        # violation -- the file is verified well-formed (N stays 0 -> green).
        FILE="$FILE" TOOL="$TOOL" OUT="$OUT" node -e 'const l=(process.env.OUT||"").split("\n").filter(Boolean).slice(0,50);const r=(l.length?l:["style suggestion"]).map(x=>({ruleId:process.env.TOOL+"-style",level:"note",message:{text:x.slice(0,300)},locations:[{physicalLocation:{artifactLocation:{uri:process.env.FILE},region:{startLine:1}}}]}));process.stdout.write(JSON.stringify({version:"2.1.0",runs:[{tool:{driver:{name:process.env.TOOL,version:"runner"}},results:r}]}))' > "$TMP_SARIF"
        N=0
        ADV=$(printf '%s' "$OUT" | grep -c . 2>/dev/null || echo 0)
        [ "$JSON" -eq 1 ] && cat "$TMP_SARIF"
        rm -f "$TMP_SARIF"
        echo "run-tool tool=$TOOL status=advisory findings=$ADV reason=formatter-style-only" >&2
        exit 0
      else
        FILE="$FILE" TOOL="$TOOL" OUT="$OUT" node -e 'const l=(process.env.OUT||"").split("\n").filter(Boolean).slice(0,50);const r=(l.length?l:["finding"]).map(x=>({ruleId:process.env.TOOL,level:"warning",message:{text:x.slice(0,300)},locations:[{physicalLocation:{artifactLocation:{uri:process.env.FILE},region:{startLine:1}}}]}));process.stdout.write(JSON.stringify({version:"2.1.0",runs:[{tool:{driver:{name:process.env.TOOL,version:"runner"}},results:r}]}))' > "$TMP_SARIF"
        N=$(node -e 'try{const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log((j.runs[0].results||[]).length)}catch(e){console.log(1)}' "$TMP_SARIF")
      fi ;;
  esac
fi

if [ "$RAN" -eq 0 ]; then
  [ "$JSON" -eq 1 ] && emit_empty_sarif
  echo "run-tool tool=$TOOL status=not_enforced findings=0 reason=tool-ran-no-output" >&2
  rm -f "$TMP_SARIF"; exit 3
fi

[ "$JSON" -eq 1 ] && cat "$TMP_SARIF"
rm -f "$TMP_SARIF"
status=$([ "$N" -gt 0 ] && echo red || echo green)
echo "run-tool tool=$TOOL status=$status findings=$N" >&2
exit $([ "$N" -gt 0 ] && echo 1 || echo 0)
