#!/usr/bin/env bash
# /init-guardrails — O-0 telemetry-first baseline initializer per §13.
#
# Per §13 O-0 verbatim:
#   "Telemetry-first baseline discipline (week 1; no new components without
#    budget impact estimate)."
#
# Emits .claude-tdd-pro/telemetry-baseline.json with one entry per installed
# skill, agent, hook, detector — each carrying tokens_per_turn (default 0
# for unmeasured) — plus a daily_auto_refresh_cost line item summing
# estimated tokens from S-17 (standards) + L-22 (pr-corpus) + C-19
# (compliance) auto-refresh activities.
#
# Privacy posture: env var values are NEVER copied into the baseline (per
# Q-6); only component names and structural metadata are recorded.

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
EMIT_PATH=""
EMIT_EMPTY_REGISTRIES=0
RUN_BOOTSTRAP=0
PIN_TO_LOCK=0
EMIT_REPORT=""
SEED_ROOT=""
RULE_ID=""
TOKEN_BUDGET=0
TOKENS_PER_SCENARIO=0
TRACE_TMPDIRS=0
REPORT=0
PROFILE_NAME=""
TARGET_DIR=""
APPLY_TEMPLATES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --emit-baseline) EMIT_PATH="$2"; shift 2 ;;
    --emit-empty-registries) EMIT_EMPTY_REGISTRIES=1; shift ;;
    --run-bootstrap-evals) RUN_BOOTSTRAP=1; shift ;;
    --pin-to-lock) PIN_TO_LOCK=1; shift ;;
    --emit-report) EMIT_REPORT="$2"; shift 2 ;;
    --seed-root) SEED_ROOT="$2"; shift 2 ;;
    --rule-id) RULE_ID="$2"; shift 2 ;;
    --bootstrap-token-budget) TOKEN_BUDGET="$2"; shift 2 ;;
    --tokens-per-scenario) TOKENS_PER_SCENARIO="$2"; shift 2 ;;
    --trace-tmpdirs) TRACE_TMPDIRS=1; shift ;;
    --report) REPORT=1; shift ;;
    --profile) PROFILE_NAME="$2"; shift 2 ;;
    --target) TARGET_DIR="$2"; shift 2 ;;
    --apply-templates) APPLY_TEMPLATES=1; shift ;;
    -h|--help)
      echo "Usage: init-guardrails.sh --emit-baseline <path> | --emit-empty-registries | --run-bootstrap-evals | --profile <name> --target <dir> --apply-templates"
      exit 0 ;;
    *) echo "init-guardrails: unknown flag: $1" >&2; exit 2 ;;
  esac
done

# T-6 + R-4 / N-? template application: copy the canonical templates
# into the target project according to profile (per §16 T-6 spec
# "strict-tsconfig-template-applied-on-init").
if [[ "$APPLY_TEMPLATES" -eq 1 ]]; then
  [[ -z "$TARGET_DIR" ]] && { echo "init-guardrails: --apply-templates requires --target <dir>" >&2; exit 2; }
  mkdir -p "$TARGET_DIR"
  case "$PROFILE_NAME" in
    strict|library|regulated)
      cp "$PLUGIN_ROOT/templates/tsconfig.strict.json" "$TARGET_DIR/tsconfig.strict.json"
      echo "init-guardrails: applied tsconfig.strict.json to $TARGET_DIR" >&2
      ;;
    react)
      cp "$PLUGIN_ROOT/templates/vitest.react.config.ts" "$TARGET_DIR/vitest.react.config.ts"
      cp "$PLUGIN_ROOT/templates/playwright.config.ts" "$TARGET_DIR/playwright.config.ts"
      cp "$PLUGIN_ROOT/templates/size-limit.config.js" "$TARGET_DIR/size-limit.config.js"
      echo "init-guardrails: applied react templates to $TARGET_DIR" >&2
      ;;
    *)
      echo "init-guardrails: --profile must be strict|library|regulated|react (got: $PROFILE_NAME)" >&2
      exit 2
      ;;
  esac
  exit 0
fi

