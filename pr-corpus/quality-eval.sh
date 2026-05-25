#!/usr/bin/env bash
# L-3.5 manual PR-corpus quality-eval gate.
# Reads N hand-graded PRs from --grades-dir, computes precision +
# mean usefulness, and writes a pass/fail gate result that L-10 monitor
# consults before activating. Architecture §12 L-3.5: 20 hand-graded PRs;
# precision >= 0.7 + mean usefulness >= 3/5 required.
set -uo pipefail

GRADES_DIR=""
OUT=""
DRY_RUN=0
NOW=""
INCLUDE_BREAKDOWN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --grades-dir) GRADES_DIR="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --now) NOW="$2"; shift 2 ;;
    --include-breakdown) INCLUDE_BREAKDOWN=1; shift ;;
    -h|--help)
      echo "Usage: quality-eval.sh --grades-dir <dir> --out <json> [--dry-run] [--now <iso>] [--include-breakdown]" >&2
      exit 0
      ;;
    *) shift ;;
  esac
done

[[ -z "$GRADES_DIR" || ! -d "$GRADES_DIR" ]] && { echo "quality-eval: --grades-dir <dir> required" >&2; exit 2; }
[[ -z "$OUT" ]] && { echo "quality-eval: --out <path> required" >&2; exit 2; }
[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

GRADES_DIR="$GRADES_DIR" OUT="$OUT" NOW="$NOW" DRY_RUN="$DRY_RUN" INCLUDE_BREAKDOWN="$INCLUDE_BREAKDOWN" node -e '
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const gradesDir = process.env.GRADES_DIR;
const out = process.env.OUT;
const now = process.env.NOW;
const dryRun = process.env.DRY_RUN === "1";
const includeBreakdown = process.env.INCLUDE_BREAKDOWN === "1";

const REQUIRED_COUNT = 20;
const PRECISION_FLOOR = 0.7;
const USEFULNESS_FLOOR = 3;

const files = fs.readdirSync(gradesDir).filter(f => f.endsWith(".json")).sort();
const grades = [];
for (const f of files) {
  const raw = fs.readFileSync(path.join(gradesDir, f), "utf8");
  let g;
  try { g = JSON.parse(raw); }
  catch (e) { process.stderr.write(`quality-eval: invalid json file=${f}\n`); process.exit(2); }
  grades.push(g);
}

if (grades.length !== REQUIRED_COUNT) {
  process.stderr.write(`quality-eval: graded_count=${grades.length} required=${REQUIRED_COUNT}\n`);
  process.exit(2);
}

for (const g of grades) {
  if (typeof g.usefulness !== "number" || g.usefulness < 1 || g.usefulness > 5) {
    process.stderr.write(`quality-eval: invalid usefulness=${g.usefulness} pr=${g.pr}\n`);
    process.exit(2);
  }
}

const usefulCount = grades.filter(g => g.graded_useful === true).length;
const precision = usefulCount / grades.length;
const meanUsefulness = grades.reduce((a, g) => a + g.usefulness, 0) / grades.length;

const precisionStr = precision.toFixed(2);
const meanStr = meanUsefulness.toFixed(2);

let gateFail = false;
if (precision < PRECISION_FLOOR) {
  process.stderr.write(`quality-eval: gate=fail precision=${precisionStr} required>=${PRECISION_FLOOR.toFixed(2)}\n`);
  gateFail = true;
}
if (meanUsefulness < USEFULNESS_FLOOR) {
  process.stderr.write(`quality-eval: gate=fail mean_usefulness=${meanStr} required>=${USEFULNESS_FLOOR}\n`);
  gateFail = true;
}

if (gateFail) process.exit(2);

const datasetSrc = grades.map(g => JSON.stringify(g)).sort().join("\n");
const datasetHash = crypto.createHash("sha256").update(datasetSrc).digest("hex");

if (dryRun) {
  process.stderr.write(`quality-eval: gate=pass precision=${precisionStr} mean_usefulness=${meanStr} dry_run=true\n`);
  process.exit(0);
}

const result = {
  gate: "pass",
  precision: Number(precisionStr),
  mean_usefulness: Number(meanStr),
  graded_count: grades.length,
  computed_at: now,
  dataset_hash: datasetHash,
};
if (includeBreakdown) {
  result.per_pr = grades.map(g => ({ pr: g.pr, usefulness: g.usefulness, graded_useful: g.graded_useful === true }));
}

fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(out, JSON.stringify(result) + "\n");
process.stderr.write(`quality-eval: gate=pass precision=${precisionStr} mean_usefulness=${meanStr} out=${out}\n`);
'
