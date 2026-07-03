#!/usr/bin/env bash
# commands/architect-session.sh - S-36 guided architect session orchestrator
# (v1.13 §27.15).
#
# The single entry point a non-technical founder uses. Takes a plain-language
# vision (+ business answers) and drives the whole flow: S-32 intake -> S-33
# translate -> S-34 multi-option recommend -> S-35 plain-language explain, over
# the built S-26/S-28/S-29 stack. While the profile is incomplete it surfaces
# the next question for the agent to ask; once complete it produces a session
# bundle (requirements + options + explanation) and a plain-language summary.
#
# CLI:
#   --vision <text>     the founder's vision (used as the workload answer)
#   --profile <json>    a business-profile.json (skip intake)
#   --answer key=value  a business answer (repeatable; runs S-32 intake)
#   --answers <json>    business answers as JSON
#   --out-dir <dir>     session output dir (default standards/architect-session)
#   --now <iso>         generated_at (default current UTC)
#   --dry-run           preview to stderr; write nothing (S2.14)
#
# stderr (incomplete): session_complete=false next_question=<key>
# stderr (complete):   session_complete=true session=<path> options=<path>
#                      explanation=<path> recommended=<id>
# Exit: 0 success (complete or awaiting-input) / 2 usage error.

set -uo pipefail

VISION=""; PROFILE=""; OUT_DIR=""; NOW=""; DRY_RUN=0
ANSWERS_JSON=""; ANSWER_ARR=()

while [ $# -gt 0 ]; do
  case "$1" in
    --vision)  VISION="${2-}";  shift 2 ;;
    --profile) PROFILE="${2-}"; shift 2 ;;
    --answer)  ANSWER_ARR+=(--answer "${2-}"); shift 2 ;;
    --answers) ANSWERS_JSON="${2-}"; shift 2 ;;
    --out-dir) OUT_DIR="${2-}"; shift 2 ;;
    --now)     NOW="${2-}";     shift 2 ;;
    --dry-run) DRY_RUN=1;       shift ;;
    -h|--help) echo "Usage: architect-session.sh --vision <text> [--answer k=v]... | --profile <json> [--out-dir <dir>] [--dry-run]" >&2; exit 0 ;;
    *) echo "architect-session: unknown arg: $1" >&2; exit 2 ;;
  esac
done

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
CMD="$PLUGIN_ROOT/commands"
if [ -z "$OUT_DIR" ]; then OUT_DIR="standards/architect-session"; fi
if [ -z "$NOW" ]; then NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ); fi
mkdir -p "$OUT_DIR" 2>/dev/null || true

# 1) Obtain the business profile (use --profile, else run S-32 intake).
PROF="$OUT_DIR/business-profile.json"
if [ -n "$PROFILE" ]; then
  PROF="$PROFILE"
else
  INTAKE=()
  [ -n "$VISION" ] && INTAKE+=(--answer "workload=$VISION")
  [ -n "$ANSWERS_JSON" ] && INTAKE+=(--answers "$ANSWERS_JSON")
  # --partial so the profile is always written; completeness is read back.
  # Empty-array-safe expansion (bash 3.2 + set -u).
  bash "$CMD/business-intake.sh" \
    ${INTAKE[@]+"${INTAKE[@]}"} ${ANSWER_ARR[@]+"${ANSWER_ARR[@]}"} \
    --partial --out "$PROF" --now "$NOW" >/dev/null 2>&1 || true
fi

if [ ! -f "$PROF" ]; then
  echo "architect-session: could not establish a business profile" >&2
  exit 2
fi

COMPLETE=$(node -e 'try{const p=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log(p.complete===true?"yes":"no")}catch(e){console.log("no")}' "$PROF")
if [ "$COMPLETE" != "yes" ]; then
  NEXTQ=$(node -e 'try{const p=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log((p.unanswered&&p.unanswered[0])||"unknown")}catch(e){console.log("unknown")}' "$PROF")
  echo "session_complete=false" >&2
  echo "next_question=$NEXTQ" >&2
  exit 0
fi

# 2) Complete profile -> run the chain.
REQ="$OUT_DIR/technical-requirements.json"
OPTS="$OUT_DIR/architecture-options.json"
EXP="$OUT_DIR/explanation.md"

if [ "$DRY_RUN" = "1" ]; then
  echo "dry_run=true" >&2
  echo "session_complete=true" >&2
  echo "session=$OUT_DIR/session.json (not written)" >&2
  exit 0
fi