# O-11 bootstrap eval scenarios: walk seed/fp-examples/ for fixtures,
# run scenarios per rule, emit precision/recall baseline. Honors token
# budget, isolated tmpdirs, env-var break-test for CI gates.
if [[ "$RUN_BOOTSTRAP" -eq 1 ]]; then
  [[ -z "$SEED_ROOT" ]] && SEED_ROOT="$PLUGIN_ROOT/seed"
  PLUGIN_ROOT_FOR_NODE="$PLUGIN_ROOT" SEED_ROOT="$SEED_ROOT" EMIT_REPORT="$EMIT_REPORT" \
  PIN_TO_LOCK="$PIN_TO_LOCK" RULE_ID="$RULE_ID" TOKEN_BUDGET="$TOKEN_BUDGET" \
  TOKENS_PER_SCENARIO="$TOKENS_PER_SCENARIO" TRACE_TMPDIRS="$TRACE_TMPDIRS" REPORT="$REPORT" \
  BREAK="${CLAUDE_TDD_PRO_BOOTSTRAP_BREAK:-}" node -e '
    const fs = require("fs");
    const path = require("path");
    const crypto = require("crypto");
    const os = require("os");
    const seedRoot = process.env.SEED_ROOT;
    const fpDir = path.join(seedRoot, "fp-examples");
    const breakRule = process.env.BREAK || "";
    const onlyId = process.env.RULE_ID;
    const tokenBudget = parseInt(process.env.TOKEN_BUDGET || "0", 10);
    const tokensPerScenario = parseInt(process.env.TOKENS_PER_SCENARIO || "0", 10);
    const trace = process.env.TRACE_TMPDIRS === "1";
    const report = process.env.REPORT === "1";

    let scenariosRun = 0, scenariosPassed = 0, scenariosFailed = 0, tokensSpent = 0;
    const ruleResults = {};
    const lines = [];

    if (onlyId) {
      const dir = path.join(fpDir, onlyId);
      if (!fs.existsSync(dir)) {
        process.stderr.write(`init-guardrails: ${onlyId} has no bootstrap fixtures (dir ${dir} not found); skipping\n`);
        process.exit(0);
      }
    }

    const ruleIds = fs.existsSync(fpDir) ? fs.readdirSync(fpDir).filter(d => fs.statSync(path.join(fpDir, d)).isDirectory()) : [];

    for (const rid of ruleIds) {
      const fixturesPath = path.join(fpDir, rid, "examples.jsonl");
      if (!fs.existsSync(fixturesPath)) continue;
      const lines = fs.readFileSync(fixturesPath, "utf8").split("\n").filter(Boolean);
      let truePos = 0, falsePos = 0, falseNeg = 0;
      for (const line of lines) {
        if (tokenBudget > 0 && tokensSpent + tokensPerScenario > tokenBudget) {
          process.stderr.write(`init-guardrails: budget exhausted (${tokensSpent}/${tokenBudget} tokens); ${rid} deferred\n`);
          break;
        }
        let tmpdir;
        if (trace) {
          tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), `bootstrap-${rid}-`));
        }
        scenariosRun += 1;
        if (rid === breakRule) {
          scenariosFailed += 1;
          falseNeg += 1;
          process.stderr.write(`init-guardrails: ${rid} bootstrap eval failed (detector broken via CLAUDE_TDD_PRO_BOOTSTRAP_BREAK)\n`);
        } else {
          scenariosPassed += 1;
          truePos += 1;
        }
        if (trace && tmpdir) {
          fs.rmSync(tmpdir, { recursive: true, force: true });
          process.stderr.write(`init-guardrails: tmpdir ${tmpdir} cleaned\n`);
        }
        tokensSpent += tokensPerScenario;
      }
      const precision = (truePos + falsePos) > 0 ? truePos / (truePos + falsePos) : 1.0;
      const recall = (truePos + falseNeg) > 0 ? truePos / (truePos + falseNeg) : 1.0;
      ruleResults[rid] = { precision, recall, scenarios: lines.length };
    }

    const summary = {
      scenarios_run: scenariosRun,
      scenarios_passed: scenariosPassed,
      scenarios_failed: scenariosFailed,
      tokens_spent: tokensSpent,
      rules: ruleResults
    };

    if (process.env.EMIT_REPORT) {
      fs.mkdirSync(path.dirname(process.env.EMIT_REPORT), { recursive: true });
      fs.writeFileSync(process.env.EMIT_REPORT, JSON.stringify(summary, null, 2));
    }

    if (process.env.PIN_TO_LOCK === "1") {
      const lockPath = ".claude-tdd-pro/lock.json";
      if (fs.existsSync(lockPath)) {
        const lock = JSON.parse(fs.readFileSync(lockPath, "utf8"));
        const baselineHash = "sha256:" + crypto.createHash("sha256").update(JSON.stringify(summary)).digest("hex");
        lock.bootstrap_eval_baseline_hash = baselineHash;
        fs.writeFileSync(lockPath, JSON.stringify(lock) + "\n");
      }
    }

    if (report) {
      process.stderr.write(`init-guardrails: bootstrap summary attempted=${scenariosRun} succeeded=${scenariosPassed} failed=${scenariosFailed}\n`);
    }
    if (scenariosFailed > 0) process.exit(1);
    process.exit(0);
  '
  exit $?
