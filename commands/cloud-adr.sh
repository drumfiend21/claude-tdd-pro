#!/usr/bin/env bash
# commands/cloud-adr.sh — S-28 cloud-architecture ADR generator (v1.12 §27.11).
#
# Generates a MADR-conformant Architecture Decision Record per the §2.16
# decision-provenance schema for a cloud design decision, grounded in the
# S-23 cloud-architecture sources that cover the decision's Well-Architected
# pillar (reusing the S-26 pillar->source mapping). Introduces no new ADR
# schema; emits a §2.16-format ADR + json sidecar.
#
# Filename conforms to the §2.16 pattern ^[0-9]{4}-[a-z0-9-]+\.md$.
#
# CLI:
#   --title <text>        decision title (required)
#   --pillar <p>          Well-Architected pillar the decision concerns (required)
#   --decision <text>     the chosen option (required)
#   --options <csv>       considered options (comma-separated)
#   --rationale <text>    why the decision was made
#   --slug <slug>         kebab slug (default derived from the title)
#   --seq <NNNN>          4-digit ADR sequence number (default 0001)
#   --status <s>          proposed|accepted|rejected|superseded|deprecated
#                         (default proposed)
#   --catalog <path>      cloud-architecture catalog
#                         (default standards/cloud-architecture-sources.yaml)
#   --out-dir <dir>       output dir (default docs/adr)
#   --now <iso>           ADR date (default current UTC date)
#   --dry-run             preview to stderr; write no files (§2.14)
#
# stderr: adr_md=<path> adr_json=<path> status=<s> pillar=<p>
#         grounding=<grounded|needs_grounding> sources=<csv>
# Exit: 0 success / 2 usage error.

set -uo pipefail

TITLE=""; PILLAR=""; DECISION=""; OPTIONS=""; RATIONALE=""
SLUG=""; SEQ="0001"; STATUS="proposed"; CATALOG=""; OUT_DIR=""; NOW=""; DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --title)     TITLE="${2-}";     shift 2 ;;
    --pillar)    PILLAR="${2-}";    shift 2 ;;
    --decision)  DECISION="${2-}";  shift 2 ;;
    --options)   OPTIONS="${2-}";   shift 2 ;;
    --rationale) RATIONALE="${2-}"; shift 2 ;;
    --slug)      SLUG="${2-}";      shift 2 ;;
    --seq)       SEQ="${2-}";       shift 2 ;;
    --status)    STATUS="${2-}";    shift 2 ;;
    --catalog)   CATALOG="${2-}";   shift 2 ;;
    --out-dir)   OUT_DIR="${2-}";   shift 2 ;;
    --now)       NOW="${2-}";       shift 2 ;;
    --dry-run)   DRY_RUN=1;         shift ;;
    -h|--help)
      echo "Usage: cloud-adr.sh --title <t> --pillar <p> --decision <d> [--options <csv>] [--rationale <t>] [--slug <s>] [--seq <NNNN>] [--status <s>] [--catalog <path>] [--out-dir <dir>] [--now <iso>] [--dry-run]" >&2
      exit 0
      ;;
    *) echo "cloud-adr: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$TITLE" ];    then echo "cloud-adr: --title is required" >&2; exit 2; fi
if [ -z "$PILLAR" ];   then echo "cloud-adr: --pillar is required" >&2; exit 2; fi
if [ -z "$DECISION" ]; then echo "cloud-adr: --decision is required" >&2; exit 2; fi
case "$STATUS" in
  proposed|accepted|rejected|superseded|deprecated) ;;
  *) echo "cloud-adr: invalid --status $STATUS (proposed|accepted|rejected|superseded|deprecated)" >&2; exit 2 ;;
esac

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
if [ -z "$CATALOG" ]; then CATALOG="standards/cloud-architecture-sources.yaml"; fi
if [ ! -f "$CATALOG" ] && [ -f "$PLUGIN_ROOT/$CATALOG" ]; then CATALOG="$PLUGIN_ROOT/$CATALOG"; fi
if [ -z "$OUT_DIR" ]; then OUT_DIR="docs/adr"; fi
if [ -z "$NOW" ]; then NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ); fi

