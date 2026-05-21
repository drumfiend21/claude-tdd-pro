#!/usr/bin/env bash
# P-8 skill-performance report → skills/PERF.md.
set -uo pipefail
OUT=""; STATS=".claude-tdd-pro/skills/perf-stats.yaml"; NOW=""; WINDOW="7d"; DRY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    --stats) STATS="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    --window) WINDOW="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) echo "Usage: perf.sh --out <md> [--stats <yaml>] [--window <Nd>] [--now <iso>] [--dry-run]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$OUT" ]] && { echo "perf: --out <md> required" >&2; exit 2; }
[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

if [[ "$DRY" -eq 1 ]]; then
  echo "perf: planned: write skills/PERF.md to $OUT window=$WINDOW dry_run=true" >&2
  exit 0
fi

mkdir -p "$(dirname "$OUT")"

# Parse yaml stats into structured records via node.
RECORDS=""
if [[ -f "$STATS" ]]; then
  RECORDS=$(STATS="$STATS" node -e '
    const fs = require("fs");
    const body = fs.readFileSync(process.env.STATS, "utf8");
    const lines = body.split("\n");
    const skills = [];
    let cur = null;
    for (const l of lines) {
      const m = l.match(/^([A-Za-z][A-Za-z0-9_-]*):\s*(\{\})?\s*$/);
      if (m) {
        if (cur) skills.push(cur);
        cur = { name: m[1], empty: m[2] === "{}" };
        continue;
      }
      const kv = l.match(/^\s+(\w+):\s*([\d.]+)/);
      if (kv && cur) cur[kv[1]] = kv[2];
    }
    if (cur) skills.push(cur);
    process.stdout.write(JSON.stringify(skills));
  ')
fi

# Aggregate stats.
SKILL_COUNT=$(echo "$RECORDS" | node -e 'let s="";process.stdin.on("data",c=>s+=c);process.stdin.on("end",()=>{const a=JSON.parse(s||"[]");process.stdout.write(String(a.length))})')

{
  echo "# Skill Performance Report"
  echo ""
  echo "generated_at: $NOW"
  echo "window: $WINDOW"
  echo ""
  echo "## aggregate"
  echo "skills_total: ${SKILL_COUNT:-0}"
  echo ""
  if [[ -n "$RECORDS" ]]; then
    echo "$RECORDS" | node -e '
      let s = ""; process.stdin.on("data", c => s += c);
      process.stdin.on("end", () => {
        const a = JSON.parse(s || "[]");
        for (const sk of a) {
          process.stdout.write(`## ${sk.name}\n`);
          if (sk.empty) {
            process.stdout.write("no_data\n");
          } else {
            for (const k of Object.keys(sk)) {
              if (k === "name" || k === "empty") continue;
              process.stdout.write(`${k}: ${sk[k]}\n`);
            }
          }
          process.stdout.write("\n");
        }
      });
    '
  fi
} > "$OUT"
echo "perf: wrote $OUT skills=$SKILL_COUNT window=$WINDOW" >&2