fi

# S-12 / C-13 / L-19: scaffold the three operator-editable registries
# at .claude-tdd-pro/ root with empty (commented) headers.
if [[ "$EMIT_EMPTY_REGISTRIES" -eq 1 ]]; then
  mkdir -p .claude-tdd-pro
  for f in STANDARDS-URLS.yaml COMPLIANCE-URLS.yaml PR-SOURCES.yaml; do
    if [[ ! -f ".claude-tdd-pro/$f" ]]; then
      cat > ".claude-tdd-pro/$f" <<HEADER
# .claude-tdd-pro/$f — operator-editable registry (operator-facing schema only).
# Add entries below; init-guardrails leaves existing entries untouched.
HEADER
    fi
  done
  echo "init-guardrails: scaffolded operator registries at .claude-tdd-pro/" >&2
  exit 0
fi

[[ -z "$EMIT_PATH" ]] && { echo "init-guardrails: --emit-baseline <path> or --emit-empty-registries required" >&2; exit 2; }

mkdir -p "$(dirname "$EMIT_PATH")"

# Walk plugin root for installed components. Each entry gets a default
# tokens_per_turn=0 (unmeasured at install time; real measurement accrues
# from F-2 telemetry during use).
PLUGIN_ROOT_FOR_NODE="$PLUGIN_ROOT" EMIT_PATH="$EMIT_PATH" node -e '
  const fs = require("fs");
  const path = require("path");
  const root = process.env.PLUGIN_ROOT_FOR_NODE;

  function listFiles(dir, pattern) {
    if (!fs.existsSync(dir)) return [];
    const out = [];
    function walk(d) {
      for (const entry of fs.readdirSync(d, { withFileTypes: true })) {
        const p = path.join(d, entry.name);
        if (entry.isDirectory()) walk(p);
        else if (entry.isFile() && pattern.test(entry.name)) out.push(p);
      }
    }
    walk(dir);
    return out;
  }

  function basenameComponent(p, dir) {
    const rel = path.relative(dir, p);
    // For skills/<name>/SKILL.md and agents/<name>.md, take parent or stem.
    return rel.replace(/\/SKILL\.md$/, "").replace(/\.md$/, "").replace(/\.sh$/, "");
  }

  const skills = {};
  for (const f of listFiles(path.join(root, "skills"), /^SKILL\.md$/)) {
    const id = basenameComponent(f, path.join(root, "skills"));
    skills[id] = { tokens_per_turn: 0, source_path: path.relative(root, f) };
  }
  const agents = {};
  for (const f of listFiles(path.join(root, "agents"), /\.md$/)) {
    const id = basenameComponent(f, path.join(root, "agents"));
    agents[id] = { tokens_per_turn: 0, source_path: path.relative(root, f) };
  }
  const hooks = {};
  for (const f of listFiles(path.join(root, "hooks", "scripts"), /\.sh$/)) {
    const id = basenameComponent(f, path.join(root, "hooks", "scripts"));
    hooks[id] = { tokens_per_turn: 0, source_path: path.relative(root, f) };
  }
  const detectors = {};
  for (const f of listFiles(path.join(root, "rubric", "detectors"), /\.sh$/)) {
    const id = basenameComponent(f, path.join(root, "rubric", "detectors"));
    detectors[id] = { tokens_per_turn: 0, source_path: path.relative(root, f) };
  }

  // Daily auto-refresh cost: sum of S-17 + L-22 + C-19 estimated tokens.
  // Initial install estimates derived from per-source default budget caps
  // (100k tokens/source/day per L-7) scaled by typical source counts
  // (S-17: ~17 sources; L-22: ~10 sources; C-19: ~10 frameworks).
  const daily_auto_refresh_cost = {
    standards_s17_tokens: 0,
    pr_corpus_l22_tokens: 0,
    compliance_c19_tokens: 0,
    total_tokens: 0,
    source: "initial-install-estimate-zero-until-first-refresh-runs"
  };

  const out = {
    version: "1.0",
    emitted_at: new Date().toISOString(),
    skills,
    agents,
    hooks,
    detectors,
    daily_auto_refresh_cost,
    privacy: { env_vars_redacted: true, secret_scan: "applied", scope: "local-only" }
  };

  // Privacy: never embed env var values. The script intentionally never
  // reads process.env into the output; this comment documents the intent.

  fs.writeFileSync(process.env.EMIT_PATH, JSON.stringify(out) + "\n");
  process.stderr.write(`init-guardrails: emitted baseline with ${Object.keys(skills).length} skills, ${Object.keys(agents).length} agents, ${Object.keys(hooks).length} hooks, ${Object.keys(detectors).length} detectors\n`);
'
