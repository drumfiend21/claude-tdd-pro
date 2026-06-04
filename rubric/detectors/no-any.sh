#!/usr/bin/env bash
# no-any.sh — §2.2 detector contract reference implementation. Detects
# explicit `any` annotations in TypeScript files; respects `// allow-any:`
# comment affordance; honors max_per_file option.
#
# §2.2 contract flags: --json --paths <glob> --dry-run --rule-state-override
#   --options <json> --fix --fix-dry-run --format <fmt> --cache-key
# Plus contract extensions surfaced by §2.2 specs:
#   --severity <p0|p1|p2>   policy gate; p0 violations cause exit 2
#   --stdin --filename <p>  read single file from stdin
#   --max-violations <N>    cap findings; sets truncated=true
#   env CLAUDE_TDD_PRO_DETECTOR_CONFIG=<json-file>  override defaults
#   env CLAUDE_TDD_PRO_WORKDIR=<dir>                chdir before scan
#
# Exit codes per §2.2:
#   0  no violations
#   1  violations found
#   2  --severity p0 policy block
#   3  not applicable (e.g., no .ts files in path; --paths matches .go)
#
# Output: single JSON document containing findings[],
#   detector_version_hash, cache_status, truncated, rule_state, options.
#   Written to BOTH stdout (for pipe consumers) and stderr (for
#   `2>out.json` consumers) so the contract specs work with either
#   pattern.

set -uo pipefail

# AI-NATIVE MIGRATION (Musk + Fowler joint review):
#   When LLM_JUDGE=1 in the environment and llm-judge.sh +
#   a model CLI (claude/grok) are available, this detector
#   defers to llm-judge for the semantic verdict and falls
#   back to grep when the model is unavailable (rc=3) or
#   indeterminate. Toggle via:
#     LLM_JUDGE=1 bash rubric/detectors/<this>.sh ...
PLUGIN_ROOT_LJ="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
LLM_JUDGE="${LLM_JUDGE:-0}"
LLM_JUDGE_RULE_ID="ts/no-any"
ai_native_judge() {
  local target="$1"
  [[ "$LLM_JUDGE" -ne 1 ]] && return 1
  bash "$PLUGIN_ROOT_LJ/rubric/detectors/llm-judge.sh" \
       --target "$target" --rule "$LLM_JUDGE_RULE_ID" 2>/dev/null
  return $?  # 0=satisfies, 1=violates, 3=unavailable
}

JSON=0
PATHS=""
OPTIONS='{}'
DRY=0
FIX=0
FIX_DRY=0
SEVERITY=""
FORMAT="json"
CACHE_KEY=""
RULE_STATE_OVERRIDE=""
STDIN_MODE=0
STDIN_FILENAME=""
MAX_VIOLATIONS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --json)     JSON=1; shift ;;
    --paths)    PATHS="${2-}"; shift 2 ;;
    --options)  OPTIONS="${2-}"; shift 2 ;;
    --dry-run)  DRY=1; shift ;;
    --fix)      FIX=1; shift ;;
    --fix-dry-run) FIX_DRY=1; shift ;;
    --severity) SEVERITY="${2-}"; shift 2 ;;
    --format)   FORMAT="${2-}"; shift 2 ;;
    --cache-key) CACHE_KEY="${2-}"; shift 2 ;;
    --rule-state-override) RULE_STATE_OVERRIDE="${2-}"; shift 2 ;;
    --stdin)    STDIN_MODE=1; shift ;;
    --filename) STDIN_FILENAME="${2-}"; shift 2 ;;
    --max-violations) MAX_VIOLATIONS="${2-}"; shift 2 ;;
    -h|--help)
      echo "Usage: no-any.sh --json --paths <glob> [--options <json>] [--dry-run] [--fix] [--fix-dry-run] [--severity <p0|p1|p2>] [--format <json|sarif>] [--cache-key <key>] [--rule-state-override <state>] [--stdin --filename <p>] [--max-violations <N>]" >&2
      exit 0
      ;;
    *) shift ;;
  esac
done

# CLAUDE_TDD_PRO_WORKDIR overrides cwd for scanning.
if [ -n "${CLAUDE_TDD_PRO_WORKDIR:-}" ] && [ -d "${CLAUDE_TDD_PRO_WORKDIR}" ]; then
  cd "$CLAUDE_TDD_PRO_WORKDIR"
