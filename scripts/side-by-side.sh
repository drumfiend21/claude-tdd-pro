#!/usr/bin/env bash
# Side-by-side gate: runs both the bash and Go runners on the same
# spec corpus and diffs their output. Fails CI on divergence.
#
# Per Musk + Fowler's joint review: this is the gate that protects
# the migration from regression while the Go runner reaches parity.
#
# Usage:
#   bash scripts/side-by-side.sh [--filter <name>] [--quiet]
#
# Exit codes:
#   0 — both runners produced identical Results: lines
#   1 — divergence detected
#   2 — Go runner not built (skipped; not a failure)
#   3 — usage error

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
GO_BIN="$PLUGIN_ROOT/bin/tdd-pro-runner"
FILTER=""
QUIET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --filter) FILTER="$2"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    -h|--help)
      echo "Usage: side-by-side.sh [--filter <name>] [--quiet]" >&2
      exit 0 ;;
    *) echo "side-by-side: unknown arg: $1" >&2; exit 3 ;;
  esac
done

if [[ ! -x "$GO_BIN" ]]; then
  echo "side-by-side: Go runner not built at $GO_BIN; skipping (build with: cd runner-go && go build -o ../bin/tdd-pro-runner .)" >&2
  exit 2
fi

bash_args=(evals/runner.sh)
go_args=("$GO_BIN" --specs "$PLUGIN_ROOT/evals/specs")
if [[ -n "$FILTER" ]]; then
  bash_args+=(--filter "$FILTER")
  go_args+=(--filter "$FILTER")
fi

# Extract just the Results: line from each runner.
bash_results=$(bash "${bash_args[@]}" 2>&1 | grep -E "^Results:" | head -1)
go_results=$("${go_args[@]}" 2>&1 | grep -E "^Results:" | head -1)

[[ "$QUIET" -eq 0 ]] && {
  echo "bash: $bash_results" >&2
  echo "go:   $go_results" >&2
}

if [[ "$bash_results" == "$go_results" ]]; then
  echo "side-by-side: PASS — both runners report $bash_results" >&2
  exit 0
fi

echo "side-by-side: DIVERGENCE — bash and Go runners disagree" >&2
echo "  bash: $bash_results" >&2
echo "  go:   $go_results" >&2
exit 1
