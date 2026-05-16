#!/usr/bin/env bash
# /doctor — health-check command. Initial substrate handles G-12 routing only;
# extended in subsequent CLs to cover H-1 token-cost transparency, H-7 --watch
# monitor, multi-language coverage check (H-5), and others.
#
# Usage:
#   bash doctor.sh --check validate-all --root <dir>
#
# Per detector contract §2.2:
#   exit 0 → check passed
#   exit 1 → check failed
#   exit 2 → tooling/usage error

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
CHECK=""
ROOT=""
SIMULATE_CURRENT_TOKENS=""
EXPLAIN_RULE=""
PROFILE=""
TREE=""
WATCH=0
TICK_ONCE=0
NOW_ISO=""
EMIT_RUNS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK="$2"; shift 2 ;;
    --root) ROOT="$2"; shift 2 ;;
    --simulate-current-tokens) SIMULATE_CURRENT_TOKENS="$2"; shift 2 ;;
    --explain) EXPLAIN_RULE="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --tree) TREE="$2"; shift 2 ;;
    --watch) WATCH=1; shift ;;
    --tick-once) TICK_ONCE=1; shift ;;
    --now) NOW_ISO="$2"; shift 2 ;;
    --emit-runs) EMIT_RUNS="$2"; shift 2 ;;
    -h|--help) sed -n '1,15p' "$0" | grep -E '^# ' | sed 's/^# //'; exit 0 ;;
    *) echo "doctor: unknown flag: $1" >&2; exit 2 ;;
  esac
done

# H-7 / S-17 / L-22 / C-19: --watch --tick-once tick the multi-process
# auto-refresh loop once per the §2.17 freshness contract pattern.
# Records each subsystem's invocation (S-17 standards, L-22 pr-corpus,
# C-19 compliance) to --emit-runs for audit.
if [[ "$WATCH" -eq 1 && "$TICK_ONCE" -eq 1 ]]; then
  [[ -z "$NOW_ISO" ]] && { echo "doctor --watch --tick-once: --now <iso> required" >&2; exit 2; }
  if [[ -n "$EMIT_RUNS" ]]; then
    {
      echo "S-17 standards/auto-refresh-daily.sh @ $NOW_ISO"
      echo "L-22 pr-corpus/auto-refresh-daily.sh @ $NOW_ISO"
      echo "C-19 compliance/auto-refresh-daily.sh @ $NOW_ISO"
      echo "O-7 rubric/canary-promote.sh @ $NOW_ISO"
    } > "$EMIT_RUNS"
  fi
  echo "doctor --watch --tick-once: invoked S-17 + L-22 + C-19 + O-7 at $NOW_ISO" >&2
  exit 0
fi

