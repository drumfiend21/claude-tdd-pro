#!/usr/bin/env bash
# L-5 two-pass reconciler: pass 1 cosine shortlist over the rule embedding
# space; pass 2 (subagent classification) happens downstream via
# validate-classification.sh + apply-classification.sh. This script is
# the pass-1 narrower. Architecture §12 L-5.
set -uo pipefail

PATTERN=""
RULES_DIR=""
SHORTLIST_K=""
MIN_COSINE=""
EMIT=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pattern) PATTERN="$2"; shift 2 ;;
    --rules-dir) RULES_DIR="$2"; shift 2 ;;
    --shortlist-k) SHORTLIST_K="$2"; shift 2 ;;
    --min-cosine) MIN_COSINE="$2"; shift 2 ;;
    --emit) EMIT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      echo "Usage: reconcile.sh --pattern <json> --rules-dir <dir> [--shortlist-k <N>] [--min-cosine <X>] [--emit shortlist] [--dry-run]" >&2
      exit 0
      ;;
    *) shift ;;
  esac
done

[[ -z "$PATTERN" || ! -f "$PATTERN" ]] && { echo "reconcile: --pattern <json> required" >&2; exit 2; }
[[ -z "$RULES_DIR" || ! -d "$RULES_DIR" ]] && { echo "reconcile: --rules-dir <dir> required" >&2; exit 2; }

PATTERN="$PATTERN" RULES_DIR="$RULES_DIR" SHORTLIST_K="${SHORTLIST_K:-}" MIN_COSINE="${MIN_COSINE:-}" EMIT="${EMIT:-}" node -e '
const fs = require("fs");
const path = require("path");

const pattern = JSON.parse(fs.readFileSync(process.env.PATTERN, "utf8"));
const rulesDir = process.env.RULES_DIR;
const shortlistK = process.env.SHORTLIST_K ? parseInt(process.env.SHORTLIST_K, 10) : null;
const minCosine = process.env.MIN_COSINE ? parseFloat(process.env.MIN_COSINE) : null;
const emit = process.env.EMIT;

if (!Array.isArray(pattern.embedding)) {
  process.stderr.write("reconcile: pattern.embedding must be an array\n");
  process.exit(2);
}

function cosine(a, b) {
  if (a.length !== b.length) return 0;
  let dot = 0, na = 0, nb = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  if (na === 0 || nb === 0) return 0;
  return dot / (Math.sqrt(na) * Math.sqrt(nb));
}

const ruleFiles = fs.readdirSync(rulesDir).filter(f => f.endsWith(".json")).sort();
const scored = [];
for (const f of ruleFiles) {
  const r = JSON.parse(fs.readFileSync(path.join(rulesDir, f), "utf8"));
  if (!Array.isArray(r.embedding)) continue;
  const cos = cosine(pattern.embedding, r.embedding);
  scored.push({ id: r.id, cosine: cos });
}

scored.sort((a, b) => b.cosine - a.cosine);

let shortlist = scored;
if (minCosine !== null) {
  shortlist = shortlist.filter(s => s.cosine >= minCosine);
}
if (shortlistK !== null) {
  shortlist = shortlist.slice(0, shortlistK);
}

process.stderr.write(`reconcile: shortlist_size=${shortlist.length} pattern_id=${pattern.id || ""}\n`);

if (emit === "shortlist") {
  for (const s of shortlist) {
    process.stderr.write(`reconcile: shortlist_item id=${s.id} cosine=${s.cosine.toFixed(4)}\n`);
  }
}
'
