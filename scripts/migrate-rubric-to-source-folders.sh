#!/usr/bin/env bash
# migrate-rubric-to-source-folders.sh — G-4 migration (one-time, week-1).
#
# Moves the legacy single-file rubric at rubric/RUBRIC.yaml into source-organized
# files under <emit-tree>/<source-namespace>/<file>.yaml, archiving the original
# to rubric/RUBRIC.legacy.yaml.archived and writing an audit record to
# <emit-tree>/_meta/migration-from-rubric-yaml.md.
#
# Architecture: §17 G-4 in docs/architecture-v1.9.md.
# Schema: target files conform to §2.21 (G-6 source-file contract) and each
# rule in those files conforms to §2.1 (rubric rule schema).
#
# Usage:
#   bash scripts/migrate-rubric-to-source-folders.sh --root <repo-root> --emit-tree <out-dir> [--dry-run]
#
# Exit codes:
#   0 — success (or dry-run reported plan)
#   1 — tooling error (ruby / node missing, args malformed)
#   2 — rejection: already-migrated OR rule lacks provenance.source
#
# Namespace routing: provenance[0].source is split on '-'. First token is the
# namespace folder; remaining tokens (joined with '-') are the filename stem.
# Examples:
#   google-tsguide          -> google/tsguide.yaml
#   google-eng-practices    -> google/eng-practices.yaml
#   owasp-asvs              -> owasp/asvs.yaml

set -uo pipefail

# --- arg parsing ---
ROOT=""
EMIT_TREE=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)       ROOT="$2";       shift 2 ;;
    --emit-tree)  EMIT_TREE="$2";  shift 2 ;;
    --dry-run)    DRY_RUN=1;       shift   ;;
    -h|--help)
      sed -n '1,30p' "$0" >&2
      exit 0
      ;;
    *)
      echo "migrate-rubric: unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$ROOT" || -z "$EMIT_TREE" ]]; then
  echo "migrate-rubric: --root and --emit-tree are required" >&2
  exit 1
fi

if ! command -v ruby >/dev/null 2>&1; then
  echo "migrate-rubric: ruby is required for YAML parsing" >&2
  exit 1
fi

RUBRIC_FILE="$ROOT/rubric/RUBRIC.yaml"
ARCHIVE_FILE="$ROOT/rubric/RUBRIC.legacy.yaml.archived"

# --- one-time-only check (BEFORE reading RUBRIC.yaml; archive existing => reject) ---
if [[ -f "$ARCHIVE_FILE" ]]; then
  echo "migrate-rubric: already migrated; RUBRIC.legacy.yaml.archived exists at $ARCHIVE_FILE — refusing to re-run" >&2
  exit 2
fi

if [[ ! -f "$RUBRIC_FILE" ]]; then
  echo "migrate-rubric: source file not found: $RUBRIC_FILE" >&2
  exit 1
fi

# --- parse RUBRIC.yaml + plan the migration via ruby ---
# Output of the ruby block:
#   - stdout: a tab-separated plan, one rule per line:
#       <rule-id>\t<namespace>\t<filename>\t<target-file-relative-path>
#   - exit 2 with stderr message if any rule lacks provenance.source
#   - exit 0 + plan otherwise
#
# We also need to emit the source-organized files. We delegate the YAML
# emission to ruby too, because each target file is itself YAML.

PLAN_DIR="$(mktemp -d)"
# Cleanup happens on EXIT; in dry-run we don't keep state, in real run we copy out.
cleanup() { rm -rf "$PLAN_DIR"; }
trap cleanup EXIT

PLAN_FILE="$PLAN_DIR/plan.tsv"
EMISSION_DIR="$PLAN_DIR/emit"
mkdir -p "$EMISSION_DIR"