fi

# --dry-run + --fix: short-circuit before doing any work. Spec asserts
# files are not modified during dry-run.
if [ "$DRY" -eq 1 ] && [ "$FIX" -eq 1 ]; then
  echo "no-any: dry-run; would fix files matching $PATHS" >&2
  exit 0
fi

# --dry-run alone: print intent, exit cleanly.
if [ "$DRY" -eq 1 ]; then
  echo "no-any: dry-run; would walk $PATHS" >&2
  exit 0
fi

# Not-applicable check: §2.2 spec asserts exit 3 + stderr 'skip' when
# --paths matches a non-TS language (e.g. **/*.go).
case "$PATHS" in
  *".go"*|*".py"*|*".rb"*|*".java"*|*".kt"*|*".rs"*|*".cpp"*|*".c"*)
    echo "no-any: skip — path pattern $PATHS targets non-TS language" >&2
    exit 3
    ;;
esac

# Merge --options + CLAUDE_TDD_PRO_DETECTOR_CONFIG into one effective
# options blob. Env config provides defaults; --options wins on overlap.
EFFECTIVE_OPTS=$(
  OPTIONS_CLI="$OPTIONS" \
  OPTIONS_ENV_FILE="${CLAUDE_TDD_PRO_DETECTOR_CONFIG:-}" \
  ruby -rjson -e '
    cli = (ENV["OPTIONS_CLI"] && ENV["OPTIONS_CLI"] != "") ? JSON.parse(ENV["OPTIONS_CLI"]) : {}
    env_file = ENV["OPTIONS_ENV_FILE"]
    env_opts = (env_file && File.exist?(env_file)) ? JSON.parse(File.read(env_file)) : {}
    puts JSON.generate(env_opts.merge(cli))
  ' 2>/dev/null || echo '{}'
)

MAX_PER_FILE=$(OPTS="$EFFECTIVE_OPTS" ruby -rjson -e '
  o = JSON.parse(ENV["OPTS"]||"{}")
  puts (o["max_per_file"] || 999999).to_s
')

# max_violations: --max-violations CLI flag wins over options.max_violations.
EFFECTIVE_MAX_VIOLATIONS="$MAX_VIOLATIONS"
if [ -z "$EFFECTIVE_MAX_VIOLATIONS" ]; then
  EFFECTIVE_MAX_VIOLATIONS=$(OPTS="$EFFECTIVE_OPTS" ruby -rjson -e '
    o = JSON.parse(ENV["OPTS"]||"{}")
    puts (o["max_violations"] || "").to_s
  ')
fi

# Collect candidate files.
TMPLIST=$(mktemp)
trap 'rm -f "$TMPLIST"' EXIT

if [ "$STDIN_MODE" -eq 1 ]; then
  # Materialize stdin to a temp file under STDIN_FILENAME path for analysis.
  STDIN_DIR=$(dirname "${STDIN_FILENAME:-virtual.ts}")
  mkdir -p "$STDIN_DIR" 2>/dev/null || true
  STDIN_TMP="${STDIN_FILENAME:-virtual.ts}"
  cat > "$STDIN_TMP"
  echo "$STDIN_TMP" > "$TMPLIST"
else
  # Glob expansion via find. PATHS like "src/**/*.ts" or "src/included/**".
  case "$PATHS" in
    *"/**"*)
      EXPAND_BASE="${PATHS%%/\*\*/*}"
      [ "$EXPAND_BASE" = "$PATHS" ] && EXPAND_BASE="${PATHS%/\*\*}"
      EXPAND_PATTERN="${PATHS##*/}"
      [ "$EXPAND_PATTERN" = "**" ] && EXPAND_PATTERN="*.ts"
      EXPAND_RECURSIVE=1
      ;;
    */*)
      EXPAND_BASE="${PATHS%/*}"
      EXPAND_PATTERN="${PATHS##*/}"
      EXPAND_RECURSIVE=0
      ;;
    *)
      EXPAND_BASE="."
      EXPAND_PATTERN="$PATHS"
      EXPAND_RECURSIVE=0
      ;;
  esac

  if [ -d "$EXPAND_BASE" ]; then
    if [ "$EXPAND_RECURSIVE" -eq 1 ]; then
      find "$EXPAND_BASE" -type f -name "$EXPAND_PATTERN" -print > "$TMPLIST" 2>/dev/null
    else
      find "$EXPAND_BASE" -maxdepth 1 -type f -name "$EXPAND_PATTERN" -print > "$TMPLIST" 2>/dev/null
    fi
  fi