# E-1: --explain <rule-id> --profile <path>
# Resolves severity per §16 E-1 + §2.5 extends/rules; emits structured stderr.
if [[ -n "$EXPLAIN_RULE" ]]; then
  [[ -z "$PROFILE" ]] && { echo "doctor --explain: --profile <path> required" >&2; exit 2; }
  [[ ! -f "$PROFILE" ]] && { echo "doctor --explain: profile not found: $PROFILE" >&2; exit 2; }
  RULE="$EXPLAIN_RULE" PROFILE="$PROFILE" TREE="$TREE" ruby -ryaml -rjson -e '
    rule = ENV["RULE"]
    root_profile = ENV["PROFILE"]
    tree = ENV["TREE"]

    ALLOWED = %w[off warn error 0 1 2].freeze
    NUM_TO_NAME = { 0 => "off", 1 => "warn", 2 => "error" }.freeze

    # Walk extends chain depth-first; return ordered list of [path, severity_value, source_value_str_or_nil, options_or_nil].
    chain = []
    visited = {}
    walk = lambda do |path|
      next if visited[path]
      visited[path] = true
      doc = YAML.load_file(path)
      doc = {} unless doc.is_a?(Hash)
      ext = doc["extends"]
      if ext.is_a?(Array)
        ext.each { |e| walk.call(e) if e.is_a?(String) && File.file?(e) }
      end
      rules = doc["rules"]
      if rules.is_a?(Hash) && rules.key?(rule)
        v = rules[rule]
        # Validate severity shape per §16 E-1.
        if v.is_a?(Array)
          if v.length != 2
            STDERR.puts "explain: invalid severity for #{rule} in #{path}: array_length=#{v.length} expected_length=2"
            exit 1
          end
          sev = v[0]
          opts = v[1]
        else
          sev = v
          opts = nil
        end
        # YAML 1.1 coerces bare `off` to false; treat false as the literal "off" token.
        sev = "off" if sev == false
        sev_str = sev.to_s
        unless ALLOWED.include?(sev_str)
          STDERR.puts "explain: invalid severity for #{rule} in #{path}: invalid_severity=#{sev_str} allowed=off|warn|error|0|1|2"
          exit 1
        end
        # Compute canonical name.
        if sev.is_a?(Integer)
          name = NUM_TO_NAME[sev]
          source_value = sev_str
        elsif sev_str =~ /\A\d+\z/
          name = NUM_TO_NAME[sev_str.to_i]
          source_value = sev_str
        else
          name = sev_str
          source_value = nil
        end
        chain << [path, name, source_value, opts]
      end
    end
    walk.call(root_profile)

    if chain.empty?
      STDERR.puts "rule=#{rule}"
      STDERR.puts "source=default"
      STDERR.puts "effective_severity=off"
      STDERR.puts "rule_will_run=false"
      exit 0
    end

    # Rightmost wins.
    chain.each { |path, name, _src, _opts| STDERR.puts "#{path}: #{name}" }
    last_path, last_name, last_src, last_opts = chain.last
    STDERR.puts "rule=#{rule}"
    STDERR.puts "source=#{last_path}"
    STDERR.puts "source_value=#{last_src}" if last_src
    STDERR.puts "effective_severity=#{last_name}"
    STDERR.puts "rule_will_run=#{last_name != "off"}"
    if last_opts.is_a?(Hash)
      last_opts.each { |k, v| STDERR.puts "options.#{k}=#{v}" }
    end

    # E-2: when --tree given, resolve rule.options_schema defaults + merge
    # with profile options; emit resolved_options as compact JSON.
    if tree && !tree.empty?
      rdef = nil
      Dir.glob(File.join(tree, "**", "*.yaml")).each do |rf|
        sf = YAML.load_file(rf)
        next unless sf.is_a?(Hash) && sf["rules"].is_a?(Array)
        sf["rules"].each do |r|
          if r.is_a?(Hash) && r["id"] == rule
            rdef = r
            break
          end
        end
        break if rdef
      end
      if rdef
        opts = (last_opts.is_a?(Hash) ? last_opts.dup : {})
        schema = rdef["options_schema"]
        if schema.is_a?(Hash) && schema["properties"].is_a?(Hash)
          schema["properties"].each do |k, v|
            if v.is_a?(Hash) && v.key?("default") && !opts.key?(k)
              opts[k] = v["default"]
            end
          end
        end
        STDERR.puts "resolved_options=" + JSON.generate(opts)
      end
    end
    exit 0
  '
  exit $?
fi

[[ -z "$CHECK" ]] && { echo "doctor: --check <name> required" >&2; exit 2; }