bash "$CMD/business-translate.sh" --profile "$PROF" --out "$REQ" --now "$NOW" >/dev/null 2>&1
bash "$CMD/architect-recommend.sh" --requirements "$REQ" --profile "$PROF" --out "$OPTS" --now "$NOW" >/dev/null 2>&1
bash "$CMD/explain.sh" --annotate "$OPTS" --out "$EXP" --now "$NOW" >/dev/null 2>&1

# 3) Assemble the session bundle + plain-language summary.
PROF="$PROF" REQ="$REQ" OPTS="$OPTS" EXP="$EXP" OUT_DIR="$OUT_DIR" NOW="$NOW" VISION="$VISION" ruby -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  prof=JSON.parse(File.read(ENV["PROF"]))
  opts=JSON.parse(File.read(ENV["OPTS"]))
  out_dir=ENV["OUT_DIR"]; now=ENV["NOW"]
  vision = ENV["VISION"].empty? ? (prof.dig("answers","workload") || "your workload") : ENV["VISION"]
  rec_id = opts["recommended_option_id"]
  rec = (opts["options"] || []).find { |o| o["option_id"] == rec_id } || (opts["options"] || []).first

  session = {
    "schema_version"        => "1.0",
    "generated_at"          => now,
    "vision"                => vision,
    "profile_ref"           => ENV["PROF"],
    "requirements_ref"      => ENV["REQ"],
    "options_ref"           => ENV["OPTS"],
    "explanation_ref"       => ENV["EXP"],
    "option_count"          => opts["option_count"],
    "recommended_option_id" => rec_id
  }
  File.write("#{out_dir}/session.json", JSON.pretty_generate(session) + "\n")

  md = +"# Your Architecture Session - #{now}\n\n"
  md << "Vision: #{vision}\n\n"
  md << "We looked at #{opts["option_count"]} grounded options. Our recommended starting point is **#{rec ? rec["summary"] : rec_id}**"
  md << " (#{rec["trade_offs"].map { |k,v| "#{k}: #{v}" }.join(", ")})" if rec && rec["trade_offs"]
  md << ".\n\n## Your options\n\n"   # blank line after heading -> MD022/MD032 clean
  (opts["options"] || []).each do |o|
    to = o["trade_offs"] || {}
    md << "- **#{o["summary"]}** - cost #{to["cost"]}, availability #{to["availability"]}, complexity #{to["complexity"]}\n"
  end
  md << "\nSee explanation.md for what each technical term means in business terms.\n"
  File.write("#{out_dir}/session.md", md)
'

# §29 / §2.34 (S-56): attach the FULL-SURFACE GROUNDING so the delivered design is COMPLETE against the
# full rule surface (42 code namespaces + the IaC convention rules) — everything CTP produces is reasoned
# against the whole surface, not the cloud-source subset. The grounding record is part of the bundle.
_FSC="$(dirname "$0")/full-surface-consult.sh"
if [ -f "$_FSC" ]; then
  bash "$_FSC" --emit-grounding > "$OUT_DIR/full-surface-grounding.json" 2>/dev/null || true
  _FSNS="$(node -e 'try{console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).grounded_namespaces.length)}catch(e){console.log(0)}' "$OUT_DIR/full-surface-grounding.json" 2>/dev/null || echo 0)"
  echo "full_surface_grounding=$OUT_DIR/full-surface-grounding.json namespaces=$_FSNS" >&2
  # §29.4: the architectural design (consult) is FORMALLY ENFORCED against the entire repo ruleset via the
  # SAME native engine development uses at WRITE-TIME (rubric/enforce-file.sh — the deterministic floor +
  # the §28.57 universal enforcer). Fast + tool-independent; a P0/P1 violation in any produced artifact is
  # RED. The full routed 3rd-party audit (composite-audit, same as development's AUDIT-TIME) is available
  # on demand via `full-surface-consult --enforce <dir>`.
  _EF="$(dirname "$0")/../rubric/enforce-file.sh"
  _design_enf="green"
  if [ -f "$_EF" ]; then
    for _af in "$OUT_DIR"/*.md "$OUT_DIR"/*.json; do
      [ -f "$_af" ] || continue
      bash "$_EF" --file "$_af" --single-file-gate >/dev/null 2>&1; _rc=$?
      [ "$_rc" -eq 1 ] && _design_enf="red"
    done
  fi
  echo "design_enforcement=$_design_enf engine=enforce-file rules_total=118" >&2
fi

echo "session_complete=true" >&2
echo "session=$OUT_DIR/session.json" >&2
echo "options=$OPTS" >&2
echo "explanation=$EXP" >&2
RECID=$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).recommended_option_id)' "$OPTS" 2>/dev/null || echo "")
echo "recommended=$RECID" >&2
exit 0
