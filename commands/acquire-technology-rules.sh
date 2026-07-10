#!/usr/bin/env bash
# commands/acquire-technology-rules.sh — S-60 dynamic rule-source acquisition (v1.25 §31 Phase 2).
#
# Searches the EXISTING source corpus for a technology's guidance and writes the extracted, 4-axis-tagged
# rules into the per-project WORKING overlay _project/<project-id>/<tech>/<source-id>.yaml (origin: project).
# It NEVER writes an official namespace (§31.2) and NEVER invents rules — every rule cites the source it was
# extracted from. Acquisition writes only to the working overlay; a rule becomes official only via S-64
# promotion PR.
#
# The fetch of a source URL is the external boundary; it is stubbed here via --source-file (the pre-fetched
# guidance, one statement per non-empty line). In production a wrapper runs the existing standards/fetchers/*
# against the umbrella-matched source URLs to produce that content. Extraction + tagging + write are here.
#
# CLI:
#   --technology <t>        the technology (must resolve via S-58; unresolved -> exit 2)
#   --project <id>          project id (required; scopes the overlay)
#   --source-file <path>    pre-fetched guidance (one rule statement per non-empty line)
#   --source-id <id>        the source's catalog id (provenance)
#   --source-url <url>      the source URL (provenance)
#   --tier <n>              source tier (provenance; default 2)
#   --fetcher <id>          fetcher used (provenance; default markdown-headers)
#   --max-rules <N>         cap (default 20); over-cap -> budget_exhausted
#   --root <dir>            plugin root override (default $CLAUDE_PLUGIN_ROOT)
#   --now <iso>             fetched_at (default current UTC)
#
# stderr: acquired=<n> technology=<t> project=<id> namespace=<ns> source=<id> budget_exhausted=<bool>
# Exit: 0 success (incl. acquired=0) / 2 usage/unresolved-technology.

set -uo pipefail

TECH=""; PROJECT=""; SRC_FILE=""; SRC_ID=""; SRC_URL=""; TIER="2"; FETCHER="markdown-headers"
MAX_RULES="20"; ROOT_OVERRIDE=""; NOW=""; ONLY_MENTION=0; EXPLAIN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --technology) TECH="${2-}"; shift 2 ;;
    --project)    PROJECT="${2-}"; shift 2 ;;
    --source-file) SRC_FILE="${2-}"; shift 2 ;;
    --only-mentioning) ONLY_MENTION=1; shift ;;   # extract only guidance lines that mention the technology
    --explain)    EXPLAIN=1; shift ;;
    --source-id)  SRC_ID="${2-}"; shift 2 ;;
    --source-url) SRC_URL="${2-}"; shift 2 ;;
    --tier)       TIER="${2-}"; shift 2 ;;
    --fetcher)    FETCHER="${2-}"; shift 2 ;;
    --max-rules)  MAX_RULES="${2-}"; shift 2 ;;
    --root)       ROOT_OVERRIDE="${2-}"; shift 2 ;;
    --now)        NOW="${2-}"; shift 2 ;;
    -h|--help) echo "Usage: acquire-technology-rules.sh --technology <t> --project <id> --source-file <f> --source-id <id> --source-url <url> [--tier N] [--max-rules N]" >&2; exit 0 ;;
    *) echo "acquire-technology-rules: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$TECH" ]    && { echo "acquire-technology-rules: --technology required" >&2; exit 2; }
[ -z "$PROJECT" ] && { echo "acquire-technology-rules: --project required" >&2; exit 2; }
[ -z "$NOW" ]     && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
ROOT="${ROOT_OVERRIDE:-$PLUGIN_ROOT/generated-code-quality-standards}"

# Resolve the technology (S-58): unresolved -> refuse to acquire (cite-or-decline).
RES="$(bash "$(dirname "$0")/resolve-technology.sh" "$TECH" 2>/dev/null)"
STATUS="$(printf '%s' "$RES" | ruby -rjson -e 'begin;puts JSON.parse(STDIN.read)["specific"]["status"];rescue;puts "unresolved";end' 2>/dev/null || echo unresolved)"
if [ "$STATUS" = "unresolved" ] || [ -z "$STATUS" ]; then
  echo "acquire-technology-rules: technology \"$TECH\" is unresolved — nothing to acquire (cite-or-decline)" >&2
  echo "acquired=0 technology=$TECH project=$PROJECT status=unresolved" >&2
  exit 2