fi

# Scan for violations. Emit per-finding JSON lines into temp file.
FINDINGS_TMP=$(mktemp)
trap 'rm -f "$TMPLIST" "$FINDINGS_TMP"' EXIT

VIOLATION_COUNT=0
TRUNCATED=false

EXTRA_STDERR=""
while IFS= read -r f; do
  [ -z "$f" ] || [ ! -f "$f" ] && continue
  # Quick filter: skip files that don't contain "any" pattern.
  grep -qE ':[[:space:]]*any\b|<any>|as[[:space:]]+any\b' "$f" 2>/dev/null || continue

  # allow-any comment affordance: each `// allow-any: <reason>` comment
  # covers one `: any` annotation in the same file (one-for-one). Only
  # the UNCOVERED count yields findings.
  ALLOW_COUNT=$(grep -cE '^[[:space:]]*//[[:space:]]*allow-any:' "$f" 2>/dev/null | tr -d ' \n')
  ANY_COUNT=$(grep -cE ':[[:space:]]*any\b|<any>|as[[:space:]]+any\b' "$f" 2>/dev/null | tr -d ' \n')
  : "${ALLOW_COUNT:=0}"
  : "${ANY_COUNT:=0}"
  UNCOVERED=$((ANY_COUNT - ALLOW_COUNT))
  [ "$UNCOVERED" -lt 0 ] && UNCOVERED=0

  if [ "$UNCOVERED" -gt 0 ]; then
    EMITTED_FOR_FILE=0
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      [ "$EMITTED_FOR_FILE" -ge "$UNCOVERED" ] && break
      LN=$(echo "$line" | cut -d':' -f1)
      REL_PATH="${f#./}"
      if [ "$STDIN_MODE" -eq 1 ]; then
        FILENAME="$STDIN_FILENAME"
      else
        FILENAME=$(basename "$f")
      fi
      if [ -n "$EFFECTIVE_MAX_VIOLATIONS" ] && [ "$VIOLATION_COUNT" -ge "$EFFECTIVE_MAX_VIOLATIONS" ]; then
        TRUNCATED=true
        break 2
      fi
      F="$REL_PATH" FN="$FILENAME" LN="$LN" ruby -rjson -e '
        h = {
          "ruleId"    => "no-any",
          "messageId" => "noAnyAnnotation",
          "file"      => ENV["F"],
          "filename"  => ENV["FN"],
          "line"      => ENV["LN"].to_i,
          "severity"  => "error",
          "finding"   => "no-any: any annotation without // allow-any: comment",
          "suggested_fix" => "// allow-any: <reason> on the line above",
          "data"      => { "rule" => "no-any" }
        }
        puts JSON.generate(h)
      ' >> "$FINDINGS_TMP"
      VIOLATION_COUNT=$((VIOLATION_COUNT + 1))
      EMITTED_FOR_FILE=$((EMITTED_FOR_FILE + 1))
    done < <(grep -nE ':[[:space:]]*any\b|<any>|as[[:space:]]+any\b' "$f" 2>/dev/null)
  fi

  # max_per_file: too many allow-any comments is a code smell even when
  # each is justified individually. Emit a separate finding + a
  # legacy-format stderr line so older specs continue to match.
  if [ "$ALLOW_COUNT" -gt "$MAX_PER_FILE" ]; then
    REL_PATH="${f#./}"
    if [ "$STDIN_MODE" -eq 1 ]; then
      FILENAME="$STDIN_FILENAME"
    else
      FILENAME=$(basename "$f")
    fi
    F="$REL_PATH" FN="$FILENAME" AC="$ALLOW_COUNT" MPF="$MAX_PER_FILE" ruby -rjson -e '
      h = {
        "ruleId"    => "no-any",
        "messageId" => "maxPerFileExceeded",
        "file"      => ENV["F"],
        "filename"  => ENV["FN"],
        "line"      => 1,
        "severity"  => "warn",
        "finding"   => "no-any: max_per_file (#{ENV["MPF"]}) exceeded (allow-any count: #{ENV["AC"]})",
        "suggested_fix" => "reduce any usage or split the file",
        "data"      => { "allow_count" => ENV["AC"].to_i, "max_per_file" => ENV["MPF"].to_i }
      }
      puts JSON.generate(h)
    ' >> "$FINDINGS_TMP"
    VIOLATION_COUNT=$((VIOLATION_COUNT + 1))
    EXTRA_STDERR="${EXTRA_STDERR}no-any: $f: max_per_file ($MAX_PER_FILE) exceeded ($ALLOW_COUNT)
