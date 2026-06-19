#!/usr/bin/env bash
# commands/promote-universal-rules.sh - promote generally-applicable, language-agnostic
# standards into first-class `g-universal-*` rules enforced across ALL languages
# (v1.18 §28.21). Apply-by-default: these standards hold for every generated source
# regardless of language/framework.
#
# DATA-DRIVEN (v1.18 §28.22): the curated principles live in
# standards/universal-standards-catalog.json (DATA) — adding coverage is a catalog
# append, never a code edit. From that ONE catalog this command deterministically
# regenerates the §2.1 rule file generated-code-quality-standards/_universal/
# universal-standards.yaml AND the polyglot detector's pattern table
# rubric/detectors/universal-pattern-rules.json. Deterministic + idempotent — so the
# daily-refresh sync (universal-coverage-sync.sh) can re-promote for free.
#
# CLI: [--root <dir>] [--catalog <path>]   exit 0 ok / 2 usage.

set -uo pipefail
ROOT=""; CATALOG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root)    ROOT="${2-}";    shift 2 ;;
    --catalog) CATALOG="${2-}"; shift 2 ;;
    -h|--help) echo "Usage: promote-universal-rules.sh [--root <dir>] [--catalog <path>]" >&2; exit 0 ;;
    *) echo "promote-universal-rules: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$ROOT" ] && ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
[ -z "$CATALOG" ] && CATALOG="$ROOT/standards/universal-standards-catalog.json"
[ -f "$CATALOG" ] || { echo "promote-universal-rules: catalog not found: $CATALOG" >&2; exit 2; }

ROOT="$ROOT" CATALOG="$CATALOG" ruby -ryaml -rjson -rfileutils -e '
  Encoding.default_external = Encoding::UTF_8
  root = ENV["ROOT"]
  EXT = "*.js,*.jsx,*.ts,*.tsx,*.py,*.go,*.rs,*.java,*.rb,*.cs,*.php,*.kt,*.swift,*.scala,*.c,*.cpp,*.cc,*.h"

  cat = JSON.parse(File.read(ENV["CATALOG"]))
  # apply-by-default: only `classification != "withheld"` principles become enforced
  # universal rules; a withheld principle is carried in the catalog but not promoted.
  principles = (cat["principles"] || []).reject { |p| p["classification"].to_s == "withheld" }

  manifest = { "generated_by" => "promote-universal-rules.sh", "rules" => {} }
  doc_rules = principles.map do |p|
    applies = (p["applies"].to_s.empty? ? EXT : p["applies"])
    manifest["rules"][p["id"]] = { "mode" => p["mode"], "patterns" => p["patterns"], "applies" => applies,
                                   "source" => p["source"], "message" => "#{p["name"]} (#{p["source"]})" }
    {
      "id" => p["id"], "name" => p["name"], "description" => p["description"],
      "detector" => "universal-pattern-rule.sh",
      "type" => "problem", "fixable" => nil, "has_suggestions" => false,
      "deprecated" => false, "replaced_by" => [], "docs_url" => "https://owasp.org/www-project-application-security-verification-standard/",
      "requires_type_checking" => false, "recommended" => true,
      "severity" => p["severity"], "version" => "1.0.0", "semver" => "1.0.0", "rule_state" => "stable",
      "provenance" => [ { "source" => p["source"], "section" => p["section"] } ],
    }
  end

  ids = principles.map { |p| p["id"] }
  doc = {
    "source" => { "id" => "owasp-asvs", "authoritative_publisher" => "OWASP Foundation / cross-source",
      "authoritative_url" => "https://owasp.org/www-project-application-security-verification-standard/",
      "registry_link" => "STANDARDS-URLS.yaml", "fetched_at" => "2026-06-15T00:00:00Z",
      "content_hash" => "sha256:universal-standards-placeholder-content-hash-for-bootstrap",
      "fetch_frequency" => "monthly", "fragility_tier" => "low",
      "license_note" => "Reference/educational use - (c) respective publishers" },
    "rules" => doc_rules, "recommended_set" => ids, "all_set" => ids.dup,
  }
  dir = File.join(root, "generated-code-quality-standards", "_universal")
  FileUtils.mkdir_p(dir)
  File.write(File.join(dir, "universal-standards.yaml"), doc.to_yaml)
  File.write(File.join(root, "rubric", "detectors", "universal-pattern-rules.json"),
             JSON.pretty_generate(manifest) + "\n")
  STDERR.puts "promote-universal-rules: #{principles.size} g-universal rules from catalog (across #{EXT.split(",").size} languages)"
'
