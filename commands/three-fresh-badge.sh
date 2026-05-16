#!/usr/bin/env bash
# L-23 three-fresh badge calculator. all-fresh requires standards + compliance
# + pr_corpus all to be fresh; otherwise emits not-all-fresh with the per-dim
# status so an operator can see which dimension lapsed.
set -uo pipefail
STATUS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --status) STATUS="$2"; shift 2 ;;
    -h|--help) echo "Usage: three-fresh-badge.sh --status <json>"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$STATUS" || ! -f "$STATUS" ]] && { echo "three-fresh-badge: --status <json> required" >&2; exit 2; }

STATUS="$STATUS" node -e '
const j = JSON.parse(require("fs").readFileSync(process.env.STATUS, "utf8"));
const s = j.standards || "unknown";
const c = j.compliance || "unknown";
const p = j.pr_corpus || "unknown";
const all = s === "fresh" && c === "fresh" && p === "fresh";
process.stderr.write(`three-fresh-badge: badge=${all ? "all-fresh" : "not-all-fresh"} standards=${s} compliance=${c} pr_corpus=${p}\n`);
'
