#!/usr/bin/env bash
# Q-6 retention sweep — prunes entries older than retention_days from collected.jsonl.
set -uo pipefail
CONFIG=""; NOW=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    -h|--help) echo "Usage: retention-sweep.sh --config <yaml> [--now <iso>]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$CONFIG" || ! -f "$CONFIG" ]] && { echo "retention-sweep: --config required" >&2; exit 2; }
[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

CONFIG="$CONFIG" NOW="$NOW" node -e '
const fs = require("fs");
const yaml = require("fs").readFileSync(process.env.CONFIG, "utf8");
const m = yaml.match(/retention_days:\s*(\d+)/);
const days = m ? parseInt(m[1], 10) : 90;
const cutoff = new Date(process.env.NOW).getTime() - days * 86400 * 1000;
const collected = ".claude-tdd-pro/space/collected.jsonl";
if (!require("fs").existsSync(collected)) { process.stderr.write("retention-sweep: no collected file\n"); process.exit(0); }
const lines = fs.readFileSync(collected, "utf8").trim().split("\n").filter(Boolean);
const kept = [];
let pruned = 0;
for (const l of lines) {
  let r;
  try { r = JSON.parse(l); } catch { kept.push(l); continue; }
  const t = r.at ? new Date(r.at).getTime() : Date.now();
  if (t < cutoff) { pruned++; continue; }
  kept.push(l);
}
fs.writeFileSync(collected, kept.join("\n") + (kept.length ? "\n" : ""));
process.stderr.write(`retention-sweep: pruned=${pruned} kept=${kept.length} retention_days=${days}\n`);
'
