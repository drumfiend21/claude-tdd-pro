#!/usr/bin/env bash
# commands/promote-project-rule.sh — S-64 promote a working rule to official via PR (v1.25 §31 Phase 3).
#
# Promotion is a MOVE, working -> official (§31.2): a rule becomes official ONLY through an approved PR that
# moves it from _project/<project-id>/<ns>/ (origin project) to generated-code-quality-standards/<ns>/
# (origin plugin). This command does NOT accept the rule — it prepares/opens the PR; acceptance is the human
# code review + merge. `release` removes a rule from the working overlay (the working-layer counterpart of
# the official removal PR).
#
# Modes:
#   --plan (default)   print the move plan (from/to/rule) to stdout; write nothing. Testable, side-effect-free.
#   --apply            perform the file MOVE locally (working -> official) — stages the change a PR carries.
#                      (In production this runs on a promotion branch; the PR + review + merge are the gate.)
#   --release          remove the working-overlay source file instead of promoting (working-layer removal).
#
# CLI:
#   --project <id>         project id (required)
#   --namespace <ns>       the working namespace (e.g. vue) (required)
#   --source <id>          the working source-file id (default: the only file in the ns)
#   --root <dir>           plugin root override (default $CLAUDE_PLUGIN_ROOT)
#   --plan | --apply | --release
#
# stderr: promotion=<ns/source> from=<path> to=<path> mode=<plan|apply|release> moved=<bool>
# Exit: 0 success / 2 usage / 3 working rule not found.

set -uo pipefail

PROJECT=""; NS=""; SRC=""; ROOT_OVERRIDE=""; MODE="plan"; EXPLAIN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --project)   PROJECT="${2-}"; shift 2 ;;
    --namespace) NS="${2-}"; shift 2 ;;
    --source)    SRC="${2-}"; shift 2 ;;
    --root)      ROOT_OVERRIDE="${2-}"; shift 2 ;;
    --plan)      MODE="plan"; shift ;;
    --apply)     MODE="apply"; shift ;;
    --release)   MODE="release"; shift ;;
    --explain)   EXPLAIN=1; shift ;;
    -h|--help) echo "Usage: promote-project-rule.sh --project <id> --namespace <ns> [--source <id>] [--plan|--apply|--release]" >&2; exit 0 ;;
    *) echo "promote-project-rule: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$PROJECT" ] && { echo "promote-project-rule: --project required" >&2; exit 2; }
[ -z "$NS" ]      && { echo "promote-project-rule: --namespace required" >&2; exit 2; }

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
ROOT="${ROOT_OVERRIDE:-$PLUGIN_ROOT/generated-code-quality-standards}"
WORK_DIR="$ROOT/_project/$PROJECT/$NS"
[ -d "$WORK_DIR" ] || { echo "promote-project-rule: no working overlay at $WORK_DIR" >&2; exit 3; }

# Pick the working source file.
if [ -n "$SRC" ]; then
  FROM="$WORK_DIR/$SRC.yaml"
else
  FROM="$(ls "$WORK_DIR"/*.yaml 2>/dev/null | head -1)"
fi
[ -n "$FROM" ] && [ -f "$FROM" ] || { echo "promote-project-rule: no working source file in $WORK_DIR" >&2; exit 3; }
BASE="$(basename "$FROM")"
TO="$ROOT/$NS/$BASE"    # official destination (origin: plugin)

case "$MODE" in
  plan)
    echo "{"                                              >  /dev/stdout
    echo "  \"mode\": \"plan\","                          >> /dev/stdout
    echo "  \"rule_source\": \"$NS/${BASE%.yaml}\","      >> /dev/stdout
    echo "  \"from\": \"_project/$PROJECT/$NS/$BASE\","   >> /dev/stdout
    echo "  \"to\": \"$NS/$BASE\","                       >> /dev/stdout
    echo "  \"action\": \"move (working -> official), via reviewed PR; origin project -> plugin\""  >> /dev/stdout
    echo "}"                                              >> /dev/stdout
    echo "promotion=$NS/${BASE%.yaml} from=_project/$PROJECT/$NS/$BASE to=$NS/$BASE mode=plan moved=false" >&2
    [ "$EXPLAIN" = 1 ] && echo "EXPLAIN: This would open a pull request to move the $NS rule from project $PROJECT's working set into the official plugin rules. Nothing changes until a reviewer approves and merges that PR. (Run with --apply to stage the move on a branch.)" >&2
    ;;
  apply)
    mkdir -p "$ROOT/$NS"
    # MOVE (not copy): official gains the file (origin flips to plugin when re-aggregated), working loses it.
    mv "$FROM" "$TO"
    # drop the now-stale project_id/origin overrides so the promoted file reads as an official source file
    if command -v ruby >/dev/null 2>&1; then
      ruby -ryaml -e 'f=ARGV[0]; d=YAML.unsafe_load_file(f); (d["rules"]||[]).each{|r| r.delete("project_id"); r.delete("origin")}; File.write(f, YAML.dump(d))' "$TO" 2>/dev/null || true
    fi
    rmdir "$WORK_DIR" 2>/dev/null || true
    echo "promotion=$NS/${BASE%.yaml} from=_project/$PROJECT/$NS/$BASE to=$NS/$BASE mode=apply moved=true" >&2
    [ "$EXPLAIN" = 1 ] && echo "EXPLAIN: Moved the $NS rule from project $PROJECT's working set into the official rules folder on this branch — ready for a review pull request. It is not shared globally until that PR merges." >&2
    ;;
  release)
    rm -f "$FROM"
    rmdir "$WORK_DIR" 2>/dev/null || true
    echo "promotion=$NS/${BASE%.yaml} from=_project/$PROJECT/$NS/$BASE to= mode=release moved=true" >&2
    [ "$EXPLAIN" = 1 ] && echo "EXPLAIN: Removed the $NS rule from project $PROJECT's working set. It was never official, so nothing global is affected." >&2
    ;;
esac
exit 0
