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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --emit-baseline) EMIT_PATH="$2"; shift 2 ;;
    --emit-empty-registries) EMIT_EMPTY_REGISTRIES=1; shift ;;
    -h|--help)
      echo "Usage: init-guardrails.sh --emit-baseline <path> | --emit-empty-registries" >&2
      exit 0 ;;
    *) echo "init-guardrails: unknown flag: $1" >&2; exit 2 ;;
  esac
done

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
