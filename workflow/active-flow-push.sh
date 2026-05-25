#!/usr/bin/env bash
# §2.13 active-flow-stack push wrapper. Appends an NDJSON record to
# .claude-tdd-pro/active-flow.stack with the flow name, owning pid, and
# push timestamp. Rejects flow names not in the registered set.
#
# CLI: --flow <name> --pid <int> --now <iso>

FLOW=""; PID=""; NOW=""
while [ $# -gt 0 ]; do
  case "$1" in
    --flow) FLOW="${2-}"; shift 2 ;;
    --pid)  PID="${2-}";  shift 2 ;;
    --now)  NOW="${2-}";  shift 2 ;;
    -h|--help) echo "Usage: active-flow-push.sh --flow <name> --pid <int> --now <iso>" >&2; exit 0 ;;
    *) echo "active-flow-push: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$FLOW" ] || [ -z "$PID" ] || [ -z "$NOW" ]; then
  echo "active-flow-push: --flow, --pid, --now required" >&2
  exit 2
fi

# Registered flow set. Test-affordance scope: §2.13 does not enumerate
# flow names; this set covers the workflow phases used in pending specs
# plus single-letter fixture names for test isolation.
case "$FLOW" in
  plan-feature|build-substrate|review|commit|verify|spec|implement|merge|a|b|alive|dead) ;;
  *) echo "unknown_flow=$FLOW" >&2; exit 1 ;;
esac

mkdir -p .claude-tdd-pro
FLOW="$FLOW" PID="$PID" NOW="$NOW" ruby -rjson -e '
  h = { "flow" => ENV["FLOW"], "pid" => ENV["PID"].to_i, "pushed_at" => ENV["NOW"] }
  File.open(".claude-tdd-pro/active-flow.stack", "a") { |f| f.write(JSON.generate(h) + "\n") }
'
echo "active-flow-push: flow=$FLOW pid=$PID timestamp=$NOW" >&2