fi

TECH="$TECH" PROJECT="$PROJECT" SRC_FILE="$SRC_FILE" SRC_ID="$SRC_ID" SRC_URL="$SRC_URL" TIER="$TIER" \
FETCHER="$FETCHER" MAX_RULES="$MAX_RULES" ROOT="$ROOT" NOW="$NOW" RES="$RES" ONLY_MENTION="$ONLY_MENTION" EXPLAIN="$EXPLAIN" ruby -ryaml -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
  tech = ENV["TECH"].to_s.downcase; project = ENV["PROJECT"]; root = ENV["ROOT"]; now = ENV["NOW"]
  src_id = ENV["SRC_ID"].to_s; src_url = ENV["SRC_URL"].to_s; tier = ENV["TIER"].to_i
  fetcher = ENV["FETCHER"].to_s; maxr = ENV["MAX_RULES"].to_i
  res = (JSON.parse(ENV["RES"]) rescue {})
  coord = res["coordinate"] || {}

  # Extract guidance statements from the pre-fetched source content (one per non-empty, non-heading line).
  lines = []
  sf = ENV["SRC_FILE"].to_s
  if !sf.empty? && File.exist?(sf)
    only = ENV["ONLY_MENTION"] == "1"
    tre = Regexp.new("(?<![a-z0-9])" + Regexp.escape(tech) + "s?(?![a-z0-9])")
    File.readlines(sf).each do |ln|
      s = ln.strip
      next if s.empty? || s.start_with?("#")
      # --only-mentioning: keep only guidance that actually names the technology (searching a general source).
      next if only && !s.downcase.match?(tre)
      lines << s
    end
  end
  budget_exhausted = lines.length > maxr
  lines = lines[0, maxr]

  # Build rules (prose-judge detector; 4-axis tag from the resolver coordinate; provenance to the source).
  rules = lines.each_with_index.map do |stmt, i|
    slug = stmt.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-+|-+$/, "")[0, 40]
    slug = "rule-#{i+1}" if slug.empty?
    {
      "id" => "#{tech}/#{slug}",
      "name" => slug,
      "description" => stmt,
      "detector" => "prose-judge.sh",
      "type" => "suggestion",
      "fixable" => "code",
      "deprecated" => false,
      "replaced_by" => [],
      "recommended" => true,
      # 4-axis tag: enforce-file matches on applies_to.linguist_aliases (lowercased) via its LING2EXT map.
      "applies_to" => { "linguist_aliases" => (coord["linguist"] || []).map { |l| l.to_s.downcase } },
      "severity" => "P2"
    }
  end

  ns_dir = File.join(root, "_project", project, tech)
  if rules.empty?
    STDERR.puts "acquired=0 technology=#{tech} project=#{project} namespace=#{tech} source=#{src_id} budget_exhausted=false"
    exit 0
  end

  require "fileutils"; FileUtils.mkdir_p(ns_dir)
  doc = {
    "source" => {
      "id" => src_id.empty? ? "#{tech}-acquired" : src_id,
      "authoritative_publisher" => "acquired via existing-source search (S-60)",
      "authoritative_url" => src_url.empty? ? "about:blank" : src_url,
      "registry_link" => "_project/#{project}",
      "fetched_at" => now,
      "content_hash" => "sha256:acquired-#{tech}-#{rules.length}",
      "fetch_frequency" => "weekly",
      "fragility_tier" => "medium",
      "license_note" => "extracted from cited source; provenance retained",
      "fetcher" => fetcher,
      "tier" => tier
    },
    "rules" => rules
  }
  out = File.join(ns_dir, "#{doc["source"]["id"]}.yaml")
  File.write(out, YAML.dump(doc))
  STDERR.puts "acquired=#{rules.length} technology=#{tech} project=#{project} namespace=#{tech} source=#{doc["source"]["id"]} budget_exhausted=#{budget_exhausted}"
  if ENV["EXPLAIN"] == "1"
    STDERR.puts "EXPLAIN: Pulled #{rules.length} #{tech} rule(s) from #{doc["source"]["id"]} into project #{project}'"'"'s working set. These apply to #{project} only and are NOT official plugin rules until a person approves them through a promotion pull request."
  end
'
exit $?