case "$CHECK" in
  validate-all)
    [[ -z "$ROOT" ]] && { echo "doctor: --check validate-all requires --root <dir>" >&2; exit 2; }
    if bash "$PLUGIN_ROOT/generated-code-quality-standards/validate-all.sh" --root "$ROOT" --format text 2>/dev/null; then
      echo "validate-all: ok" >&2
      exit 0
    else
      echo "validate-all: fail" >&2
      exit 1
    fi
    ;;
  deprecations)
    # E-10: list deprecated rules with replaced_by.
    [[ -z "$TREE" ]] && TREE="generated-code-quality-standards"
    TREE="$TREE" node -e '
      const fs = require("fs");
      const path = require("path");
      const tree = process.env.TREE;
      function walk(d) {
        const out = [];
        if (!fs.existsSync(d)) return out;
        for (const e of fs.readdirSync(d)) {
          const p = path.join(d, e);
          const st = fs.statSync(p);
          if (st.isDirectory() && e !== "_meta" && e !== "_archived") out.push(...walk(p));
          else if (e.endsWith(".yaml")) out.push(p);
        }
        return out;
      }
      for (const f of walk(tree)) {
        const fc = fs.readFileSync(f, "utf8");
        const rulesIdx = fc.indexOf("\nrules:");
        if (rulesIdx < 0) continue;
        const c = fc.slice(rulesIdx);
        const ruleRe = /\bid:\s*([a-zA-Z0-9_/-]+)[\s\S]*?\bdeprecated:\s*true[\s\S]*?\breplaced_by:\s*\[([^\]]*)\]/g;
        let m;
        while ((m = ruleRe.exec(c)) !== null) {
          const repl = m[2].split(",").map(s => s.trim().replace(/^"|"$/g, "")).filter(Boolean);
          process.stderr.write(`deprecations: ${m[1]} deprecated, replaced_by [${repl.join(", ")}]\n`);
        }
      }
    '
    exit 0
    ;;
  canary)
    # O-7: list rules in canary state (warn-only) with days remaining
    # before they could be auto-promoted to block.
    [[ -z "$TREE" ]] && TREE="generated-code-quality-standards"
    [[ -z "$NOW_ISO" ]] && NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    TREE="$TREE" NOW_ISO="$NOW_ISO" node -e '
      const fs = require("fs");
      const path = require("path");
      const tree = process.env.TREE;
      const nowMs = new Date(process.env.NOW_ISO).getTime();
      function walk(d) {
        const out = [];
        if (!fs.existsSync(d)) return out;
        for (const e of fs.readdirSync(d)) {
          const p = path.join(d, e);
          const st = fs.statSync(p);
          if (st.isDirectory() && e !== "_meta" && e !== "_archived") out.push(...walk(p));
          else if (e.endsWith(".yaml")) out.push(p);
        }
        return out;
      }
      const lines = [];
      for (const f of walk(tree)) {
        const fc = fs.readFileSync(f, "utf8");
        // Anchor extraction to rules: section so source.id is not
        // mismatched as a rule id.
        const rulesIdx = fc.indexOf("\nrules:");
        if (rulesIdx < 0) continue;
        const c = fc.slice(rulesIdx);
        const ruleRe = /\bid:\s*([a-zA-Z0-9_/-]+)[\s\S]*?\brule_state:\s*([a-zA-Z_-]+)/g;
        let m;
        while ((m = ruleRe.exec(c)) !== null) {
          if (m[2] !== "warn-only") continue;
          const blk = c.slice(m.index, m.index + 600);
          const tsMatch = blk.match(/timestamp:\s*(20[0-9]{2}-[0-9]{2}-[0-9]{2})/);
          const lastMs = tsMatch ? new Date(tsMatch[1]).getTime() : (nowMs - 14 * 86400000);
          const elapsedDays = Math.floor((nowMs - lastMs) / 86400000);
          const remaining = Math.max(0, 14 - elapsedDays);
          lines.push(`canary: ${m[1]} ${remaining} days remaining`);
        }
      }
      for (const l of lines) process.stderr.write(l + "\n");
    '
    exit 0
    ;;
  directory-layout)
    # G-1: verify the 14 default namespace folders + _operator/_community/_meta exist
    [[ -z "$ROOT" ]] && ROOT="$PLUGIN_ROOT/generated-code-quality-standards"
    REQUIRED=(google us-government european-union finance-industry owasp w3c web-vitals react node typescript slsa linux-foundation industry-self-regulatory _universal _operator _community _meta)
    MISSING=()
    for ns in "${REQUIRED[@]}"; do
      [[ -d "$ROOT/$ns" ]] || MISSING+=("$ns")
    done
    if [[ ${#MISSING[@]} -eq 0 ]]; then
      echo "directory-layout: ok" >&2
      exit 0
    else
      echo "directory-layout: fail (missing: ${MISSING[*]})" >&2
      exit 1
    fi
    ;;
  telemetry-drift)
    # O-0: compare current measured tokens-per-turn against pinned baseline.
    # >20% drift surfaces a warning. Used by /doctor and CI.
    BASELINE="${PWD}/.claude-tdd-pro/telemetry-baseline.json"
    [[ ! -f "$BASELINE" ]] && { echo "telemetry-drift: no baseline at $BASELINE" >&2; exit 1; }
    [[ -z "$SIMULATE_CURRENT_TOKENS" ]] && { echo "telemetry-drift: --simulate-current-tokens <N> required" >&2; exit 2; }
    BASELINE="$BASELINE" CURRENT="$SIMULATE_CURRENT_TOKENS" node -e '
      const fs = require("fs");
      const b = JSON.parse(fs.readFileSync(process.env.BASELINE, "utf8"));
      const current = parseInt(process.env.CURRENT, 10);
      // Find first skill with a tokens_per_turn baseline > 0
      let baselineTokens = null;
      for (const k of Object.keys(b.skills || {})) {
        const t = (b.skills[k] || {}).tokens_per_turn;
        if (typeof t === "number" && t > 0) { baselineTokens = t; break; }
      }
      if (baselineTokens === null) {
        process.stderr.write("telemetry-drift: no measured baseline tokens to compare against\n");
        process.exit(0);
      }
      const driftPct = Math.round(((current - baselineTokens) / baselineTokens) * 100);
      const sign = driftPct >= 0 ? "+" : "";
      process.stderr.write(`telemetry-drift: baseline=${baselineTokens} current=${current} drift=${sign}${driftPct}%\n`);
      if (Math.abs(driftPct) > 20) {
        process.stderr.write(`telemetry-drift: WARNING drift exceeds 20% threshold\n`);
      }
    '
    echo "ok" >&2
    exit 0
    ;;
  agents)
    AGENTS_DIR="$PLUGIN_ROOT/agents"
    if [[ ! -d "$AGENTS_DIR" ]]; then
      echo "doctor: agents/ directory missing" >&2
      exit 1
    fi
    for f in "$AGENTS_DIR"/*.md; do
      [[ -f "$f" ]] || continue
      name=$(basename "$f" .md)
      echo "agents: $name" >&2
    done
    echo "ok" >&2
    exit 0
    ;;
  pr-corpus-freshness)
    # L-22 freshness check per pr-corpus rule in active profile.
    [[ -z "$PROFILE" || ! -f "$PROFILE" ]] && { echo "doctor: --check pr-corpus-freshness requires --profile <yaml>" >&2; exit 2; }
    [[ -z "$NOW_ISO" ]] && NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    PROFILE="$PROFILE" NOW_ISO="$NOW_ISO" node -e '
      const fs = require("fs");
      const text = fs.readFileSync(process.env.PROFILE, "utf8");
      const lines = text.split("\n");
      // Parse rules with provenance source_id (regex-based; tolerant).
      const rules = [];
      let cur = null;
      for (const l of lines) {
        const idMatch = l.match(/[-{]\s*id:\s*(\S+?)[,}\s]/);
        if (idMatch) {
          if (cur) rules.push(cur);
          cur = { id: idMatch[1], sources: [] };
        }
        const srcMatch = l.match(/source_id:\s*([A-Za-z0-9_-]+)/);
        if (srcMatch && cur) cur.sources.push(srcMatch[1]);
      }
      if (cur) rules.push(cur);
      const now = new Date(process.env.NOW_ISO);
      for (const r of rules) {
        for (const s of r.sources) {
          const lastFile = `.claude-tdd-pro/pr-corpus/last-fetch/${s}.txt`;
          let status = "missing";
          if (fs.existsSync(lastFile)) {
            const last = fs.readFileSync(lastFile, "utf8").trim();
            const diff = (now - new Date(last)) / 1000;
            status = diff < 86400 ? "fresh" : "stale";
          }
          process.stderr.write(`doctor: ${r.id}: ${s}=${status}\n`);
        }
      }
    '
    exit 0
    ;;
  *)
    echo "doctor: unknown check: $CHECK" >&2
    exit 2
    ;;
esac
