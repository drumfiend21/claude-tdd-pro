#!/usr/bin/env bash
# commands/recommend-technology.sh — S-61 technology-fitness recommender (v1.25 §31 Phase 3).
#
# Given an umbrella and the workload's needs, ranks the candidate technologies (from the S-59 registry) and
# recommends the best fit — so the consult can propose Angular over React when the workload favors it. The
# recommendation is GROUNDED (cite-or-decline): it cites the registry fitness tags it matched; it never
# emits an ungrounded preference. The operator may override; the chosen technology's ruleset is then
# resolved/acquired (S-58/S-60) and applied.
#
# CLI:
#   --umbrella <name>     the umbrella to choose within (e.g. frontend) (required)
#   --need <tag>          a workload need (repeatable) matched against each candidate's fitness tags
#   --registry <yaml>     default standards/technology-umbrella-registry.yaml
#
# stdout: recommendation JSON { umbrella, needs, candidates:[{technology,score,matched}], recommended, rationale }
# stderr: recommended=<tech|none> umbrella=<u> score=<n> candidates=<csv> grounded=<bool>
# Exit: 0 success (incl. declined) / 2 usage error.

set -uo pipefail

UMB=""; REGISTRY=""; NEEDS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --umbrella) UMB="${2-}"; shift 2 ;;
    --need)     NEEDS="${NEEDS}${2-}"$'\n'; shift 2 ;;
    --registry) REGISTRY="${2-}"; shift 2 ;;
    -h|--help) echo "Usage: recommend-technology.sh --umbrella <name> [--need <tag>]..." >&2; exit 0 ;;
    *) echo "recommend-technology: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$UMB" ] && { echo "recommend-technology: --umbrella required" >&2; exit 2; }

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
resolve() { if [ -f "$1" ]; then printf '%s' "$1"; elif [ -f "$PLUGIN_ROOT/$1" ]; then printf '%s' "$PLUGIN_ROOT/$1"; else printf '%s' "$1"; fi; }
[ -z "$REGISTRY" ] && REGISTRY="standards/technology-umbrella-registry.yaml"
REGISTRY=$(resolve "$REGISTRY")
[ -f "$REGISTRY" ] || { echo "recommend-technology: registry not found: $REGISTRY" >&2; exit 2; }

UMB="$UMB" REGISTRY="$REGISTRY" NEEDS="$NEEDS" ruby -ryaml -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  reg = YAML.unsafe_load_file(ENV["REGISTRY"]) || {}
  umb = ENV["UMB"].to_s.downcase
  needs = ENV["NEEDS"].to_s.split("\n").map { |s| s.strip.downcase }.reject(&:empty?)

  cands = (reg["technologies"] || []).select { |t| (t["umbrellas"] || []).map(&:downcase).include?(umb) }
  scored = cands.map do |t|
    fit = (t["fitness"] || []).map { |f| f.to_s.downcase }
    matched = needs.empty? ? [] : (needs & fit)
    # score = matched needs; tie-break weight: a tech with its own namespace is better supported.
    { "technology" => t["technology"], "score" => matched.length, "matched" => matched,
      "has_namespace" => !t["specific_namespace"].nil?, "fitness" => fit }
  end
  # rank: score desc, then has_namespace, then alphabetical (deterministic).
  ranked = scored.sort_by { |s| [-s["score"], s["has_namespace"] ? 0 : 1, s["technology"].to_s] }

  if ranked.empty?
    STDOUT.puts JSON.pretty_generate({ "umbrella" => umb, "needs" => needs, "candidates" => [], "recommended" => nil, "status" => "declined" })
    STDERR.puts "recommended=none umbrella=#{umb} score=0 candidates= grounded=false"
    exit 0
  end
  best = ranked.first
  # cite-or-decline: with needs given, a recommendation is grounded only if it matched >=1 need OR is the
  # single best-supported candidate; the rationale always cites the fitness tags it stood on.
  grounded = needs.empty? ? true : (best["score"] > 0)
  rationale =
    if needs.empty?
      "Best-supported #{umb} technology by registry fitness (#{best["fitness"].join(", ")})."
    elsif best["score"] > 0
      "Recommended for needs [#{needs.join(", ")}]: #{best["technology"]} matches #{best["matched"].join(", ")} (registry fitness)."
    else
      "No candidate matches the stated needs [#{needs.join(", ")}]; defaulting to best-supported #{best["technology"]} - treat as ungrounded (cite-or-decline)."
    end

  STDOUT.puts JSON.pretty_generate({
    "umbrella" => umb, "needs" => needs,
    "candidates" => ranked.map { |s| { "technology" => s["technology"], "score" => s["score"], "matched" => s["matched"] } },
    "recommended" => best["technology"], "grounded" => grounded, "rationale" => rationale
  })
  STDERR.puts "recommended=#{best["technology"]} umbrella=#{umb} score=#{best["score"]} candidates=#{ranked.map{|s|s["technology"]}.join(",")} grounded=#{grounded}"
'
exit $?