# Derive a kebab slug from the title when not given.
if [ -z "$SLUG" ]; then
  SLUG=$(printf '%s' "$TITLE" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed -E 's/^-+//; s/-+$//')
fi
# Normalize seq to 4 digits.
SEQ=$(printf '%04d' "$((10#${SEQ:-1}))" 2>/dev/null || printf '%s' "$SEQ")

TITLE="$TITLE" PILLAR="$PILLAR" DECISION="$DECISION" OPTIONS="$OPTIONS" RATIONALE="$RATIONALE" \
SLUG="$SLUG" SEQ="$SEQ" STATUS="$STATUS" CATALOG="$CATALOG" OUT_DIR="$OUT_DIR" NOW="$NOW" DRY_RUN="$DRY_RUN" \
ruby -ryaml -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
  title=ENV["TITLE"]; pillar=ENV["PILLAR"]; decision=ENV["DECISION"]
  options=ENV["OPTIONS"]; rationale=ENV["RATIONALE"]; slug=ENV["SLUG"]
  seq=ENV["SEQ"]; status=ENV["STATUS"]; catalog=ENV["CATALOG"]
  out_dir=ENV["OUT_DIR"]; now=ENV["NOW"]; dry_run=ENV["DRY_RUN"]=="1"

  # Grounding sources for the pillar (from the S-23 catalog pillars field).
  sources=[]
  doc = begin; YAML.unsafe_load_file(catalog); rescue; nil; end
  if doc.is_a?(Array)
    doc.each do |e|
      next unless e.is_a?(Hash) && e["id"] && e["pillars"].is_a?(Array)
      sources << e["id"] if e["pillars"].include?(pillar)
    end
  end
  sources = sources.sort.uniq
  grounding = sources.empty? ? "needs_grounding" : "grounded"

  considered = options.to_s.split(",").map(&:strip).reject(&:empty?)
  considered = [decision] if considered.empty?

  # MADR-format ADR (§2.16 fields).
  md = +""
  md << "# #{seq}. #{title}\n\n"
  md << "- Status: #{status}\n"
  md << "- Date: #{now}\n"
  md << "- Pillar: #{pillar}\n\n"
  md << "## Context\n\n"
  md << "Cloud design decision concerning the #{pillar} Well-Architected pillar.\n"
  if sources.empty?
    md << "Grounding: needs_grounding (no cloud-architecture source covers this pillar in the active catalog).\n\n"
  else
    md << "Grounding sources (cloud-architecture catalog): #{sources.join(", ")}.\n\n"
  end
  md << "## Considered Options\n\n"
  considered.each { |o| md << "- #{o}\n" }
  md << "\n## Decision Outcome\n\n"
  md << "Chosen: #{decision}\n\n"
  md << "Rationale: #{rationale.to_s.empty? ? "(to record)" : rationale}\n"

  adr = {
    "schema_version"  => "1.0",
    "decision_id"     => "#{seq}-#{slug}",
    "title"           => title,
    "status"          => status,
    "date"            => now,
    "pillar"          => pillar,
    "context"         => "Cloud design decision concerning the #{pillar} Well-Architected pillar.",
    "considered_options" => considered,
    "decision_outcome"=> { "chosen" => decision, "rationale" => rationale.to_s },
    "grounding"       => grounding,
    "grounding_sources" => sources,
    "deciders"        => []
  }
  json = JSON.pretty_generate(adr)

  md_path   = "#{out_dir}/#{seq}-#{slug}.md"
  json_path = "#{out_dir}/#{seq}-#{slug}.json"

  unless dry_run
    require "fileutils"
    FileUtils.mkdir_p(out_dir)
    File.write(md_path, md)
    File.write(json_path, json + "\n")
  end

  STDERR.puts "dry_run=true" if dry_run
  STDERR.puts "adr_md=#{md_path}"
  STDERR.puts "adr_json=#{json_path}"
  STDERR.puts "status=#{status}"
  STDERR.puts "pillar=#{pillar}"
  STDERR.puts "grounding=#{grounding}"
  STDERR.puts "sources=#{sources.join(",")}"
'
exit 0