ruby -ryaml -e '# coding: utf-8
  require "fileutils"

  rubric_path    = ARGV[0]
  emission_dir   = ARGV[1]
  plan_file      = ARGV[2]

  # Pre-process: quote URLs / timestamps / hashes inside flow-style maps so
  # Ruby Psych can parse them. Block-style RUBRIC.yaml is unaffected.
  raw = File.read(rubric_path)
  raw = raw.gsub(/(\burl:\s+)(https?:\/\/[^\s,\}]+)/, "\\1\"\\2\"")
  raw = raw.gsub(/(\bfetched_at:\s+)(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z?)/, "\\1\"\\2\"")
  raw = raw.gsub(/(\bcontent_hash:\s+)(sha256:[A-Za-z0-9_\-]+)/, "\\1\"\\2\"")

  begin
    data = YAML.unsafe_load(raw)
  rescue => e
    STDERR.puts "migrate-rubric: yaml parse error: #{e.message}"
    exit 1
  end

  rules = (data && data["rules"]) || []

  # Group rules by target file
  by_file = {}     # "<ns>/<filename>" => { ns:, filename:, source_header:, rules: [] }
  plan_lines = []

  rules.each_with_index do |rule, idx|
    provenance = rule["provenance"]
    if !provenance.is_a?(Array) || provenance.empty? || !provenance[0].is_a?(Hash) || provenance[0]["source"].nil? || provenance[0]["source"].to_s.strip.empty?
      STDERR.puts "migrate-rubric: rule provenance.source is required (index #{idx}, id=#{rule["id"] || "<no-id>"})"
      exit 2
    end

    source_id = provenance[0]["source"].to_s
    parts = source_id.split("-")
    namespace = parts.shift
    filename  = parts.join("-")
    if namespace.nil? || namespace.empty? || filename.empty?
      STDERR.puts "migrate-rubric: rule provenance.source is required to be <namespace>-<file> form (got: #{source_id.inspect})"
      exit 2
    end

    key = "#{namespace}/#{filename}"
    target_rel = "generated-code-quality-standards/#{namespace}/#{filename}.yaml"

    by_file[key] ||= {
      namespace: namespace,
      filename:  filename,
      source_header: {
        "id"                => source_id,
        "authoritative_url" => provenance[0]["url"],
        "content_hash"      => provenance[0]["content_hash"],
        "fetched_at"        => provenance[0]["fetched_at"],
      }.compact,
      rules: [],
    }

    # Stamp source_file field on the rule per §2.1
    enriched = rule.dup
    enriched["source_file"] = target_rel
    by_file[key][:rules] << enriched

    plan_lines << [rule["id"], namespace, filename, target_rel].join("\t")
  end

  # Always write the plan (caller decides whether to emit files)
  File.write(plan_file, plan_lines.join("\n") + (plan_lines.empty? ? "" : "\n"))

  # Emit source-organized files
  by_file.each do |_key, bundle|
    out_dir = File.join(emission_dir, bundle[:namespace])
    FileUtils.mkdir_p(out_dir)
    out_path = File.join(out_dir, "#{bundle[:filename]}.yaml")

    payload = {
      "source" => bundle[:source_header],
      "rules"  => bundle[:rules],
    }
    File.write(out_path, payload.to_yaml(line_width: -1))
  end

  # Always emit _meta audit record (whether or not we copy it out)
  meta_dir = File.join(emission_dir, "_meta")
  FileUtils.mkdir_p(meta_dir)
  meta_path = File.join(meta_dir, "migration-from-rubric-yaml.md")
  File.write(meta_path, <<~MD)
    # Migration from rubric/RUBRIC.yaml

    One-time week-1 G-4 migration. Source: `rubric/RUBRIC.yaml` (now archived as
    `rubric/RUBRIC.legacy.yaml.archived`).

    Generated by `scripts/migrate-rubric-to-source-folders.sh` per §17 G-4 of
    `docs/architecture-v1.9.md`.

    ## Summary

    - Source rules: #{rules.length}
    - Target files: #{by_file.length}

    ## Mapping (rule id -> target file)

    #{plan_lines.map { |l| id, ns, fn, rel = l.split("\t"); "- `#{id}` -> `#{rel}`" }.join("\n")}
  MD

  # Final report — to stderr so dry-run callers can capture via 2>file.
  STDERR.puts "#{rules.length} rules -> #{by_file.length} files"
' "$RUBRIC_FILE" "$EMISSION_DIR" "$PLAN_FILE"

RUBY_EXIT=$?

if [[ $RUBY_EXIT -ne 0 ]]; then
  exit "$RUBY_EXIT"
fi

# --- dry-run: report, don't write ---
if [[ "$DRY_RUN" -eq 1 ]]; then
  exit 0
fi

# --- real run: copy emitted tree to <emit-tree>, then archive RUBRIC.yaml ---
mkdir -p "$EMIT_TREE"
# Copy contents (preserve namespace subdirs)
if command -v cp >/dev/null 2>&1; then
  cp -R "$EMISSION_DIR"/. "$EMIT_TREE"/
else
  echo "migrate-rubric: cp not available" >&2
  exit 1
fi

# Archive original
mv "$RUBRIC_FILE" "$ARCHIVE_FILE"

exit 0
