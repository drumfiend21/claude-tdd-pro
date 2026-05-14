#!/usr/bin/env bash
# p2-bootstrap-from-seed — P-2 cold-start helper that copies seed agent
# dataset (O-1 seed corpus) into evals/datasets/agents/<agent>.jsonl so a
# new install has a non-empty eval dataset for each subagent.
#
# Per O-1 architecture: "~30 inputs per review subagent dataset"
# Per P-2 architecture: per-agent dataset at evals/datasets/agents/<agent-name>.jsonl
#
# Usage:
#   bash p2-bootstrap-from-seed.sh --agent <agent-name>

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
AGENT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) AGENT="$2"; shift 2 ;;
    *) echo "p2-bootstrap-from-seed: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$AGENT" ]] && { echo "p2-bootstrap-from-seed: --agent <name> required" >&2; exit 2; }

SEED="$PLUGIN_ROOT/seed/agent-datasets/$AGENT.jsonl"
DEST_DIR="$PWD/evals/datasets/agents"
DEST="$DEST_DIR/$AGENT.jsonl"

[[ ! -f "$SEED" ]] && { echo "p2-bootstrap-from-seed: no seed dataset for agent $AGENT at $SEED" >&2; exit 1; }

mkdir -p "$DEST_DIR"
cp "$SEED" "$DEST"
echo "p2-bootstrap-from-seed: bootstrapped $(wc -l < "$DEST" | tr -d ' ') records into $DEST" >&2
exit 0
