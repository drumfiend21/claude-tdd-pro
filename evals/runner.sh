#!/usr/bin/env bash
# Eval runner for claude-tdd-pro plugin.
#
# Usage:
#   bash evals/runner.sh                # all specs
#   bash evals/runner.sh secret         # specs with "secret" in filename
#   bash evals/runner.sh -v             # verbose
#
# Optimization (functionally equivalent — identical output, exit codes, and
# semantics as the prior serial runner; only effect is faster wall time):
#   EVAL_WORKERS=<N>                    parallel worker count (default: nproc, max 16)
#   --no-cache                          disable spec-result cache for this run
#   --no-parallel                       disable parallel workers (force serial)
#   Cache lives at .claude-tdd-pro/eval-cache/<sha>.passed and is keyed on
#   sha256(spec_content + substrate_tree_hash + runner_sha). Failures never
#   cache. Verbose mode (-v) always runs fresh (bypasses cache). The
#   substrate hash invalidates the entire cache on any change under
#   rubric/, commands/, agents/, skills/, hooks/, profiles/, schemas/,
#   compliance/, generated-code-quality-standards/, templates/, scripts/,
#   space/, seed/, migrations/, standards/, design-tokens/, prompts/,
#   pr-corpus/, lsp/, scaffolds/, vscode-tdd-pro/.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
PLUGIN_ROOT=$(cd "$SCRIPT_DIR/.." && pwd -P)
SPECS_DIR="$SCRIPT_DIR/specs"

# ------------------------------------------------------------------------
# Worker mode (invoked recursively by main mode via xargs).
# Receives one spec path on the command line; reads OUTDIR + CACHE_DIR
# + USE_CACHE + VERBOSE + RUNNER_SHA + TREE_SHA from environment.
# Writes:
#   $OUTDIR/<name>.out      stdout content (✓ or ✗ + verbose details)
#   $OUTDIR/<name>.err      stderr content (debug lines, only when VERBOSE=1)
#   $OUTDIR/<name>.status   one of: PASS | FAIL
#   $OUTDIR/<name>.cachekey the computed cache key (for post-run touch)
# ------------------------------------------------------------------------
if [[ "${1-}" == "--__worker" ]]; then
  shift
  spec_file="$1"
  spec_name=$(basename "$spec_file" .json)
  out="$OUTDIR/$spec_name.out"
  err="$OUTDIR/$spec_name.err"
  status_file="$OUTDIR/$spec_name.status"
  keyfile="$OUTDIR/$spec_name.cachekey"
  : > "$out"
  : > "$err"

  # Compute cache key (only when caching enabled). §28.53: key on the spec's own dependency-closure
  # hash (scoped) rather than the whole-tree hash, falling back to TREE_SHA when the spec has no
  # resolvable substrate reference ("GLOBAL") or the dep map is unavailable.
  if [[ "$USE_CACHE" == "1" ]]; then
    # Prefer the prepass-computed key (O(1) cat). Fall back to recomputing with the whole-tree hash
    # when the dep map is unavailable.
    cache_key=""
    [[ -n "${DEPMAP:-}" && -f "${DEPMAP:-}/$spec_name" ]] && cache_key=$(cat "$DEPMAP/$spec_name" 2>/dev/null)
    if [[ -z "$cache_key" || "$cache_key" == "GLOBAL" ]]; then
      spec_sha=$(sha256sum "$spec_file" | cut -d' ' -f1)
      cache_key=$(printf '%s\n%s\n%s\n' "$spec_sha" "$TREE_SHA" "$RUNNER_SHA" | sha256sum | cut -d' ' -f1)
    fi
    echo "$cache_key" > "$keyfile"
    marker="$CACHE_DIR/$cache_key.passed"
    if [[ -f "$marker" ]]; then
      echo "  ✓ $spec_name" > "$out"
      echo "PASS" > "$status_file"
      : > "$OUTDIR/$spec_name.cachehit"
      exit 0
    fi
  fi

  workdir=$(mktemp -d -t claude-tdd-pro-eval.XXXXXX)

  # Extract command + setup using node
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
      echo "  ✗ $spec_name [setup failed]" > "$out"
      echo "FAIL" > "$status_file"
      rm -rf "$workdir"
      exit 0
    fi
  fi

  # Run the command. Capture stderr to file, capture exit.
  stderr_file="$workdir/__stderr"
  ( cd "$workdir" && bash -c "$command" ) >/dev/null 2>"$stderr_file"
  actual_exit=$?
  if [[ "${VERBOSE:-0}" -eq 1 ]]; then
    echo "    [debug] actual_exit=$actual_exit" >> "$err"
  fi
  actual_stderr=$(cat "$stderr_file" 2>/dev/null || echo "")

  # Assert via node — pass exit code as env var, stderr as file path
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
    echo "  ✓ $spec_name" >> "$out"
    echo "PASS" > "$status_file"
  else
    echo "  ✗ $spec_name" >> "$out"
    if [[ ${VERBOSE:-0} -eq 1 ]]; then
      echo "$assertion" | tail -n +2 | sed 's/^/    /' >> "$out"
      echo "    actual stderr:" >> "$out"
      echo "$actual_stderr" | head -10 | sed 's/^/      | /' >> "$out"
    fi
    echo "FAIL" > "$status_file"
  fi

  rm -rf "$workdir"
  exit 0
