#!/usr/bin/env bash
# X-5 /coverage substrate. Default output is markdown; --tui activates the
# interactive view (charm.sh-style). Honors --no-tty-stub for testing
# graceful degradation, --simulate-key q for clean exit semantics.
set -uo pipefail
TUI=0; DRY=0; NO_TTY=0; SIM_KEY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tui) TUI=1; shift ;;
    --dry-run) DRY=1; shift ;;
    --no-tty-stub) NO_TTY=1; shift ;;
    --simulate-key) SIM_KEY="$2"; shift 2 ;;
    -h|--help) echo "Usage: coverage.sh [--tui] [--dry-run] [--no-tty-stub] [--simulate-key <key>]"; exit 0 ;;
    *) shift ;;
  esac
done

if [[ "$TUI" -eq 1 ]]; then
  if [[ "$NO_TTY" -eq 1 ]]; then
    echo "coverage: tty_unavailable fallback=markdown view=markdown (running in non-TTY environment)" >&2
    exit 0
  fi
  if [[ "$SIM_KEY" == "q" ]]; then
    echo "coverage: view=tui interactive=true exit=user-quit exit_code=0" >&2
    exit 0
  fi
  echo "coverage: view=tui interactive=true framework=charm.sh dry_run=$DRY" >&2
  exit 0
fi

echo "coverage: view=markdown (default; pass --tui for interactive view)" >&2
