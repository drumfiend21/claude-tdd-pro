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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK="$2"; shift 2 ;;
    --root) ROOT="$2"; shift 2 ;;
    --simulate-current-tokens) SIMULATE_CURRENT_TOKENS="$2"; shift 2 ;;
    --explain) EXPLAIN_RULE="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    -h|--help) sed -n '1,15p' "$0" | grep -E '^# ' | sed 's/^# //'; exit 0 ;;
    *) echo "doctor: unknown flag: $1" >&2; exit 2 ;;
  esac
done

# E-1: --explain <rule-id> --profile <path>
# Resolves severity per §16 E-1 + §2.5 extends/rules; emits structured stderr.
if [[ -n "$EXPLAIN_RULE" ]]; then
  [[ -z "$PROFILE" ]] && { echo "doctor --explain: --profile <path> required" >&2; exit 2; }
  [[ ! -f "$PROFILE" ]] && { echo "doctor --explain: profile not found: $PROFILE" >&2; exit 2; }
  RULE="$EXPLAIN_RULE" PROFILE="$PROFILE" ruby -ryaml -e '
    rule = ENV["RULE"]
    root_profile = ENV["PROFILE"]

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
  *)
    echo "doctor: unknown check: $CHECK" >&2
    exit 2
    ;;
esac