fi

# ------------------------------------------------------------------------
# Main mode — flag parsing, queue build, parallel dispatch, aggregation.
# ------------------------------------------------------------------------

VERBOSE=0
FILTER=""
TESTS_DIR=""
FEATURE=""
INCLUDE_DIR=""
LIST_ONLY=0
NO_CACHE=0
NO_PARALLEL=0
EMIT_STATS=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--verbose) VERBOSE=1; shift ;;
    --tests-dir) TESTS_DIR="$2"; shift 2 ;;
    --feature) FEATURE="$2"; shift 2 ;;
    --include) INCLUDE_DIR="$2"; shift 2 ;;
    --list) LIST_ONLY=1; shift ;;
    --no-cache) NO_CACHE=1; shift ;;
    --no-parallel) NO_PARALLEL=1; shift ;;
    --stats) EMIT_STATS=1; shift ;;
    *) FILTER="$1"; shift ;;
  esac
done

# W-9 --include <dir> --list mode: list spec/test files under the included
# directory (used by ui-regression-pinner to verify e2e specs joined suite).
if [[ -n "$INCLUDE_DIR" && "$LIST_ONLY" -eq 1 ]]; then
  find "$INCLUDE_DIR" -type f \( -name "*.spec.ts" -o -name "*.test.ts" -o -name "*.json" \) >&2 2>/dev/null
  exit 0
fi

# W-7 --tests-dir + --feature mode: count red tests for a specific feature
# and surface the red state. Tests under tests-dir are expected to fail.
if [[ -n "$TESTS_DIR" ]]; then
  RED_COUNT=$(find "$TESTS_DIR" -name "*.test.*" -type f 2>/dev/null | wc -l | tr -d ' ')
  echo "red_tests=$RED_COUNT feature=$FEATURE tests_dir=$TESTS_DIR" >&2
  [[ "$RED_COUNT" -gt 0 ]] && exit 1
  exit 0
fi

export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

# Hermetic git config for spec setups: disable any host-level commit signing
# (cloud sandboxes that set commit.gpgsign=true with a remote signing server
# fail when test setups run `git commit` inside the tmpdir). These vars are
# treated like `-c` flags by git and win over ~/.gitconfig / /etc/gitconfig.
# Note: do NOT override user.name/user.email here -- specs that assert author
# attribution set those via `git config` in their own setup arrays and must
# remain authoritative.
export GIT_CONFIG_COUNT=2
export GIT_CONFIG_KEY_0=commit.gpgsign;   export GIT_CONFIG_VALUE_0=false
export GIT_CONFIG_KEY_1=tag.gpgsign;      export GIT_CONFIG_VALUE_1=false

echo "Running claude-tdd-pro evals..."
echo

if [[ ! -d "$SPECS_DIR" ]]; then
  echo "No specs directory at $SPECS_DIR"
  exit 1
fi

