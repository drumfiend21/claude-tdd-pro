#!/usr/bin/env bash
# Q-2 SPACE collector. Aggregates metrics from F-2 (rubric pass rate +
# defect escape), git (activity opt-in), F-4/E-5 (suppression),
# PostToolUse logs (feedback loop time), W-3 transitions, and E-12
# cache hit rate per architecture section 16 Q-2.
set -uo pipefail
METRIC=""
ALL=0
GIT_ROOT=""
CONFIG=""
SINCE=""
OUT=""
STATS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --metric) METRIC="$2"; shift 2 ;;
    --all) ALL=1; shift ;;
    --git-root) GIT_ROOT="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --stats) STATS="$2"; shift 2 ;;
    -h|--help) echo "Usage: collector.sh --metric <name> [--config <path>] [--git-root <path>] [--since <window>] [--stats <yaml>] | --all --out <path>"; exit 0 ;;
    *) shift ;;
  esac
done

# P-8 skill-perf cross-loop signal. Inlined dim_enabled check (the function
# below is defined later; bash 3.2 needs function definition before call site).
if [[ "$METRIC" == "skill-perf" ]]; then
  src="${STATS:-.claude-tdd-pro/skills/perf-stats.yaml}"
  ENABLED=1
  if [[ -n "$CONFIG" && -f "$CONFIG" ]]; then
    grep -qE 'efficiency_and_flow:[[:space:]]*\{[[:space:]]*enabled:[[:space:]]*true' "$CONFIG" || ENABLED=0
  fi
  if [[ "$ENABLED" -eq 1 ]]; then
    SKILLS=""
    if [[ -f "$src" ]]; then
      SKILLS=$(grep -E '^[a-zA-Z][a-zA-Z0-9_-]*:' "$src" | sed -E 's/:.*//' | tr '\n' ' ')
    fi
    legacy=".claude-tdd-pro/prompts/skill-perf.jsonl"
    if [[ -f "$legacy" && -z "$SKILLS" ]]; then
      SKILLS=$(grep -oE '"skill":"[^"]+"' "$legacy" | sed -E 's/.*"skill":"([^"]+)".*/\1/' | tr '\n' ' ')
    fi
    if [[ ! -f "$src" && ! -f "$legacy" ]]; then
      echo "space-collector: id=space-skill-perf dimension=efficiency_and_flow source_loop=prompt skill_perf=no_data" >&2
    else
      echo "space-collector: id=space-skill-perf dimension=efficiency_and_flow source_loop=prompt stats=$src skills=$SKILLS" >&2
    fi
  fi
  exit 0
fi

# Helper: check if a dimension is enabled in config.
dim_enabled() {
  local dim="$1"
  [[ -z "$CONFIG" || ! -f "$CONFIG" ]] && return 0
  CONFIG="$CONFIG" DIM="$dim" ruby -ryaml -e '
    Encoding.default_external = Encoding::UTF_8
    d = YAML.load_file(ENV["CONFIG"]) rescue {}
    dims = d["dimensions"] || {}
    cfg = dims[ENV["DIM"]] || {}
    exit (cfg["enabled"] == true ? 0 : 1)
  '
}

emit_metric() {
  local id="$1" dim="$2" rest="$3"
  echo "id=$id dimension=$dim $rest" >&2
}

emit_yaml() {
  local id="$1" dim="$2" loop="$3" val="${4:-}"
  [[ -z "$OUT" ]] && return 0
  mkdir -p "$(dirname "$OUT")"
  if [[ ! -f "$OUT" ]]; then
    echo "metrics:" > "$OUT"
  fi
  {
    echo "  - id: $id"
    echo "    dimension: $dim"
    echo "    source_loop: $loop"
    [[ -n "$val" ]] && echo "    value: $val"
    case "$loop" in
      rubric)      echo "    upstream_doc: 'reads from .claude-tdd-pro/rubric-runs/ — see rubric loop documentation'" ;;
      rule-engine) echo "    upstream_doc: 'reads from .claude-tdd-pro/cache/ — see rule-engine loop documentation'" ;;
      workflow)    echo "    upstream_doc: 'reads from .claude-tdd-pro/workflow/ — see workflow loop documentation'" ;;
      prompt)     echo "    upstream_doc: 'reads from .claude-tdd-pro/prompts/ — see prompt loop documentation'" ;;
    esac
    echo "    scope: solo"
  } >> "$OUT"
}

