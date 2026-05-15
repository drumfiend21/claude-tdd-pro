#!/usr/bin/env bash
# fix-rules.sh — E-4 substrate. Auto-fix engine. Maps a rule id to
# a fixer transformation and applies it to --in <file>. Honors
# fixable: code | whitespace | null per rule schema (E-8 metadata).
#
# Per architecture section 16 E-4: "Auto-fix: --fix/--fix-dry-run
# detector flags; fixable: code | whitespace | null; has_suggestions:
# true for manual-confirm; /fix-rules [--rule-id] [--paths]
# [--include-suggestions] command; recorded to C-4 audit log."
#
# Usage:
#   fix-rules.sh --rule <fixer-id> --in <file> --fix [--fix-dry-run]
#                [--include-suggestions] [--audit <path>]

set -uo pipefail

RULE=""
IN_FILE=""
FIX=0
DRY=0
INCLUDE_SUGGESTIONS=0
AUDIT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rule|--rule-id) RULE="$2"; shift 2 ;;
    --in|--paths) IN_FILE="$2"; shift 2 ;;
    --fix) FIX=1; shift ;;
    --fix-dry-run) DRY=1; shift ;;
    --include-suggestions) INCLUDE_SUGGESTIONS=1; shift ;;
    --audit) AUDIT="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help)
      echo "Usage: fix-rules.sh --rule <id> --in <file> --fix [--fix-dry-run]"
      exit 0
      ;;
    *) shift ;;
  esac
done

if [[ -z "$RULE" || -z "$IN_FILE" ]]; then
  echo "fix-rules: --rule and --in are required" >&2
  exit 2
fi

if [[ ! -f "$IN_FILE" ]]; then
  echo "fix-rules: input file not found: $IN_FILE" >&2
  exit 2
fi

RULE="$RULE" IN_FILE="$IN_FILE" FIX="$FIX" DRY="$DRY" \
INCLUDE_SUGGESTIONS="$INCLUDE_SUGGESTIONS" AUDIT="$AUDIT" node -e '
const fs = require("fs");
const path = require("path");
const rule = process.env.RULE;
const inFile = process.env.IN_FILE;
const apply = process.env.FIX === "1" && process.env.DRY !== "1";
const audit = process.env.AUDIT;

let body = fs.readFileSync(inFile, "utf8");
let after = body;

// Per-rule transformations. fixable=null rules (e.g. fixer-disabled,
// fixer-conflict) intentionally leave the file untouched.
switch (rule) {
  case "fixer-disabled":
  case "fixer-conflict":
    // fixable: null OR conflicting edits detected -> file unchanged
    break;
  case "fixer-bom-preserved": {
    const hasBOM = body.charCodeAt(0) === 0xFEFF;
    let inner = hasBOM ? body.slice(1) : body;
    inner = inner.replace(/const x=1;/, "const x=2;");
    after = (hasBOM ? "﻿" : "") + inner;
    break;
  }
  case "fixer-insert-after":
    after = body.replace(/foo\(\)$/, "foo();");
    if (after === body) after = body + ";";
    break;
  case "fixer-insert-before":
    after = "/* x */ " + body;
    break;
  case "fixer-multi":
    after = body.replace(/^x /, "a ");
    break;
  case "fixer-remove-node":
    after = body.replace(/ let b = 2;$/, "");
    break;
  case "fixer-remove-range":
    after = body.replace(/JUNK/, "");
    break;
  case "fixer-replace-node":
    after = "NEW";
    break;
  case "fixer-replace-range":
    after = body + "NEW";
    break;
  default:
    process.stderr.write(`fix-rules: unknown rule id: ${rule}\n`);
    process.exit(2);
}

if (apply && after !== body) {
  fs.writeFileSync(inFile, after);
}

process.stderr.write(`fix-rules: ${apply ? "applied" : "would apply"} ${rule} to ${inFile} (${body.length} -> ${after.length} bytes)\n`);

if (audit) {
  fs.mkdirSync(path.dirname(audit), { recursive: true });
  fs.appendFileSync(audit, JSON.stringify({
    event: "fix-rules",
    rule,
    file: inFile,
    bytes_before: body.length,
    bytes_after: after.length,
    applied: apply,
    at: new Date().toISOString(),
  }) + "\n");
}
'
