#!/usr/bin/env bash
# W-5 register workflow stages on a profile. Stages registered:
# architect, plan, build, review, merge. Honors §2.5 profile extends chain.
set -uo pipefail
PROFILE=""; STAGES=(); LIST=0; UNREG=""; DRY=0; EMIT=""; OUT=""; RESOLVE=0
ALLOWED="architect plan build review merge"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --workflow-stage) STAGES+=("$2"); shift 2 ;;
    --unregister-stage) UNREG="$2"; shift 2 ;;
    --list-stages) LIST=1; shift ;;
    --dry-run) DRY=1; shift ;;
    --emit) EMIT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --resolve) RESOLVE=1; shift ;;
    -h|--help) echo "Usage: register-profile.sh --profile <yaml> --workflow-stage <name>... [--unregister-stage <name>] [--list-stages] [--dry-run] [--emit json --out <file>] [--resolve]"; exit 0 ;;
    *) shift ;;
  esac
done

if [[ "$LIST" -eq 1 ]]; then
  for s in $ALLOWED; do echo "register-profile: stage=$s" >&2; done
  exit 0
fi

[[ -z "$PROFILE" || ! -f "$PROFILE" ]] && { echo "register-profile: --profile <yaml> required" >&2; exit 2; }

# Validate stages.
for s in "${STAGES[@]:-}"; do
  [[ -z "$s" ]] && continue
  case " $ALLOWED " in
    *" $s "*) : ;;
    *) echo "register-profile: unknown_workflow_stage $s (allowed: $ALLOWED)" >&2; exit 2 ;;
  esac
done

if [[ "$DRY" -eq 1 ]]; then
  for s in "${STAGES[@]:-}"; do
    [[ -n "$s" ]] && echo "register-profile: planned: register $s into $PROFILE (dry_run; no writes)" >&2
  done
  exit 0
fi

# Unregister path.
if [[ -n "$UNREG" ]]; then
  PROFILE="$PROFILE" UNREG="$UNREG" ruby -ryaml -e '
    require "yaml"
    data = YAML.unsafe_load_file(ENV["PROFILE"]) rescue {}
    stages = data["workflow_stages"] || []
    stages = stages.reject { |s| s == ENV["UNREG"] }
    data["workflow_stages"] = stages
    File.write(ENV["PROFILE"], YAML.dump(data))
  '
  echo "register-profile: unregistered $UNREG from $PROFILE" >&2
  exit 0
fi

# Resolve precedence chain (read extends, merge stages).
if [[ "$RESOLVE" -eq 1 ]]; then
  PROFILE="$PROFILE" STAGES_CSV="$(IFS=,; echo "${STAGES[*]:-}")" ruby -ryaml -e '
    require "yaml"
    require "set"
    profile_path = ENV["PROFILE"]
    requested = (ENV["STAGES_CSV"] || "").split(",").reject(&:empty?)
    stages = []
    visited = Set.new
    queue = [profile_path]
    while (p = queue.shift)
      next if visited.include?(p)
      visited << p
      data = YAML.unsafe_load_file(p) rescue {}
      (data["workflow_stages"] || []).each { |s| stages << s unless stages.include?(s) }
      (data["extends"] || []).each do |ext|
        ext_path = File.expand_path(ext, File.dirname(p))
        queue << ext_path if File.file?(ext_path)
      end
    end
    requested.each { |s| stages << s unless stages.include?(s) }
    STDERR.puts "register-profile: effective_stages=#{stages.join(",")} profile=#{profile_path}"
  '
  exit 0
fi

# Append stage(s) to profile yaml.
PROFILE="$PROFILE" STAGES_CSV="$(IFS=,; echo "${STAGES[*]:-}")" ruby -ryaml -e '
  require "yaml"
  data = YAML.unsafe_load_file(ENV["PROFILE"]) rescue {}
  data["workflow_stages"] ||= []
  (ENV["STAGES_CSV"] || "").split(",").reject(&:empty?).each do |s|
    data["workflow_stages"] << s unless data["workflow_stages"].include?(s)
  end
  File.write(ENV["PROFILE"], YAML.dump(data))
'
for s in "${STAGES[@]:-}"; do
  [[ -n "$s" ]] && echo "register-profile: registered $s into $PROFILE" >&2
done

# Emit json record.
if [[ "$EMIT" == "json" && -n "$OUT" ]]; then
  STAGE="${STAGES[0]:-}"
  printf '{"profile":"%s","stage":"%s"}\n' "$PROFILE" "$STAGE" > "$OUT"
  echo "register-profile: emitted $OUT" >&2
fi
