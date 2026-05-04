#!/usr/bin/env bash
# Eval runner for claude-tdd-pro plugin.
#
# Usage:
#   bash evals/runner.sh                # all specs
#   bash evals/runner.sh secret         # specs with "secret" in filename
#   bash evals/runner.sh -v             # verbose

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
PLUGIN_ROOT=$(cd "$SCRIPT_DIR/.." && pwd -P)
SPECS_DIR="$SCRIPT_DIR/specs"

VERBOSE=0
FILTER=""
for arg in "$@"; do
  case "$arg" in
    -v|--verbose) VERBOSE=1 ;;
    *) FILTER="$arg" ;;
  esac
done

export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

pass=0
fail=0
failed_specs=()

run_one() {
  local spec_file="$1"
  local spec_name
  spec_name=$(basename "$spec_file" .json)

  if [[ -n "$FILTER" && "$spec_name" != *"$FILTER"* ]]; then
    return 0
  fi

  local workdir
  workdir=$(mktemp -d -t claude-tdd-pro-eval.XXXXXX)

  # Extract command + setup using node
  local command setup
  command=$(node -e '
    const j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    process.stdout.write(j.command || "");
  ' "$spec_file")
  setup=$(node -e '
    const j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    process.stdout.write((j.setup || []).join("\n"));
  ' "$spec_file")

  # Run setup in the workdir
  if [[ -n "$setup" ]]; then
    if ! (cd "$workdir" && bash -c "$setup") >/dev/null 2>&1; then
      echo "  ✗ $spec_name [setup failed]"
      fail=$((fail+1))
      failed_specs+=("$spec_name")
      rm -rf "$workdir"
      return 0
    fi
  fi

  # Run the command. Capture stderr to file, capture exit.
  local stderr_file
  stderr_file="$workdir/__stderr"
  ( cd "$workdir" && bash -c "$command" ) >/dev/null 2>"$stderr_file"
  local actual_exit=$?
  [[ ${VERBOSE:-0} -eq 1 ]] && echo "    [debug] actual_exit=$actual_exit" >&2 || true
  local actual_stderr
  actual_stderr=$(cat "$stderr_file" 2>/dev/null || echo "")

  # Assert via node — pass exit code as env var, stderr as file path
  local assertion
  assertion=$(EXPECTED_EXIT="$actual_exit" STDERR_FILE="$stderr_file" node -e '
    const fs = require("fs");
    const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const ec = parseInt(process.env.EXPECTED_EXIT, 10);
    const stderr = fs.readFileSync(process.env.STDERR_FILE, "utf8");
    const exp = j.expect || {};
    const errors = [];
    if (exp.exit_code !== undefined && exp.exit_code !== ec)
      errors.push(`  exit_code: expected ${exp.exit_code}, got ${ec}`);
    for (const sub of (exp.stderr_contains || []))
      if (!stderr.includes(sub))
        errors.push(`  stderr_contains: missing "${sub}"`);
    for (const sub of (exp.stderr_not_contains || []))
      if (stderr.includes(sub))
        errors.push(`  stderr_not_contains: should not contain "${sub}"`);
    process.stdout.write(errors.length ? "FAIL\n" + errors.join("\n") : "PASS");
  ' "$spec_file")

  if [[ "$assertion" == PASS ]]; then
    echo "  ✓ $spec_name"
    pass=$((pass+1))
  else
    echo "  ✗ $spec_name"
    if [[ $VERBOSE -eq 1 ]]; then
      echo "$assertion" | tail -n +2 | sed 's/^/    /'
      echo "    actual stderr:"
      echo "$actual_stderr" | head -10 | sed 's/^/      | /'
    fi
    fail=$((fail+1))
    failed_specs+=("$spec_name")
  fi

  rm -rf "$workdir"
}

echo "Running claude-tdd-pro evals..."
echo

if [[ ! -d "$SPECS_DIR" ]]; then
  echo "No specs directory at $SPECS_DIR"
  exit 1
fi

for spec in "$SPECS_DIR"/*.json; do
  [[ -e "$spec" ]] || continue
  run_one "$spec"
done

echo
echo "Results: $pass passed, $fail failed"
if [[ $fail -gt 0 ]]; then
  echo "Failed specs:"
  for s in "${failed_specs[@]}"; do echo "  - $s"; done
  exit 1
fi
exit 0