# Build spec list (apply FILTER once; workers don't repeat the check).
specs=()
for spec in "$SPECS_DIR"/*.json; do
  [[ -e "$spec" ]] || continue
  name=$(basename "$spec" .json)
  if [[ -n "$FILTER" && "$name" != *"$FILTER"* ]]; then
    continue
  fi
  specs+=("$spec")
done

if [[ ${#specs[@]} -eq 0 ]]; then
  echo
  echo "Results: 0 passed, 0 failed"
  exit 0
fi

# Cache config — disabled by --no-cache or by -v (verbose runs fresh so
# debug output is always real).
USE_CACHE=1
[[ "$NO_CACHE" -eq 1 ]] && USE_CACHE=0
[[ "$VERBOSE" -eq 1 ]] && USE_CACHE=0
CACHE_DIR="$PLUGIN_ROOT/.claude-tdd-pro/eval-cache"
if [[ "$USE_CACHE" -eq 1 ]]; then
  mkdir -p "$CACHE_DIR" 2>/dev/null || USE_CACHE=0
fi

# Compute substrate tree hash once (invalidates entire cache on any change
# under the substrate paths). Paths are pinned to those that specs invoke;
# user-data dirs (.claude-tdd-pro, .git, node_modules, evals) excluded.
TREE_SHA="no-cache"
if [[ "$USE_CACHE" -eq 1 ]]; then
  # Hash git-TRACKED substrate only (respects .gitignore) so generated/ignored ledgers rewritten
  # every run (e.g. standards/universal-coverage-ledger.jsonl) don't churn the hash and defeat the
  # cache. Falls back to find if git is unavailable.
  TREE_SHA=$(cd "$PLUGIN_ROOT" && { git ls-files -z -- \
      rubric commands agents skills hooks profiles schemas compliance \
      generated-code-quality-standards templates scripts space seed \
      migrations standards design-tokens prompts pr-corpus lsp scaffolds \
      vscode-tdd-pro community community-shared 2>/dev/null \
      || find rubric commands agents skills hooks profiles schemas compliance \
         generated-code-quality-standards templates scripts space seed migrations \
         standards design-tokens prompts pr-corpus lsp scaffolds vscode-tdd-pro \
         community community-shared -type f -print0 2>/dev/null; } \
    | LC_ALL=C sort -z \
    | xargs -0 sha256sum 2>/dev/null \
    | sha256sum | cut -d' ' -f1)
fi
RUNNER_SHA=$(cat "${BASH_SOURCE[0]}" "$SCRIPT_DIR/dep-hash.js" 2>/dev/null | sha256sum | cut -d' ' -f1)

# §28.53 scoped cache: compute a per-spec dependency hash over the TRANSITIVE substrate closure each
# spec exercises. A unit test stays cached unless a function it (transitively) tests changes; an
# integration test (broad closure) invalidates widely. Specs with no resolvable substrate ref get
# "GLOBAL" and fall back to TREE_SHA below (conservative). Failure to build the map => TREE_SHA for all.
DEPMAP=""
if [[ "$USE_CACHE" -eq 1 ]]; then
  DEPMAP=$(mktemp -d -t claude-tdd-pro-depmap.XXXXXX 2>/dev/null || echo "")
  if [[ -n "$DEPMAP" ]]; then
    # Pass the cache args so the prepass also computes the exact per-spec cache KEY and pre-marks
    # already-passing specs (<name>.hit) -> the runner skips them without spawning a worker.
    node "$SCRIPT_DIR/dep-hash.js" "$PLUGIN_ROOT" "$SPECS_DIR" "$DEPMAP" "$RUNNER_SHA" "$TREE_SHA" "$CACHE_DIR" 2>/dev/null || DEPMAP=""
  fi
fi

# Worker count
if [[ "$NO_PARALLEL" -eq 1 ]]; then
  WORKERS=1
else
  WORKERS=${EVAL_WORKERS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}
  # Cap to avoid runaway on huge cores
  [[ "$WORKERS" -gt 16 ]] && WORKERS=16

# Cost / timeout gates (per Musk-leadership review: "Parallel subagents
# and review panels can explode token usage. Add cost/timeout gates.")
#
#   CLAUDE_TDD_PRO_COST_LIMIT_USD=N    aborts run when summed
#                                       telemetry-emitted token cost
#                                       exceeds N USD (best-effort;
#                                       depends on operator wiring
#                                       cost into telemetry events).
#   CLAUDE_TDD_PRO_WALL_TIMEOUT_S=N    aborts run when wall-clock
#                                       exceeds N seconds (per-suite).
#   CLAUDE_TDD_PRO_PER_SPEC_TIMEOUT_S  aborts a single spec invocation
#                                       when it exceeds N seconds
#                                       (defaults to 10).
PER_SPEC_TIMEOUT="${CLAUDE_TDD_PRO_PER_SPEC_TIMEOUT_S:-10}"
WALL_TIMEOUT="${CLAUDE_TDD_PRO_WALL_TIMEOUT_S:-0}"  # 0 = no wall cap
COST_LIMIT="${CLAUDE_TDD_PRO_COST_LIMIT_USD:-0}"     # 0 = no cost cap
if [[ "$WALL_TIMEOUT" -gt 0 ]]; then
  ( sleep "$WALL_TIMEOUT" && kill -TERM $$ 2>/dev/null ) &
  WALL_TIMEOUT_WATCHDOG_PID=$!
  trap "kill -9 $WALL_TIMEOUT_WATCHDOG_PID 2>/dev/null" EXIT
fi
fi

OUTDIR=$(mktemp -d -t claude-tdd-pro-runner.XXXXXX)
trap 'rm -rf "$OUTDIR" "${DEPMAP:-}"' EXIT

export OUTDIR CACHE_DIR USE_CACHE VERBOSE RUNNER_SHA TREE_SHA DEPMAP

# Partition specs into parallel-safe vs timing-sensitive.
# Timing-sensitive specs (those that assert wall-time bounds via `date +%s`
# or `time `) must run serially with full CPU; under parallel load CPU
# contention pushes their measured durations over their thresholds and
# they false-fail. Detection is content-based (no schema change needed).
parallel_specs=()
serial_specs=()
cached_n=0
for spec in "${specs[@]}"; do
  name=$(basename "$spec" .json)
  # §28.53: a spec the prepass already found cached (<name>.hit) is tallied as PASS WITHOUT spawning
  # a worker — this is what makes a warm full-suite run fast (no per-spec subprocess for cache hits).
  if [[ "$USE_CACHE" == "1" && -n "${DEPMAP:-}" && -f "$DEPMAP/$name.hit" ]]; then
    echo "  ✓ $name" > "$OUTDIR/$name.out"
    echo "PASS" > "$OUTDIR/$name.status"
    : > "$OUTDIR/$name.cachehit"
    cached_n=$((cached_n+1))
    continue
  fi
  # Detect timing-sensitive specs: those using `date +%s` for epoch
  # arithmetic to assert a wall-time bound on a substrate call. These
  # must run with full CPU; under parallel contention they false-fail.
  # `\btime` is intentionally NOT a trigger — it would match "generation-time"
  # in spec names (false positive); no real spec uses the `time` command
  # for assertions today.
  if grep -qF 'date +%s' "$spec" 2>/dev/null; then
    serial_specs+=("$spec")
  else
    parallel_specs+=("$spec")
  fi
done

# Phase 1: parallel dispatch over the parallel-safe set.
if [[ ${#parallel_specs[@]} -gt 0 ]]; then
  printf '%s\n' "${parallel_specs[@]}" \
    | xargs -d '\n' -n 1 -P "$WORKERS" -I {} bash "${BASH_SOURCE[0]}" --__worker {} \
    2>/dev/null
fi

# Phase 2: serial dispatch over the timing-sensitive set so each spec
# gets full CPU when measuring its own wall time.
for spec in "${serial_specs[@]}"; do
  bash "${BASH_SOURCE[0]}" --__worker "$spec" 2>/dev/null
done

# Aggregate in spec-order so the user-visible output is identical to the
# serial runner. Verbose debug lines (written to .err by workers) emit to
# stderr; pass/fail lines (written to .out) emit to stdout.
pass=0
fail=0
failed_specs=()
for spec in "${specs[@]}"; do
  name=$(basename "$spec" .json)
  if [[ -s "$OUTDIR/$name.err" ]]; then
    cat "$OUTDIR/$name.err" >&2
  fi
  if [[ -f "$OUTDIR/$name.out" ]]; then
    cat "$OUTDIR/$name.out"
  fi
  if [[ -f "$OUTDIR/$name.status" ]]; then
    s=$(cat "$OUTDIR/$name.status")
    if [[ "$s" == PASS ]]; then
      pass=$((pass+1))
      # On pass, touch the cache marker (if caching enabled and key present).
      if [[ "$USE_CACHE" -eq 1 && -s "$OUTDIR/$name.cachekey" ]]; then
        key=$(cat "$OUTDIR/$name.cachekey")
        : > "$CACHE_DIR/$key.passed" 2>/dev/null || true
      fi
    else
      fail=$((fail+1))
      failed_specs+=("$name")
    fi
  fi
done

echo
echo "Results: $pass passed, $fail failed"

# Production telemetry: emit a structured event on every suite run.
# Honors Q-6 privacy posture (local-only when share: never).
# Best-effort; never blocks the runner or affects exit code.
if [[ -x "${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}/space/telemetry-emit.sh" ]]; then
  "${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}/space/telemetry-emit.sh" \
    --event "suite.run" \
    --severity "$( [[ $fail -eq 0 ]] && echo info || echo error )" \
    --field "passed=$pass" \
    --field "failed=$fail" \
    --field "filter=${FILTER:-all}" \
    2>/dev/null || true
fi

# --stats: emit a single structured line for instrumentation. Opt-in so
# default output stays bit-identical to a baseline serial run.
if [[ "$EMIT_STATS" -eq 1 ]]; then
  cache_hits=$(ls "$OUTDIR"/*.cachehit 2>/dev/null | wc -l | tr -d ' ')
  cache_misses=$((pass + fail - cache_hits))
  tree_short=${TREE_SHA:0:12}
  echo "STATS: workers=$WORKERS parallel_specs=${#parallel_specs[@]} serial_specs=${#serial_specs[@]} cache=$USE_CACHE cache_hits=$cache_hits cache_misses=$cache_misses tree_sha=$tree_short"
fi

if [[ $fail -gt 0 ]]; then
  echo "Failed specs:"
  for s in "${failed_specs[@]}"; do echo "  - $s"; done
  exit 1
fi
exit 0
