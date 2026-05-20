#!/usr/bin/env bash
# E-16 /plugin-list — print installed plugins; --show-rules adds namespaced
# rule ids; --show-cost adds per-plugin token cost from cost-stats.json.
set -uo pipefail
SHOW_RULES=0; SHOW_COST=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --show-rules) SHOW_RULES=1; shift ;;
    --show-cost) SHOW_COST=1; shift ;;
    -h|--help) echo "Usage: plugin-list.sh [--show-rules] [--show-cost]"; exit 0 ;;
    *) shift ;;
  esac
done

REG_BASE=".claude-tdd-pro/plugins/registered"
[[ ! -d "$REG_BASE" ]] && { echo "plugin-list: no plugins registered" >&2; exit 0; }

for d in "$REG_BASE"/*/; do
  [[ -d "$d" ]] || continue
  src_file="$d/source.yaml"
  [[ ! -f "$src_file" ]] && continue
  pid=$(grep -E '^plugin_id:' "$src_file" | sed -E 's/plugin_id:[[:space:]]*//')
  repo=$(grep -E '^source_repo:' "$src_file" | sed -E 's/source_repo:[[:space:]]*//')
  echo "plugin-list: plugin_id=$pid source_repo=$repo" >&2
  if [[ "$SHOW_RULES" -eq 1 && -f "$d/rules.txt" ]]; then
    while IFS= read -r rid; do
      [[ -z "$rid" ]] && continue
      echo "plugin-list:   rule: $rid" >&2
    done < "$d/rules.txt"
  fi
  if [[ "$SHOW_COST" -eq 1 && -f "$d/cost-stats.json" ]]; then
    tok=$(node -e "process.stdout.write(String((JSON.parse(require('fs').readFileSync('$d/cost-stats.json','utf8')).tokens||0)))")
    echo "plugin-list:   cost: tokens=$tok" >&2
  fi
done
