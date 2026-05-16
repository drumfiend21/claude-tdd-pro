#!/usr/bin/env bash
# L-12 pr-to-eval-dataset extractor. Parses a unified diff into per-file
# before/after fixture pairs for the P-2 eval-dataset substrate.
set -uo pipefail
DIFF=""; EMIT=""; OUT=""; PATTERN_CATEGORY=""; PR_NUMBER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --diff) DIFF="$2"; shift 2 ;;
    --emit) EMIT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --pattern-category) PATTERN_CATEGORY="$2"; shift 2 ;;
    --pr-number) PR_NUMBER="$2"; shift 2 ;;
    -h|--help) echo "Usage: extract.sh --diff <patch> --emit before|after|dataset --out <file> [--pattern-category <kind>] [--pr-number <n>]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$DIFF" || ! -f "$DIFF" ]] && { echo "extract: --diff <file> required" >&2; exit 2; }
[[ -z "$OUT" ]] && { echo "extract: --out <file> required" >&2; exit 2; }
[[ -z "$EMIT" ]] && { echo "extract: --emit before|after|dataset required" >&2; exit 2; }

DIFF="$DIFF" EMIT="$EMIT" OUT="$OUT" PC="$PATTERN_CATEGORY" PR="$PR_NUMBER" node -e '
const fs = require("fs");
const text = fs.readFileSync(process.env.DIFF, "utf8");
const emit = process.env.EMIT;
const out = process.env.OUT;
const pc = process.env.PC;
const pr = process.env.PR;

const lines = text.split("\n");
const files = [];
let cur = null;
for (let i = 0; i < lines.length; i++) {
  const l = lines[i];
  if (l.startsWith("diff --git ")) {
    if (cur) files.push(cur);
    const m = l.match(/^diff --git a\/(.+?) b\/(.+)$/);
    cur = { headerA: m ? m[1] : "", headerB: m ? m[2] : "", file: m ? m[2] : "", before: [], after: [], binary: false, deleted: false, renamed: false, renamed_from: null, renamed_to: null };
    continue;
  }
  if (!cur) continue;
  if (l.startsWith("Binary files ")) { cur.binary = true; continue; }
  if (l.startsWith("deleted file mode")) { cur.deleted = true; cur.file = cur.headerA; continue; }
  if (l.startsWith("rename from ")) { cur.renamed = true; cur.renamed_from = l.replace("rename from ", "").trim(); continue; }
  if (l.startsWith("rename to ")) { cur.renamed_to = l.replace("rename to ", "").trim(); cur.file = cur.renamed_to; continue; }
  if (l.startsWith("--- ") || l.startsWith("+++ ")) continue;
  if (l.startsWith("@@")) continue;
  if (l.startsWith("-") && !l.startsWith("---")) { cur.before.push(l.slice(1)); continue; }
  if (l.startsWith("+") && !l.startsWith("+++")) { cur.after.push(l.slice(1)); continue; }
  if (l.startsWith(" ")) { cur.before.push(l.slice(1)); cur.after.push(l.slice(1)); continue; }
}
if (cur) files.push(cur);

if (emit === "before") {
  fs.writeFileSync(out, files.map(f => f.before.join("\n")).join("\n") + "\n");
  process.exit(0);
}
if (emit === "after") {
  fs.writeFileSync(out, files.map(f => f.after.join("\n")).join("\n") + "\n");
  process.exit(0);
}
if (emit === "dataset") {
  const records = [];
  for (const f of files) {
    let entry;
    if (f.binary) {
      entry = { file: f.file, skipped: "binary" };
    } else if (f.renamed) {
      entry = { file: f.file, renamed_from: f.renamed_from, renamed_to: f.renamed_to, before: f.before.join("\n"), after: f.after.join("\n") };
    } else if (f.deleted) {
      entry = { file: f.file, before: f.before.join("\n"), after: "", deleted: true };
    } else {
      entry = { file: f.file, before: f.before.join("\n"), after: f.after.join("\n") };
    }
    if (pc) entry.pattern_category = pc;
    if (pr) entry.source_pr = parseInt(pr, 10);
    records.push(JSON.stringify(entry));
  }
  fs.writeFileSync(out, records.join("\n") + "\n");
  process.exit(0);
}
process.stderr.write(`extract: unknown --emit value ${emit}\n`);
process.exit(2);
'
