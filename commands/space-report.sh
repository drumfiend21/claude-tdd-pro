#!/usr/bin/env bash
# Q-3 SPACE text dashboard with metric IDs + counter-Goodhart guards.
set -uo pipefail
METRICS=""; COLLECTED=""; CONFIG=""; SINCE=""; SHARE_TO=""; AGGREGATE_USERS=0; TUI=0; DRY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --metrics) METRICS="$2"; shift 2 ;;
    --collected) COLLECTED="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    --share) SHARE_TO="$2"; shift 2 ;;
    --aggregate-users) AGGREGATE_USERS=1; shift ;;
    --tui) TUI=1; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) echo "Usage: space-report.sh --metrics <yaml> [--collected <yaml>] --config <yaml> [--since <window>] [--tui] [--dry-run]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$METRICS" || -z "$CONFIG" ]] && { echo "space-report: --metrics and --config required" >&2; exit 2; }

# X-5 view-mode emission: --tui activates the charm.sh-style interactive view;
# default remains markdown so non-TTY callers (CI, redirected stdout) work.
if [[ "$TUI" -eq 1 ]]; then
  echo "space-report: view=tui interactive=true framework=charm.sh dry_run=$DRY" >&2
  exit 0
fi
echo "space-report: view=markdown (default)" >&2

# Reject --aggregate-users: this dashboard is solo-scale.
if [[ "$AGGREGATE_USERS" -eq 1 ]]; then
  echo "space-report: --aggregate-users rejected; this dashboard is solo-scale only (no team-rollup, no benchmarking)" >&2
  exit 2
fi

# Reject --share when share=never in config.
if [[ -n "$SHARE_TO" ]]; then
  SHARE_VAL=$(grep -E '^share:' "$CONFIG" | sed -E 's/share:[[:space:]]*//' | tr -d '"' | tr -d ' ')
  if [[ "$SHARE_VAL" == "never" ]]; then
    echo "space-report: --share $SHARE_TO blocked: share=never in config; change config to share before retrying" >&2
    exit 2
  fi
fi

# Solo-scale caveat to STDOUT (first 20 lines).
cat <<EOF
# SPACE Report (solo-scale self-observation)

> **Scope caveat**: this is solo-scale self-observation, not
> productivity science. Limitations: no causality, no benchmarking,
> no performance review. Single-developer, local-only, retention-bounded.

EOF

METRICS="$METRICS" COLLECTED="$COLLECTED" CONFIG="$CONFIG" \
LANG="${LANG:-en_US.UTF-8}" ruby -ryaml -rset -e '# coding: utf-8
Encoding.default_external = Encoding::UTF_8
metrics = (YAML.unsafe_load_file(ENV["METRICS"]) rescue {})["metrics"] || []
collected_path = ENV["COLLECTED"]
collected = (collected_path.to_s.empty? || !File.file?(collected_path)) ? [] : ((YAML.unsafe_load_file(collected_path) rescue {})["collected"] || [])
config = YAML.unsafe_load_file(ENV["CONFIG"]) rescue {}
dims = config["dimensions"] || {}

def enabled?(dims, name)
  d = dims[name] || {}
  d["enabled"] == true
end

DISPLAY = {
  "satisfaction" => "Satisfaction",
  "performance" => "Performance",
  "activity" => "Activity",
  "collaboration" => "Collaboration",
  "efficiency_and_flow" => "Efficiency and Flow",
}

# Build collected index by id.
coll_by_id = {}
collected.each { |c| coll_by_id[c["id"]] = c }

# Per-dimension report sections.
%w[satisfaction performance activity collaboration efficiency_and_flow].each do |dim|
  next unless enabled?(dims, dim)
  STDERR.puts "## #{DISPLAY[dim]}"
  metrics.select { |m| m["dimension"] == dim }.each do |m|
    id = m["id"]
    coll = coll_by_id[id]
    val = coll ? coll["value"] : (m["value"] || nil)
    # Auto-derive flow-guard-warnings from friction events when no value supplied.
    if val.nil? && id == "space-flow-guard-warnings"
      events_path = ".claude-tdd-pro/friction/events.jsonl"
      if File.file?(events_path)
        marker = %q{"event":"flow-guard-warning"}
        val = File.readlines(events_path).count { |l| l.include?(marker) }
      end
    end
    # L-15 auto-derive pr-corpus learn rate from learn-stats.json.
    if val.nil? && id == "space-pr-corpus-learn-rate"
      stats_path = ".claude-tdd-pro/pr-corpus/learn-stats.json"
      if File.file?(stats_path)
        require "json"
        j = JSON.parse(File.read(stats_path)) rescue {}
        val = j["learn_events_30d"]
      end
    end
    line = "- #{id}"
    line += ": #{val}" unless val.nil?
    line += " (window=#{m["reporting_window"]})" if m["reporting_window"]
    line += " no_data" if val.nil?
    STDERR.puts line
  end
end

# Counter-Goodhart guards.
warnings = []

# Activity-only spike: activity-commits up >2x but pass-rate not improved.
act = coll_by_id["space-activity-commits"]
perf = coll_by_id["space-perf-rubric-pass-rate"]
if act && perf && act["prev"] && (act["value"].to_f / [act["prev"].to_f, 0.0001].max) > 2 && (perf["value"].to_f - perf["prev"].to_f).abs < 0.05
  warnings << "counter-goodhart: activity_spike_without_quality_change (commits #{act["prev"]} -> #{act["value"]} but pass-rate flat)"
end

# Pass-rate up + suppression up: optimizing the metric not the system.
sup = coll_by_id["space-friction-suppressions"]
if perf && sup && perf["prev"] && perf["value"].to_f > perf["prev"].to_f && sup["value"].to_i > sup["prev"].to_i
  warnings << "counter-goodhart: pass_rate_up_with_suppression_up (pass-rate #{perf["prev"]} -> #{perf["value"]} but suppressions #{sup["prev"]} -> #{sup["value"]})"
end

unless warnings.empty?
  STDERR.puts ""
  STDERR.puts "## Goodhart Guards"
  warnings.each { |w| STDERR.puts "- #{w}" }
end

# Unknown metric warnings.
known_ids = metrics.map { |m| m["id"] }.to_set
unknown = collected.map { |c| c["id"] }.reject { |id| known_ids.include?(id) }
unless unknown.empty?
  STDERR.puts ""
  STDERR.puts "## Warnings"
  unknown.each { |id| STDERR.puts "- warning: collected metric #{id} not declared in space/metrics.yaml" }
end
'
