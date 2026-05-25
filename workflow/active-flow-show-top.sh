#!/usr/bin/env bash
# §2.13 active-flow-stack show-top wrapper. Prints the top NDJSON entry
# to stderr WITHOUT modifying the stack. If the stack file does not
# exist, exits 0 silently (lazy-create per §2.13).

STACK=".claude-tdd-pro/active-flow.stack"
if [ ! -f "$STACK" ] || [ ! -s "$STACK" ]; then
  exit 0
fi
tail -n 1 "$STACK" >&2
