#!/usr/bin/env bash
# L-16 GitHub issue-tracker extension. Fetches security-labeled issues
# from configured upstream repos and emits pattern records (parses CWE/CVE
# refs, links to fix-PRs, retains closed-not-resolved issues).
set -uo pipefail
SOURCE=""; LABEL="security"; UPSTREAM=""; EMIT=""; OUT=""; DRY=0; SOURCES=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --label) LABEL="$2"; shift 2 ;;
    --upstream-stub) UPSTREAM="$2"; shift 2 ;;
    --emit) EMIT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --sources) SOURCES="$2"; shift 2 ;;
    -h|--help) echo "Usage: issue-tracker.sh --source <id> [--label <name>] [--upstream-stub <jsonl>] [--emit patterns --out <file>] [--sources <yaml>] [--dry-run]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$SOURCE" ]] && { echo "issue-tracker: --source <id> required" >&2; exit 2; }

if [[ -n "$SOURCES" && -f "$SOURCES" ]]; then
  if ! grep -q "$SOURCE" "$SOURCES"; then
    echo "issue-tracker: source_not_configured source=$SOURCE (not present in $SOURCES; add it to issue-sources.yaml first)" >&2
    exit 2
  fi
fi

if [[ "$DRY" -eq 1 ]]; then
  echo "issue-tracker: source=$SOURCE label_filter=$LABEL upstream=${UPSTREAM:-(live)} dry_run=true" >&2
  exit 0
fi

[[ -z "$UPSTREAM" || ! -f "$UPSTREAM" ]] && { echo "issue-tracker: --upstream-stub <jsonl> required (live fetch not yet implemented)" >&2; exit 2; }
[[ -z "$OUT" ]] && { echo "issue-tracker: --out <file> required for --emit" >&2; exit 2; }

UPSTREAM="$UPSTREAM" LABEL="$LABEL" OUT="$OUT" SOURCE="$SOURCE" node -e '
const fs = require("fs");
const lines = fs.readFileSync(process.env.UPSTREAM, "utf8").trim().split("\n").filter(Boolean);
const label = process.env.LABEL;
const records = [];
let matched = 0;

for (const l of lines) {
  let o; try { o = JSON.parse(l); } catch { continue; }
  const labels = o.labels || [];
  if (!labels.includes(label)) continue;
  matched++;
  const body = (o.body || "") + " " + (o.title || "");
  const cveMatch = body.match(/CVE-\d{4}-\d+/);
  const cweMatch = body.match(/CWE-\d+/);
  const rec = {
    number: o.number,
    source: process.env.SOURCE,
    category: "security",
  };
  if (o.state) rec.state = o.state;
  if (o.resolution) rec.resolution = o.resolution;
  if (o.linked_pr) rec.linked_pr = o.linked_pr;
  if (cveMatch) rec.cve = cveMatch[0];
  if (cweMatch) rec.cwe = cweMatch[0];
  records.push(JSON.stringify(rec));
}
fs.writeFileSync(process.env.OUT, records.length ? records.join("\n") + "\n" : "");
process.stderr.write(`issue-tracker: source=${process.env.SOURCE} matched=${matched} written=${records.length}\n`);
'
