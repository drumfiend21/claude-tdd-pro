#!/usr/bin/env bash
# commands/acquire-technology-live.sh — S-60 production-fetch wrapper (v1.26 §31, GCTP item 2b).
#
# The production orchestrator over acquire-technology-rules.sh: instead of a single hand-passed --source-file,
# it resolves the technology's umbrella, selects the EXISTING source-catalog entries that apply to that
# umbrella (the "search the same sources" model, §31.1), reads each source's fetched content from the fetch
# cache (populated by standards/fetchers/* against the source URLs — the harness owns the network download),
# and feeds each into acquire-technology-rules.sh. The result is the full acquire lifecycle from a technology
# name + a cache dir, with no hand-managed --source-file.
#
# Cache contract: <cache>/<source-id>.txt holds the fetched guidance for that source (one statement per line).
# In production the harness runs standards/fetcher.sh per source URL to populate it; here it is a plain dir so
# the orchestration is deterministic and testable without live network.
#
# CLI:
#   --technology <t>        (required) must resolve via S-58
#   --project <id>          (required) scopes the working overlay
#   --cache <dir>           (required) dir of <source-id>.txt fetched-content files
#   --sources <yaml>        source catalog(s); repeatable (default: the standard standards/*sources*.yaml set)
#   --max-sources <N>       cap the number of umbrella-matched sources searched (default 8)
#   --root <dir>            plugin root override (passed through to acquire)
#   --now <iso>
#
# stderr: sources_matched=<n> sources_fetched=<m> acquired_total=<k> technology=<t> project=<id>
# Exit: 0 success (incl. acquired_total=0) / 2 usage/unresolved.

set -uo pipefail

TECH=""; PROJECT=""; CACHE=""; MAXS="8"; ROOT_OVERRIDE=""; NOW=""; SOURCES=(); THRESHOLD="30"; TECH_SRC_REG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --technology) TECH="${2-}"; shift 2 ;;
    --project)    PROJECT="${2-}"; shift 2 ;;
    --cache)      CACHE="${2-}"; shift 2 ;;
    --sources)    SOURCES+=("${2-}"); shift 2 ;;
    --max-sources) MAXS="${2-}"; shift 2 ;;
    --threshold)  THRESHOLD="${2-}"; shift 2 ;;   # P-18 sufficiency floor (default 30)
    --tech-source-registry) TECH_SRC_REG="${2-}"; shift 2 ;;
    --root)       ROOT_OVERRIDE="${2-}"; shift 2 ;;
    --now)        NOW="${2-}"; shift 2 ;;
    -h|--help) echo "Usage: acquire-technology-live.sh --technology <t> --project <id> --cache <dir> [--max-sources N]" >&2; exit 0 ;;
    *) echo "acquire-technology-live: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$TECH" ]    && { echo "acquire-technology-live: --technology required" >&2; exit 2; }
[ -z "$PROJECT" ] && { echo "acquire-technology-live: --project required" >&2; exit 2; }
[ -z "$CACHE" ]   && { echo "acquire-technology-live: --cache <dir> required" >&2; exit 2; }
[ -z "$NOW" ]     && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
HERE="$(dirname "$0")"
if [ "${#SOURCES[@]}" -eq 0 ]; then
  for f in sources cloud-architecture-sources cloud-engineering-sources data-architecture-sources distributed-systems-sources eo-security-sources; do
    [ -f "$PLUGIN_ROOT/standards/$f.yaml" ] && SOURCES+=("$PLUGIN_ROOT/standards/$f.yaml")
  done
fi

# Resolve the technology -> umbrella-activated EXISTING namespaces (the umbrella match set).
RES="$(bash "$HERE/resolve-technology.sh" "$TECH" 2>/dev/null)"
STATUS="$(printf '%s' "$RES" | ruby -rjson -e 'begin;puts JSON.parse(STDIN.read)["specific"]["status"];rescue;puts "unresolved";end' 2>/dev/null || echo unresolved)"
if [ "$STATUS" = "unresolved" ] || [ -z "$STATUS" ]; then
  echo "acquire-technology-live: technology \"$TECH\" is unresolved — nothing to acquire (cite-or-decline)" >&2
  echo "sources_matched=0 sources_fetched=0 acquired_total=0 technology=$TECH project=$PROJECT status=unresolved" >&2
  exit 2
fi

