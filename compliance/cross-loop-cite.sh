#!/usr/bin/env bash
# L-15 emit citations from compliance coverage when evidence comes from a
# pr-corpus learned pattern. Uses regex parsing because Psych rejects
# unquoted `pr-corpus:no-eval` style values inside flow-style arrays.
set -uo pipefail
COVERAGE=""; EMIT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --coverage) COVERAGE="$2"; shift 2 ;;
    --emit) EMIT="$2"; shift 2 ;;
    -h|--help) echo "Usage: cross-loop-cite.sh --coverage <yaml> [--emit citations]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$COVERAGE" || ! -f "$COVERAGE" ]] && { echo "cross-loop-cite: --coverage <yaml> required" >&2; exit 2; }

COVERAGE="$COVERAGE" node -e '
const fs = require("fs");
const text = fs.readFileSync(process.env.COVERAGE, "utf8");
const lines = text.split("\n");
let curControl = null;
for (let i = 0; i < lines.length; i++) {
  const l = lines[i];
  const cidMatch = l.match(/control_id:\s*(\S+)/);
  if (cidMatch) { curControl = cidMatch[1]; continue; }
  const satMatch = l.match(/satisfied_by:\s*\[([^\]]+)\]/);
  if (satMatch && curControl) {
    const items = satMatch[1].split(",").map(s => s.trim());
    for (const item of items) {
      if (item.startsWith("pr-corpus:")) {
        process.stderr.write(`cross-loop-cite: control=${curControl} evidence=${item}\n`);
      }
    }
  }
}
'