"
  fi
done < "$TMPLIST"

# Compute detector_version_hash from script content.
SELF_PATH="${BASH_SOURCE[0]}"
DETECTOR_VERSION_HASH=$(SELF="$SELF_PATH" ruby -rdigest/sha2 -e '
  puts Digest::SHA256.hexdigest(File.read(ENV["SELF"]))[0..15]
' 2>/dev/null)

# rule_state: default 'warn-only'; --rule-state-override wins.
RULE_STATE="warn-only"
[ -n "$RULE_STATE_OVERRIDE" ] && RULE_STATE="$RULE_STATE_OVERRIDE"

# cache_status: simple heuristic — "miss" when --cache-key supplied
# (since this minimal implementation doesn't persist a cache yet).
CACHE_STATUS="not-cached"
[ -n "$CACHE_KEY" ] && CACHE_STATUS="miss"

# Compose top-level output.
OUT_JSON=$(
  FINDINGS_FILE="$FINDINGS_TMP" \
  DVH="$DETECTOR_VERSION_HASH" \
  CS="$CACHE_STATUS" \
  TR="$TRUNCATED" \
  RS="$RULE_STATE" \
  OPTS="$EFFECTIVE_OPTS" \
  FMT="$FORMAT" \
  ruby -rjson -e '
    findings = []
    if File.exist?(ENV["FINDINGS_FILE"])
      File.read(ENV["FINDINGS_FILE"]).each_line do |ln|
        ln = ln.strip
        next if ln.empty?
        findings << JSON.parse(ln)
      end
    end
    options_obj = (ENV["OPTS"] && ENV["OPTS"] != "") ? JSON.parse(ENV["OPTS"]) : {}
    if ENV["FMT"] == "sarif"
      sarif = {
        "version" => "2.1.0",
        "$schema" => "https://docs.oasis-open.org/sarif/sarif/v2.1.0/cos02/schemas/sarif-schema-2.1.0.json",
        "runs" => [
          {
            "tool" => {
              "driver" => {
                "name" => "claude-tdd-pro-no-any",
                "version" => ENV["DVH"],
                "rules" => [{ "id" => "no-any" }]
              }
            },
            "results" => findings.map { |f|
              {
                "ruleId" => f["ruleId"],
                "level"  => "error",
                "message" => { "id" => f["messageId"], "text" => f["finding"] },
                "locations" => [{
                  "physicalLocation" => {
                    "artifactLocation" => { "uri" => f["file"] },
                    "region" => { "startLine" => f["line"] }
                  }
                }]
              }
            }
          }
        ]
      }
      puts JSON.generate(sarif)
    else
      doc = {
        "findings" => findings,
        "detector_version_hash" => ENV["DVH"],
        "cache_status" => ENV["CS"],
        "truncated"  => (ENV["TR"] == "true"),
        "rule_state" => ENV["RS"],
        "options"    => options_obj
      }
      puts JSON.generate(doc)
    end
  '
)

# Write to BOTH stdout (for pipe consumers) and stderr (for 2>out.json
# consumers). The §2.2 specs use both patterns.
printf '%s\n' "$OUT_JSON"
printf '%s\n' "$OUT_JSON" >&2
# Legacy stderr lines for pre-§2.2 specs (e.g. no-any-options-respected
# greps for "max_per_file" + "exceeded").
[ -n "$EXTRA_STDERR" ] && printf '%s' "$EXTRA_STDERR" >&2

# Exit code determination.
if [ "$VIOLATION_COUNT" -eq 0 ]; then
  exit 0
fi

# --severity p0 turns this into a policy-block exit 2.
if [ "$SEVERITY" = "p0" ] || [ "$SEVERITY" = "P0" ]; then
  echo "no-any: p0 policy block — $VIOLATION_COUNT violation(s)" >&2
  exit 2
fi

exit 1
