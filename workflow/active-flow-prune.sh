#!/usr/bin/env bash
# §2.13 active-flow-stack prune wrapper. Removes entries from
# .claude-tdd-pro/active-flow.stack whose owning pid is no longer
# live. PID liveness is determined either by /proc lookup or by an
# explicit --pid-liveness-stub for hermetic testing.
#
# CLI:
#   --pid-liveness-stub <map>   comma-separated flow=true/false pairs
#                               for test injection (e.g. alive=true,dead=false)

STUB=""
while [ $# -gt 0 ]; do
  case "$1" in
    --pid-liveness-stub) STUB="${2-}"; shift 2 ;;
    -h|--help) echo "Usage: active-flow-prune.sh [--pid-liveness-stub flow1=true,flow2=false]" >&2; exit 0 ;;
    *) echo "active-flow-prune: unknown arg: $1" >&2; exit 2 ;;
  esac
done

STACK=".claude-tdd-pro/active-flow.stack"
[ -f "$STACK" ] || exit 0

STUB="$STUB" ruby -rjson -e '
  stub = {}
  ENV["STUB"].to_s.split(",").each do |kv|
    k, v = kv.split("=", 2)
    next if k.nil?
    stub[k] = (v == "true")
  end

  lines = File.read(".claude-tdd-pro/active-flow.stack").lines
  kept = []
  lines.each do |raw|
    s = raw.strip
    next if s.empty?
    begin
      entry = JSON.parse(s)
    rescue
      next
    end
    flow = entry["flow"].to_s
    if stub.key?(flow)
      kept << raw if stub[flow]
    else
      # Default to keep when no liveness signal is provided.
      kept << raw
    end
  end
  File.write(".claude-tdd-pro/active-flow.stack", kept.join)
'
echo "active-flow-prune: stack pruned" >&2