run_metric() {
  local m="$1"
  case "$m" in
    activity-commits)
      if ! dim_enabled activity; then
        echo "activity_skipped=opt_in_not_set" >&2
        return 0
      fi
      [[ -z "$GIT_ROOT" || ! -d "$GIT_ROOT/.git" ]] && { echo "id=space-act-commits dimension=activity commits=0" >&2; return 0; }
      local count=$(cd "$GIT_ROOT" && git log --oneline 2>/dev/null | wc -l | tr -d ' ')
      emit_metric "space-act-commits" "activity" "commits=$count"
      ;;
    rubric-pass-rate)
      if ! dim_enabled performance && [[ -n "$CONFIG" ]]; then
        echo "performance_disabled=skipped" >&2
        return 0
      fi
      local f=".claude-tdd-pro/rubric-runs/last.json"
      [[ ! -f "$f" ]] && { echo "id=space-perf-rubric-pass-rate dimension=performance rubric_pass_rate=no_data" >&2; emit_yaml "space-perf-rubric-pass-rate" "performance" "rubric"; return 0; }
      local pass=$(node -e "const j=JSON.parse(require('fs').readFileSync('$f','utf8'));process.stdout.write(String(j.pass||0))")
      local fail=$(node -e "const j=JSON.parse(require('fs').readFileSync('$f','utf8'));process.stdout.write(String(j.fail||0))")
      local total=$((pass + fail))
      [[ "$total" -eq 0 ]] && total=1
      local rate=$(node -e "process.stdout.write(($pass/$total).toFixed(2))")
      emit_metric "space-perf-rubric-pass-rate" "performance" "rubric_pass_rate=$rate source_loop=rubric"
      emit_yaml "space-perf-rubric-pass-rate" "performance" "rubric" "$rate"
      ;;
    defect-escape)
      local f=".claude-tdd-pro/rubric-runs/escape.json"
      [[ ! -f "$f" ]] && { echo "id=space-perf-defect-escape dimension=performance no_data=true" >&2; return 0; }
      local rate=$(node -e "const j=JSON.parse(require('fs').readFileSync('$f','utf8'));const d=j.defects_post_promote||0;const p=j.promotions||1;process.stdout.write((d/p).toFixed(2))")
      emit_metric "space-perf-defect-escape" "performance" "defect_escape=$rate"
      ;;
    suppression-count)
      local rl_count=$(wc -l < .claude-tdd-pro/suppressions/rule-loop.log 2>/dev/null | tr -d ' ' || echo 0)
      local in_count=$(wc -l < .claude-tdd-pro/suppressions/inline.log 2>/dev/null | tr -d ' ' || echo 0)
      local total=$((rl_count + in_count))
      emit_metric "space-friction-suppressions" "efficiency_and_flow" "suppression_total=$total rule_loop=$rl_count inline=$in_count"
      ;;
    cache-hit-rate)
      local f=".claude-tdd-pro/cache/stats.json"
      [[ ! -f "$f" ]] && { echo "id=space-eff-cache-hit-rate dimension=efficiency_and_flow no_data=true" >&2; return 0; }
      local rate=$(node -e "const j=JSON.parse(require('fs').readFileSync('$f','utf8'));const h=j.hits||0;const m=j.misses||0;const t=h+m||1;process.stdout.write((h/t).toFixed(2))")
      emit_metric "space-eff-cache-hit-rate" "efficiency_and_flow" "cache_hit_rate=$rate source_loop=rule-engine"
      emit_yaml "space-eff-cache-hit-rate" "efficiency_and_flow" "rule-engine" "$rate"
      ;;
    feedback-loop-time)
      local f=".claude-tdd-pro/posttooluse/log.jsonl"
      [[ ! -f "$f" ]] && { echo "id=space-eff-feedback-loop dimension=efficiency_and_flow no_data=true" >&2; return 0; }
      local p50=$(node -e "
        const lines=require('fs').readFileSync('$f','utf8').trim().split('\n').filter(Boolean);
        const durs=lines.map(l=>{const j=JSON.parse(l);return (new Date(j.finished_at)-new Date(j.started_at))/1000}).sort((a,b)=>a-b);
        let m;
        if (durs.length === 0) m = 0;
        else if (durs.length % 2 === 1) m = durs[Math.floor(durs.length/2)];
        else m = (durs[durs.length/2 - 1] + durs[durs.length/2]) / 2;
        process.stdout.write(String(Math.round(m)))
      ")
      emit_metric "space-eff-feedback-loop" "efficiency_and_flow" "feedback_loop_seconds_p50=$p50"
      ;;
    workflow-transitions)
      local f=".claude-tdd-pro/workflow/transitions.jsonl"
      [[ ! -f "$f" ]] && { echo "id=space-collab-transitions dimension=collaboration no_data=true" >&2; return 0; }
      local count=$(wc -l < "$f" | tr -d ' ')
      emit_metric "space-collab-transitions" "collaboration" "transitions=$count source_loop=workflow"
      emit_yaml "space-collab-transitions" "collaboration" "workflow" "$count"
      ;;
    satisfaction-survey)
      if ! dim_enabled satisfaction; then
        echo "satisfaction_skipped=opt_in_not_set" >&2
        return 0
      fi
      emit_metric "space-sat-micro-survey" "satisfaction" "survey_runs=1"
      ;;
    friction-events)
      local f=".claude-tdd-pro/friction/events.jsonl"
      [[ ! -f "$f" ]] && { echo "id=space-eff-friction-events dimension=efficiency_and_flow no_data=true" >&2; return 0; }
      local count=$(wc -l < "$f" | tr -d ' ')
      emit_metric "space-eff-friction-events" "efficiency_and_flow" "friction_events=$count"
      ;;
    skill-perf|skill-performance)
      local f=".claude-tdd-pro/prompts/skill-perf.jsonl"
      [[ ! -f "$f" ]] && { echo "id=space-eff-skill-perf dimension=efficiency_and_flow skill_perf=no_data" >&2; return 0; }
      local skill=$(node -e "const j=JSON.parse(require('fs').readFileSync('$f','utf8').trim().split('\n')[0]);process.stdout.write(j.skill||'unknown')")
      emit_metric "space-eff-skill-perf" "efficiency_and_flow" "skill_perf_present=true source_loop=prompt skill=$skill"
      ;;
    *)
      echo "collector: unknown metric: $m (valid: activity-commits, rubric-pass-rate, defect-escape, suppression-count, cache-hit-rate, feedback-loop-time, workflow-transitions, satisfaction-survey, skill-perf)" >&2
      return 2
      ;;
  esac
}

if [[ "$ALL" -eq 1 ]]; then
  [[ -z "$OUT" ]] && { echo "collector: --all requires --out" >&2; exit 2; }
  mkdir -p "$(dirname "$OUT")"
  : > "$OUT"
  for m in rubric-pass-rate defect-escape suppression-count cache-hit-rate feedback-loop-time workflow-transitions; do
    run_metric "$m" 2>/dev/null
  done
  echo "collector: wrote $OUT" >&2
  exit 0
fi

[[ -z "$METRIC" ]] && { echo "collector: --metric <name> or --all required" >&2; exit 2; }
run_metric "$METRIC"
