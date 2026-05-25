#!/usr/bin/env bash
# §2.13 active-flow-stack pop wrapper. Removes the top NDJSON entry from
# .claude-tdd-pro/active-flow.stack and writes it to stderr. Empty stack
# emits `no_active_flow` and exits 0.

STACK=".claude-tdd-pro/active-flow.stack"

if [ ! -f "$STACK" ] || [ ! -s "$STACK" ]; then
  echo "no_active_flow" >&2
  exit 0
fi

# Last non-empty line is the top of stack.
top=$(tail -n 1 "$STACK")
if [ -z "$top" ]; then
  echo "no_active_flow" >&2
  exit 0
fi

# Pop: write all-but-last back, emit popped entry to stderr.
ruby -rjson -e '
  lines = File.read(".claude-tdd-pro/active-flow.stack").lines.reject { |l| l.strip.empty? }
  top = lines.pop
  File.write(".claude-tdd-pro/active-flow.stack", lines.join)
  STDERR.write(top.strip + "\n")
'