# Select umbrella-matched sources: those whose applies_to intersects the activated namespaces.
MATCHED="$(RES="$RES" SRCS="${SOURCES[*]}" MAXS="$MAXS" ruby -ryaml -rjson -e '
  res = JSON.parse(ENV["RES"]); acts = (res["activated_namespaces"] || [])
  out = []
  ENV["SRCS"].split(" ").each do |cf|
    next unless File.exist?(cf)
    d = (YAML.unsafe_load_file(cf) rescue nil); next unless d.is_a?(Array)
    d.each do |e|
      next unless e.is_a?(Hash) && e["id"]
      at = (e["applies_to"] || []).map(&:to_s)
      # match if the source applies to any umbrella namespace, OR to the technology umbrella itself
      if !(at & (acts + res["umbrellas"].to_a)).empty?
        out << [e["id"], (e["url"] || e["authoritative_url"] || ""), (e["tier"] || 2)].join("\t")
      end
    end
  end
  puts out.uniq.first(ENV["MAXS"].to_i).join("\n")
' 2>/dev/null)"

MATCHED_N=0; FETCHED_N=0; ACQ_TOTAL=0

# P-18 whole-source acquisition of the technology's OWN CANONICAL sources (tech-source-registry). The entire
# source is tech-specific, so acquire it WHOLE (no --only-mentioning) with no artificial cap — this is the
# bulk of the ≥threshold rules.
[ -z "$TECH_SRC_REG" ] && TECH_SRC_REG="$PLUGIN_ROOT/standards/technology-source-registry.yaml"
CANON="$(TECH="$TECH" REG="$TECH_SRC_REG" ruby -ryaml -e '
  t=ENV["TECH"].downcase; reg=(YAML.unsafe_load_file(ENV["REG"]) rescue {}) || {}
  ((reg["technologies"]||{})[t]||[]).each { |s| puts [s["source_id"], (s["url"]||""), (s["tier"]||1)].join("\t") }
' 2>/dev/null)"
if [ -n "$CANON" ]; then
  while IFS=$'\t' read -r sid surl stier; do
    [ -z "$sid" ] && continue
    MATCHED_N=$((MATCHED_N+1))
    content="$CACHE/$sid.txt"
    [ -f "$content" ] || continue
    FETCHED_N=$((FETCHED_N+1))
    A_ARGS=(--technology "$TECH" --project "$PROJECT" --source-file "$content" --source-id "$sid" --source-url "$surl" --tier "$stier" --fetcher html-anchor --max-rules 500 --now "$NOW")   # WHOLE source, no --only-mentioning
    [ -n "$ROOT_OVERRIDE" ] && A_ARGS+=(--root "$ROOT_OVERRIDE")
    n="$(bash "$HERE/acquire-technology-rules.sh" "${A_ARGS[@]}" 2>&1 | grep -oE 'acquired=[0-9]+' | grep -oE '[0-9]+' | head -1)"
    ACQ_TOTAL=$((ACQ_TOTAL + ${n:-0}))
  done <<EOF
$CANON
EOF
fi

# Umbrella-general sources: searched with --only-mentioning (only tech-mentioning guidance becomes a rule).
if [ -n "$MATCHED" ]; then
  while IFS=$'\t' read -r sid surl stier; do
    [ -z "$sid" ] && continue
    MATCHED_N=$((MATCHED_N+1))
    content="$CACHE/$sid.txt"
    [ -f "$content" ] || continue
    FETCHED_N=$((FETCHED_N+1))
    A_ARGS=(--technology "$TECH" --project "$PROJECT" --source-file "$content" --source-id "$sid" --source-url "$surl" --tier "$stier" --fetcher html-anchor --only-mentioning --max-rules 500 --now "$NOW")
    [ -n "$ROOT_OVERRIDE" ] && A_ARGS+=(--root "$ROOT_OVERRIDE")
    n="$(bash "$HERE/acquire-technology-rules.sh" "${A_ARGS[@]}" 2>&1 | grep -oE 'acquired=[0-9]+' | grep -oE '[0-9]+' | head -1)"
    ACQ_TOTAL=$((ACQ_TOTAL + ${n:-0}))
  done <<EOF
$MATCHED
EOF
fi

# P-18 sufficiency signal: rule_count + whether it meets the operator's ≥threshold floor.
if [ "$ACQ_TOTAL" -ge "$THRESHOLD" ]; then SUFF="ok"; else SUFF="below-threshold-$THRESHOLD"; fi
echo "sources_matched=$MATCHED_N sources_fetched=$FETCHED_N acquired_total=$ACQ_TOTAL rule_count=$ACQ_TOTAL sufficiency=$SUFF technology=$TECH project=$PROJECT" >&2
exit 0
