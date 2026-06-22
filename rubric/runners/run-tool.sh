#!/usr/bin/env bash
# rubric/runners/run-tool.sh — ADR-0008 Wave 2: the per-tool runner layer of the composite
# engine. Invokes one FOSS tool against a file and normalizes its output to SARIF 2.1.0 (the
# §28.29 bus then aggregates across tools).
#
# MISSING-TOOL POLICY (§28.28 operator decision — hard-require):
#   tool present            -> run + emit SARIF; exit 0 (clean) | 1 (findings)
#   tool absent + --required-> HARD-FAIL (blocking); exit 1; SARIF carries a tool-absent error
#   tool absent (optional)  -> not_enforced (never a vacuous green); exit 3
#   usage / unknown tool    -> exit 2
#
# This runner is TOOL-INDEPENDENT for the test suite: the absent paths are deterministic, so the
# eval suite stays green on a fresh (toolless) container; the live path runs opportunistically.
#
# Supported tools (all open-source; GPL/LGPL are invoke-only, never bundled):
#   eslint (MIT) · markdownlint-cli2 (MIT) · cspell (MIT) · checkov (Apache-2.0, native SARIF)
#
# CLI: --tool <name> --file <path> [--required] [--json]
# stderr: `run-tool tool=<t> status=<green|red|not_enforced|hard-fail> findings=<n>`
# Exit: 0 green | 1 red/hard-fail | 3 not_enforced | 2 usage.

set -uo pipefail
TOOL=""; FILE=""; REQUIRED=0; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --tool) TOOL="${2-}"; shift 2 ;;
    --file) FILE="${2-}"; shift 2 ;;
    --required) REQUIRED=1; shift ;;
    --json) JSON=1; shift ;;
    -h|--help) echo "Usage: run-tool.sh --tool <eslint|markdownlint|cspell|checkov> --file <path> [--required] [--json]" >&2; exit 0 ;;
    *) echo "run-tool: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$TOOL" ] && { echo "run-tool: --tool required" >&2; exit 2; }
[ -z "$FILE" ] && { echo "run-tool: --file required" >&2; exit 2; }
[ -f "$FILE" ] || { echo "run-tool: not a file: $FILE" >&2; exit 2; }

# tool name -> binary
case "$TOOL" in
  eslint)       BIN="eslint" ;;
  markdownlint) BIN="markdownlint-cli2" ;;
  cspell)       BIN="cspell" ;;
  checkov)      BIN="checkov" ;;
  *) echo "run-tool: unknown tool: $TOOL" >&2; exit 2 ;;
esac

emit_sarif() { # $1=level $2=message $3=ruleId  -> a one-result SARIF doc (for tool-absent / synthetic)
  FILE="$FILE" LV="$1" MSG="$2" RID="$3" TOOL="$TOOL" node -e '
    const o={version:"2.1.0","$schema":"https://docs.oasis-open.org/sarif/sarif/v2.1.0/errata01/os/schemas/sarif-schema-2.1.0.json",
      runs:[{tool:{driver:{name:process.env.TOOL,version:"runner"}},results:[{ruleId:process.env.RID,level:process.env.LV,
        message:{text:process.env.MSG},locations:[{physicalLocation:{artifactLocation:{uri:process.env.FILE},region:{startLine:1}}}]}]}]};
    process.stdout.write(JSON.stringify(o));'
}
emit_empty_sarif() {
  TOOL="$TOOL" node -e 'process.stdout.write(JSON.stringify({version:"2.1.0",runs:[{tool:{driver:{name:process.env.TOOL,version:"runner"}},results:[]}]}))'
}

# ---- missing-tool policy ------------------------------------------------------------------
# RUN_TOOL_FORCE_ABSENT=1 forces the absent path (test affordance: the eval suite must verify the
# hard-require / not_enforced policy deterministically even when the binary happens to be present).
if [ "${RUN_TOOL_FORCE_ABSENT:-0}" = "1" ] || ! command -v "$BIN" >/dev/null 2>&1; then
  if [ "$REQUIRED" -eq 1 ]; then
    [ "$JSON" -eq 1 ] && emit_sarif "error" "required tool '$TOOL' is not installed (hard-require policy)" "tool-absent"
    echo "run-tool tool=$TOOL status=hard-fail findings=1 reason=required-tool-absent" >&2
    exit 1
  else
    [ "$JSON" -eq 1 ] && emit_empty_sarif
    echo "run-tool tool=$TOOL status=not_enforced findings=0 reason=optional-tool-absent" >&2
    exit 3
  fi
