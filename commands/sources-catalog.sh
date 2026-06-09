#!/usr/bin/env bash
# commands/sources-catalog.sh - S-31 secured-source catalog document generator
# (v1.12 §27.14).
#
# Generates a human-readable Markdown catalog mirroring the cloud-architecture
# (S-23) and cloud-engineering (S-30/S-31) source registries, with links and
# metadata. This is the project's auditable "sources catalog" - the single
# document that lists every authority the cloud-architect feature grounds its
# rules, reviews, ADRs, and conventions in.
#
# CLI:
#   --arch-catalog <path>  S-23 catalog (default cloud-architecture-sources.yaml)
#   --eng-catalog <path>   S-30/S-31 catalog (default cloud-engineering-sources.yaml)
#   --out <file>           output (default standards/SOURCES.md)
#   --now <iso>            generated_at (default current UTC)
#   --dry-run              preview to stderr; write nothing (§2.14)
#
# stderr: sources_catalog=<path> arch_sources=<n> eng_sources=<m> total=<t>
# Exit: 0 success / 2 usage error.

set -uo pipefail

ARCH=""; ENG=""; OUT=""; NOW=""; DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --arch-catalog) ARCH="${2-}"; shift 2 ;;
    --eng-catalog)  ENG="${2-}";  shift 2 ;;
    --out)          OUT="${2-}";  shift 2 ;;
    --now)          NOW="${2-}";  shift 2 ;;
    --dry-run)      DRY_RUN=1;    shift ;;
    -h|--help) echo "Usage: sources-catalog.sh [--arch-catalog <p>] [--eng-catalog <p>] [--out <file>] [--now <iso>] [--dry-run]" >&2; exit 0 ;;
    *) echo "sources-catalog: unknown arg: $1" >&2; exit 2 ;;
  esac
done

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
resolve() { if [ -f "$1" ]; then printf '%s' "$1"; elif [ -f "$PLUGIN_ROOT/$1" ]; then printf '%s' "$PLUGIN_ROOT/$1"; else printf '%s' "$1"; fi; }
if [ -z "$ARCH" ]; then ARCH="standards/cloud-architecture-sources.yaml"; fi
if [ -z "$ENG" ]; then ENG="standards/cloud-engineering-sources.yaml"; fi
ARCH=$(resolve "$ARCH"); ENG=$(resolve "$ENG")
if [ -z "$OUT" ]; then OUT="standards/SOURCES.md"; fi
if [ -z "$NOW" ]; then NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ); fi

ARCH="$ARCH" ENG="$ENG" OUT="$OUT" NOW="$NOW" DRY_RUN="$DRY_RUN" ruby -ryaml -e '
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
  arch=ENV["ARCH"]; eng=ENV["ENG"]; out=ENV["OUT"]; now=ENV["NOW"]; dry=ENV["DRY_RUN"]=="1"

  load_cat = lambda do |p|
    return [] unless File.exist?(p)
    d = begin; YAML.unsafe_load_file(p); rescue; nil; end
    d.is_a?(Array) ? d.select { |e| e.is_a?(Hash) && e["id"] } : []
  end
  arch_src = load_cat.call(arch)
  eng_src  = load_cat.call(eng)

  section = lambda do |title, list|
    s = +"## #{title}\n\n"
    list.each do |e|
      pillars = (e["pillars"] || []).join(", ")
      disc    = (e["discipline"] || []).join(", ")
      meta = ["id `#{e["id"]}`", ("tier #{e["tier"]}" if e["tier"])]
      meta << "pillars: #{pillars}" unless pillars.empty?
      meta << "discipline: #{disc}" unless disc.empty?
      s << "- [#{e["name"]}](#{e["url"]}) - #{meta.compact.join("; ")}\n"
    end
    s << "\n"
    s
  end

  md = +"# Cloud-Architect Sources Catalog\n\n"
  md << "Generated: #{now}\n\n"
  md << "Every authority the cloud-architect feature grounds its rules, reviews (S-26), ADRs (S-28), build conformance (S-29), and convention enforcement (S-30) in. Total sources: #{arch_src.length + eng_src.length}.\n\n"
  md << section.call("Architecture curriculum sources (S-23)", arch_src)
  md << section.call("Software-engineering and operations sources (S-30/S-31)", eng_src)

  unless dry
    require "fileutils"
    d = File.dirname(out)
    FileUtils.mkdir_p(d) unless d.empty? || d == "."
    File.write(out, md)
  end

  STDERR.puts "dry_run=true" if dry
  STDERR.puts "sources_catalog=#{out}"
  STDERR.puts "arch_sources=#{arch_src.length}"
  STDERR.puts "eng_sources=#{eng_src.length}"
  STDERR.puts "total=#{arch_src.length + eng_src.length}"
'
exit 0
