#!/usr/bin/env bash
# commands/full-surface-intake.sh — S-57 full-surface requirements intake (v1.14 §30 / §2.35).
#
# The INPUT-side mirror of S-56 full-surface consult (§29 / P-11). Where S-32 business-intake gathers a
# FIXED universal-9 questionnaire — leaving most of the 42-namespace rule surface grounded from defaults —
# S-57 classifies the founder's workload into the namespaces it actually touches and activates per-namespace
# PROBE GROUPS, so intake gathers facts across the whole surface. It emits a v1.1 business-profile.json that
# is a STRICT SUPERSET of the v1.0 profile: the universal 9 are mirrored unchanged (universal-stays-universal),
# plus workload_classification + probes.<namespace> + grounded_in_namespaces; grounded_in is a strict superset.
#
# S-57 COMPOSES S-32 (it shells business-intake.sh for the universal layer + its validation) — so v1.0
# behavior is untouched and back-compat is guaranteed by construction.
#
# CLI:
#   --workload <text>          the founder's vision/workload (drives classification; falls back to answers.workload)
#   --classify                 print workload_classification JSON to stdout; exit 0
#   --list-questions           print {universal:[...], probe_groups:{ns:[...]}} JSON to stdout; exit 0
#   --answer key=value         a universal answer (repeatable; forwarded to S-32)
#   --answers <json>           universal answers as JSON (file or inline; forwarded to S-32)
#   --probe-answer ns:key=value  a per-namespace probe answer (repeatable)
#   --with-data                include the S-38 data-aware universal questions
#   --out <path>               business-profile.json v1.1 (default standards/business-profile.json)
#   --classifier <yaml>        default standards/business-intake-workload-classifier.yaml
#   --question-bank <yaml>     default standards/business-intake-question-bank.yaml
#   --now <iso>                generated_at (default current UTC)
#   --partial                  write the profile even if incomplete
#   --dry-run                  preview to stderr; write nothing (§2.14)
#
# stderr: workload_types=<csv> namespaces=<n> activated_probes=<n> |
#         profile=<path> schema_version=1.1 complete=<bool>
#         grounded_in=<csv> grounded_in_namespaces=<csv> unanswered=<csv>
# Exit: 0 complete (or classify/list/partial/dry-run) / 1 incomplete / 2 usage/invalid.

set -uo pipefail

WORKLOAD=""; CLASSIFY=0; LIST=0; OUT=""; NOW=""; PARTIAL=0; DRY_RUN=0; WITH_DATA=0
ANSWERS_JSON=""; ANSWERS_KV=""; PROBE_KV=""; CLASSIFIER=""; QBANK=""

while [ $# -gt 0 ]; do
  case "$1" in
    --workload)      WORKLOAD="${2-}"; shift 2 ;;
    --classify)      CLASSIFY=1; shift ;;
    --list-questions) LIST=1; shift ;;
    --answer)        ANSWERS_KV="${ANSWERS_KV}${2-}"$'\n'; shift 2 ;;
    --answers)       ANSWERS_JSON="${2-}"; shift 2 ;;
    --probe-answer)  PROBE_KV="${PROBE_KV}${2-}"$'\n'; shift 2 ;;
    --with-data)     WITH_DATA=1; shift ;;
    --out)           OUT="${2-}"; shift 2 ;;
    --classifier)    CLASSIFIER="${2-}"; shift 2 ;;
    --question-bank) QBANK="${2-}"; shift 2 ;;
    --now)           NOW="${2-}"; shift 2 ;;
    --partial)       PARTIAL=1; shift ;;
    --dry-run)       DRY_RUN=1; shift ;;
    -h|--help) echo "Usage: full-surface-intake.sh --workload <text> [--classify|--list-questions] [--answer k=v]... [--probe-answer ns:k=v]... [--out <path>]" >&2; exit 0 ;;
    *) echo "full-surface-intake: unknown arg: $1" >&2; exit 2 ;;
  esac
done

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
resolve() { if [ -f "$1" ]; then printf '%s' "$1"; elif [ -f "$PLUGIN_ROOT/$1" ]; then printf '%s' "$PLUGIN_ROOT/$1"; else printf '%s' "$1"; fi; }
[ -z "$CLASSIFIER" ] && CLASSIFIER="standards/business-intake-workload-classifier.yaml"
[ -z "$QBANK" ]      && QBANK="standards/business-intake-question-bank.yaml"
CLASSIFIER=$(resolve "$CLASSIFIER"); QBANK=$(resolve "$QBANK")
[ -z "$OUT" ] && OUT="standards/business-profile.json"
[ -z "$NOW" ] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
[ -f "$CLASSIFIER" ] || { echo "full-surface-intake: classifier not found: $CLASSIFIER" >&2; exit 2; }
[ -f "$QBANK" ]      || { echo "full-surface-intake: question-bank not found: $QBANK" >&2; exit 2; }

