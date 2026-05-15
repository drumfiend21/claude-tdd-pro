#!/usr/bin/env bash
# type-test-coverage.sh — T-3 substrate stub. Detects exported
# functions / types that lack a compile-time type test (test-d.ts
# file or expectTypeOf assertion).
#
# Per §2.2 detector contract: --json, --paths, --dry-run, --help.

set -uo pipefail

JSON=0
PATHS=""
DRY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --paths) PATHS="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help)
      echo "Usage: type-test-coverage.sh --json --paths <glob> [--dry-run]"
      echo "Detector flags: --json --paths --dry-run"
      exit 0
      ;;
    *) shift ;;
  esac
done

if [[ "$DRY" -eq 1 ]]; then
  echo "type-test-coverage: dry-run; would walk $PATHS" >&2
  exit 0
fi

EXPAND_BASE=""
EXPAND_PATTERN=""
EXPAND_RECURSIVE=0
case "$PATHS" in
  *"/**"*)
    EXPAND_BASE="${PATHS%%/\*\*/*}"
    [[ "$EXPAND_BASE" == "$PATHS" ]] && EXPAND_BASE="${PATHS%/\*\*}"
    EXPAND_PATTERN="${PATHS##*/}"
    [[ "$EXPAND_PATTERN" == "**" ]] && EXPAND_PATTERN="*"
    EXPAND_RECURSIVE=1
    ;;
  */*)
    EXPAND_BASE="${PATHS%/*}"
    EXPAND_PATTERN="${PATHS##*/}"
    ;;
  *)
    EXPAND_BASE="."
    EXPAND_PATTERN="$PATHS"
    ;;
esac

[[ -d "$EXPAND_BASE" ]] || exit 0
if [[ "$EXPAND_RECURSIVE" -eq 1 ]]; then
  FIND_DEPTH=""
else
  FIND_DEPTH="-maxdepth 1"
fi

EXIT=0
EXPORT_FILES=$(find "$EXPAND_BASE" $FIND_DEPTH -type f -name "$EXPAND_PATTERN" -print0 2>/dev/null \
  | xargs -0 grep -lE '^export[[:space:]]+(function|class|type|interface|const|async)' 2>/dev/null)

# Single-Node pass: classify each export file (covered if sibling
# test-d exists or file contains expectTypeOf) and emit findings up
# to MAX_REPORT. Replaces the per-file shell loop which was O(n)
# bash forks.
EXPORT_FILES="$EXPORT_FILES" JSON_FLAG="$JSON" MAX_REPORT="50" node -e '
const fs = require("fs");
const path = require("path");
const json = process.env.JSON_FLAG === "1";
const maxReport = parseInt(process.env.MAX_REPORT, 10);
const files = (process.env.EXPORT_FILES || "").split("\n").filter(Boolean);
let reported = 0;
let totalUncovered = 0;
for (const f of files) {
  const ext = path.extname(f);
  const base = f.slice(0, -ext.length);
  const testD = `${base}.test-d${ext}`;
  if (fs.existsSync(testD)) continue;
  let body = "";
  try { body = fs.readFileSync(f, "utf8"); } catch {}
  if (body.includes("expectTypeOf")) continue;
  totalUncovered++;
  if (reported >= maxReport) continue;
  if (json) {
    process.stderr.write(`{"severity":"warn","rule_id":"types/type-test-coverage","file":"${f}","line":1,"finding":"type-test-coverage: exported symbol lacks a test-d type-test or expectTypeOf assertion (google-tsguide §testing)","suggested_fix":"add a sibling test-d.<ext> with expectTypeOf assertions"}\n`);
  } else {
    process.stderr.write(`type-test-coverage: ${f}:1 exported symbol lacks test-d coverage\n`);
  }
  reported++;
}
if (totalUncovered > 0) process.exit(1);
process.exit(0);
'
exit $?
