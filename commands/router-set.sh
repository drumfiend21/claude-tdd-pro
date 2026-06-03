#!/usr/bin/env bash
# P-10 runtime model router per §6. Updates prompts/router.yaml mapping
# for a given task-class → model tier. Supports --dry-run per §2.14.
#
# Usage:
#   commands/router-set.sh --task-class <name> --model <haiku|sonnet|opus>
#                          [--rationale <text>] [--dry-run]
#                          [--emit-audit <jsonl>]
#
# Exit codes:
#   0 — updated (or dry-run plan emitted)
#   2 — usage error

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
ROUTER="$PLUGIN_ROOT/prompts/router.yaml"

TASK_CLASS=""
MODEL=""
RATIONALE=""
DRY_RUN=0
EMIT_AUDIT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-class) TASK_CLASS="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --rationale) RATIONALE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --emit-audit) EMIT_AUDIT="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: router-set.sh --task-class <name> --model <haiku|sonnet|opus> [--rationale <text>] [--dry-run] [--emit-audit <jsonl>]"
      exit 0 ;;
    *) echo "router-set: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$TASK_CLASS" || -z "$MODEL" ]] && { echo "router-set: --task-class + --model required" >&2; exit 2; }

case "$MODEL" in
  haiku|sonnet|opus) : ;;
  *) echo "router-set: --model must be haiku|sonnet|opus (got $MODEL)" >&2; exit 2 ;;
esac

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "router-set: dry-run; would set task_class=$TASK_CLASS model=$MODEL in $ROUTER" >&2
  exit 0
fi

[[ ! -f "$ROUTER" ]] && { echo "router-set: $ROUTER not found" >&2; exit 2; }

TASK_CLASS="$TASK_CLASS" MODEL="$MODEL" RATIONALE="$RATIONALE" ROUTER="$ROUTER" ruby -ryaml -e '
  path = ENV["ROUTER"]
  doc = YAML.unsafe_load_file(path) || {}
  routes = (doc["routes"] || [])
  found = false
  routes.each do |r|
    next unless r.is_a?(Hash)
    if r["task_class"] == ENV["TASK_CLASS"]
      r["model"] = ENV["MODEL"]
      r["rationale"] = ENV["RATIONALE"] unless ENV["RATIONALE"].empty?
      found = true
    end
  end
  unless found
    routes << {"task_class" => ENV["TASK_CLASS"], "model" => ENV["MODEL"], "rationale" => ENV["RATIONALE"]}
  end
  doc["routes"] = routes
  File.write(path, doc.to_yaml.sub(/\A---\n/, ""))
'

echo "router-set: updated $TASK_CLASS -> $MODEL in $ROUTER" >&2

if [[ -n "$EMIT_AUDIT" ]]; then
  mkdir -p "$(dirname "$EMIT_AUDIT")"
  printf '{"action":"router-set","task_class":"%s","model":"%s","ts":"%s"}\n' \
    "$TASK_CLASS" "$MODEL" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$EMIT_AUDIT"
fi
exit 0