# Universal layer: shell S-32 to produce the v1.0 profile (answers + grounded_in + complete + unanswered),
# unless we are only classifying / listing. This guarantees the universal 9 and their validation are
# byte-identical to development intake (composition, not duplication).
UNIVERSAL_JSON="{}"
if [ "$CLASSIFY" = "0" ] && [ "$LIST" = "0" ]; then
  _bi_tmp="$(mktemp)"
  _bi_args=(--partial --out "$_bi_tmp" --now "$NOW")
  [ "$WITH_DATA" = "1" ] && _bi_args+=(--with-data)
  [ -n "$ANSWERS_JSON" ] && _bi_args+=(--answers "$ANSWERS_JSON")
  # Forward each universal --answer (newline-delimited).
  while IFS= read -r _ln; do
    [ -z "$_ln" ] && continue
    _bi_args+=(--answer "$_ln")
  done <<EOF
$ANSWERS_KV
EOF
  # A bad universal enum answer must still fail loud (exit 2) — run without --partial capture of rc.
  if ! bash "$PLUGIN_ROOT/commands/business-intake.sh" "${_bi_args[@]}" >/dev/null 2>"$_bi_tmp.err"; then
    if grep -q '^invalid=' "$_bi_tmp.err" 2>/dev/null; then
      cat "$_bi_tmp.err" >&2; rm -f "$_bi_tmp" "$_bi_tmp.err"; exit 2
    fi
  fi
  [ -f "$_bi_tmp" ] && UNIVERSAL_JSON="$(cat "$_bi_tmp")"
  rm -f "$_bi_tmp" "$_bi_tmp.err"
fi