fi

# ---- live path: invoke the tool and normalize to SARIF -----------------------------------
TMP_SARIF="$(mktemp)"; N=0; RAN=1
case "$TOOL" in
  checkov)
    # checkov emits SARIF natively; write to a temp dir and read results.sarif
    OUTDIR="$(mktemp -d)"
    checkov -f "$FILE" -o sarif --output-file-path "$OUTDIR" --quiet >/dev/null 2>&1 || true
    if [ -f "$OUTDIR/results_sarif.sarif" ]; then
      cp "$OUTDIR/results_sarif.sarif" "$TMP_SARIF"
      N=$(node -e 'try{const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log((j.runs||[]).reduce((a,r)=>a+(r.results||[]).length,0))}catch(e){console.log(0)}' "$TMP_SARIF")
    else RAN=0; fi
    rm -rf "$OUTDIR" ;;
  cspell)
    OUT="$(cspell --no-progress --no-summary "$FILE" 2>/dev/null || true)"
    N=$(printf '%s' "$OUT" | grep -c . || true)
    FILE="$FILE" OUT="$OUT" TOOL="$TOOL" node -e '
      const lines=(process.env.OUT||"").split("\n").filter(Boolean);
      const results=lines.map(l=>({ruleId:"cspell-unknown-word",level:"warning",message:{text:l},
        locations:[{physicalLocation:{artifactLocation:{uri:process.env.FILE},region:{startLine:1}}}]}));
      process.stdout.write(JSON.stringify({version:"2.1.0",runs:[{tool:{driver:{name:"cspell",version:"runner"}},results}]}));' > "$TMP_SARIF" ;;
  markdownlint)
    OUT="$(markdownlint-cli2 "$FILE" 2>&1 || true)"
    N=$(printf '%s' "$OUT" | grep -cE "MD[0-9]+/" || true)
    FILE="$FILE" OUT="$OUT" node -e '
      const lines=(process.env.OUT||"").split("\n").filter(l=>/MD\d+\//.test(l));
      const results=lines.map(l=>{const m=l.match(/(MD\d+)/);const ln=l.match(/:(\d+)/);
        return {ruleId:(m?m[1]:"markdownlint"),level:"warning",message:{text:l.trim()},
        locations:[{physicalLocation:{artifactLocation:{uri:process.env.FILE},region:{startLine:(ln?+ln[1]:1)}}}]};});
      process.stdout.write(JSON.stringify({version:"2.1.0",runs:[{tool:{driver:{name:"markdownlint",version:"runner"}},results}]}));' > "$TMP_SARIF" ;;
  eslint)
    OUT="$(eslint --format json "$FILE" 2>/dev/null || true)"
    [ -z "$OUT" ] && RAN=0
    if [ "$RAN" -eq 1 ]; then
      FILE="$FILE" OUT="$OUT" node -e '
        let j; try{j=JSON.parse(process.env.OUT)}catch(e){process.exit(0)}
        const results=[];
        for(const f of j) for(const m of (f.messages||[])) results.push({ruleId:m.ruleId||"eslint",
          level:m.severity===2?"error":"warning",message:{text:m.message},
          locations:[{physicalLocation:{artifactLocation:{uri:process.env.FILE},region:{startLine:m.line||1}}}]});
        process.stdout.write(JSON.stringify({version:"2.1.0",runs:[{tool:{driver:{name:"eslint",version:"runner"}},results}]}));' > "$TMP_SARIF"
      N=$(node -e 'try{const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log((j.runs[0].results||[]).length)}catch(e){console.log(0)}' "$TMP_SARIF")
    fi ;;
esac

if [ "$RAN" -eq 0 ]; then
  # tool present but could not produce a parseable result (e.g. eslint with no config) -> not_enforced
  [ "$JSON" -eq 1 ] && emit_empty_sarif
  echo "run-tool tool=$TOOL status=not_enforced findings=0 reason=tool-ran-no-output" >&2
  rm -f "$TMP_SARIF"; exit 3
fi

[ "$JSON" -eq 1 ] && cat "$TMP_SARIF"
rm -f "$TMP_SARIF"
status=$([ "$N" -gt 0 ] && echo red || echo green)
echo "run-tool tool=$TOOL status=$status findings=$N" >&2
exit $([ "$N" -gt 0 ] && echo 1 || echo 0)