CLASSIFIER="$CLASSIFIER" QBANK="$QBANK" WORKLOAD="$WORKLOAD" CLASSIFY="$CLASSIFY" LIST="$LIST" \
OUT="$OUT" NOW="$NOW" PARTIAL="$PARTIAL" DRY_RUN="$DRY_RUN" WITH_DATA="$WITH_DATA" \
PROBE_KV="$PROBE_KV" UNIVERSAL_JSON="$UNIVERSAL_JSON" ANSWERS_JSON="$ANSWERS_JSON" ruby -ryaml -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
  classifier_f=ENV["CLASSIFIER"]; qbank_f=ENV["QBANK"]
  classify=ENV["CLASSIFY"]=="1"; list=ENV["LIST"]=="1"
  out=ENV["OUT"]; now=ENV["NOW"]; partial=ENV["PARTIAL"]=="1"; dry=ENV["DRY_RUN"]=="1"

  cls = YAML.unsafe_load_file(classifier_f); cls = [] unless cls.is_a?(Array)
  qb  = YAML.unsafe_load_file(qbank_f) || {}
  groups = (qb["probe_groups"] || {})

  universal = begin; JSON.parse(ENV["UNIVERSAL_JSON"]); rescue; {}; end
  u_answers = universal["answers"] || {}

  # Workload text: --workload else answers.workload.
  wl = ENV["WORKLOAD"].to_s.strip
  wl = u_answers["workload"].to_s if wl.empty?
  hay = wl.downcase

  # Classify: a type fires if always:true or any signal is a substring of the workload text.
  fired = []
  cls.each do |t|
    next unless t.is_a?(Hash)
    if t["always"] == true
      fired << t
    else
      sigs = (t["signals"] || [])
      fired << t if sigs.any? { |s| !s.to_s.empty? && hay.include?(s.to_s.downcase) }
    end
  end
  namespaces = fired.flat_map { |t| t["namespaces"] || [] }.uniq.sort
  workload_types = fired.map { |t| t["workload_type"] }.compact
  # Activated probe namespaces = in-scope namespaces that actually have a probe group.
  activated = namespaces.select { |ns| groups.key?(ns) }.sort
  # §30.2 coverage TRANSPARENCY: in-scope namespaces with no probe group. Reported explicitly (never
  # silent) so a coverage gap is visible — the intake mirror of "no rule silently unenforced".
  unprobed = (namespaces - activated).sort

  if classify
    STDOUT.puts JSON.pretty_generate({
      "workload_classification" => {
        "workload_types" => workload_types,
        "namespaces" => namespaces,
        "activated_probe_namespaces" => activated,
        "unprobed_in_scope" => unprobed
      }
    })
    STDERR.puts "workload_types=#{workload_types.join(",")}"
    STDERR.puts "namespaces=#{namespaces.length}"
    STDERR.puts "activated_probes=#{activated.length}"
    STDERR.puts "unprobed_in_scope=#{unprobed.join(",")}"
    exit 0
  end

  if list
    STDOUT.puts JSON.pretty_generate({
      "universal_source" => "commands/business-intake.sh --list-questions",
      "probe_groups" => activated.each_with_object({}) { |ns,h| h[ns] = groups[ns] }
    })
    STDERR.puts "workload_types=#{workload_types.join(",")}"
    STDERR.puts "activated_probes=#{activated.length}"
    exit 0
  end

  # Index every activated probe by key; collect probe answers (ns:key=value).
  probe_by_key = {}   # key => {ns, def}
  activated.each do |ns|
    (groups[ns] || []).each { |q| probe_by_key[q["key"]] = {"ns"=>ns, "def"=>q} }
  end

  probe_answers = {}  # ns => {key => value}
  ENV["PROBE_KV"].to_s.split("\n").each do |line|
    next if line.strip.empty?
    lhs, _, val = line.partition("=")
    ns, _, key = lhs.strip.partition(":")
    ns = ns.strip; key = key.strip; val = val.strip
    # Accept "ns:key=value" or bare "key=value" (resolve ns from the key index).
    if key.empty?
      key = ns; ns = (probe_by_key[key] ? probe_by_key[key]["ns"] : "")
    end
    meta = probe_by_key[key]
    if meta.nil?
      STDERR.puts "invalid=#{key} reason=unknown-probe"; exit 2
    end
    ns = meta["ns"]
    qd = meta["def"]
    if qd["type"] == "enum" && !(qd["allowed"] || []).include?(val)
      STDERR.puts "invalid=#{key} allowed=#{(qd["allowed"]||[]).join(",")}"; exit 2
    end
    if qd["type"] == "free" && val.empty?
      STDERR.puts "invalid=#{key} reason=empty"; exit 2
    end
    (probe_answers[ns] ||= {})[key] = val
  end

  # Completeness: universal complete AND every activated probe answered.
  all_probe_keys = probe_by_key.keys
  answered_probe_keys = probe_answers.values.flat_map(&:keys)
  probe_unanswered = (all_probe_keys - answered_probe_keys).sort
  u_unanswered = (universal["unanswered"] || [])
  u_complete = (universal["complete"] == true)
  complete = u_complete && probe_unanswered.empty?
  unanswered = (u_unanswered + probe_unanswered)

  # grounded_in: strict superset = universal grounded_in ∪ answered-probe source_ids.
  u_grounded = (universal["grounded_in"] || [])
  probe_sources = probe_answers.flat_map { |ns,kv| kv.keys.map { |k| probe_by_key[k]["def"]["source_id"] } }
  grounded_in = (u_grounded + probe_sources).compact.uniq.sort
  grounded_in_namespaces = probe_answers.keys.sort

  if !complete && !partial
    STDERR.puts "unanswered=#{unanswered.join(",")}"
    STDERR.puts "complete=false"
    exit 1
  end

  profile = {
    "schema_version" => "1.1",
    "generated_at"   => now,
    "complete"       => complete,
    "answers"        => u_answers,                       # universal 9 mirrored unchanged
    "workload_classification" => {
      "workload_types" => workload_types,
      "namespaces" => namespaces,
      "activated_probe_namespaces" => activated,
      "unprobed_in_scope" => unprobed              # §30.2 explicit coverage transparency
    },
    "probes"         => probe_answers,                   # per-namespace probe answers
    "grounded_in"    => grounded_in,                     # strict superset of v1.0
    "grounded_in_namespaces" => grounded_in_namespaces,
    "unanswered"     => unanswered
  }

  unless dry
    require "fileutils"
    d = File.dirname(out); FileUtils.mkdir_p(d) unless d.empty? || d == "."
    File.write(out, JSON.pretty_generate(profile) + "\n")
  end

  STDERR.puts "dry_run=true" if dry
  STDERR.puts "profile=#{out}"
  STDERR.puts "schema_version=1.1"
  STDERR.puts "complete=#{complete}"
  STDERR.puts "workload_types=#{workload_types.join(",")}"
  STDERR.puts "grounded_in=#{grounded_in.join(",")}"
  STDERR.puts "grounded_in_namespaces=#{grounded_in_namespaces.join(",")}"
  STDERR.puts "unprobed_in_scope=#{unprobed.join(",")}"
  STDERR.puts "unanswered=#{unanswered.join(",")}" unless unanswered.empty?
  exit 0
'
exit $?
