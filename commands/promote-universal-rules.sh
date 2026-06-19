#!/usr/bin/env bash
# commands/promote-universal-rules.sh - promote generally-applicable, language-agnostic
# standards into first-class `g-universal-*` rules enforced across ALL languages
# (v1.18 §28.21). Apply-by-default: these standards hold for every generated source
# regardless of language/framework. From ONE manifest it generates (single source of
# truth -> no drift): the §2.1 rule file generated-code-quality-standards/_universal/
# universal-standards.yaml AND the polyglot detector's pattern table
# rubric/detectors/universal-pattern-rules.json. Deterministic + idempotent.
#
# CLI: [--root <dir>]   exit 0 ok / 2 usage.

set -uo pipefail
ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2-}"; shift 2 ;;
    -h|--help) echo "Usage: promote-universal-rules.sh [--root <dir>]" >&2; exit 0 ;;
    *) echo "promote-universal-rules: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$ROOT" ] && ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"

ROOT="$ROOT" ruby -ryaml -rjson -rfileutils -e '
  Encoding.default_external = Encoding::UTF_8
  root = ENV["ROOT"]
  EXT = "*.js,*.jsx,*.ts,*.tsx,*.py,*.go,*.rs,*.java,*.rb,*.cs,*.php,*.kt,*.swift,*.scala,*.c,*.cpp,*.cc,*.h"

  # single source of truth: id, name, description, source, severity, mode, patterns[]
  RULES = [
    { id: "g-universal-no-hardcoded-secrets", name: "no-hardcoded-secrets",
      desc: "No credential, key, or token literal may be committed to source in any language; load secrets from the environment or a secret store.",
      source: "owasp-asvs", section: "V2.10", severity: "P0", mode: "forbid",
      patterns: [
        "AKIA[0-9A-Z]{16}",
        "BEGIN [A-Z ]*PRIVATE KEY",
        "(password|passwd|secret|api_?key|access_?key|auth_?token|client_?secret|token)[\"\x27`]?\\s*[:=]{1,2}\\s*[\"\x27`][^\"\x27`]{6,}[\"\x27`]",
      ] },
    { id: "g-universal-no-debug-output", name: "no-debug-output-in-source",
      desc: "No raw debug print/console output in production source in any language; use a structured logger.",
      source: "google-eng-practices", section: "logging", severity: "P2", mode: "forbid",
      patterns: [
        "console\\.(log|debug|info|warn)\\s*\\(",
        "\\bprint\\s*\\(",
        "fmt\\.Print",
        "System\\.out\\.print",
        "println!\\s*\\(",
        "Console\\.WriteLine",
      ] },
  ]

  manifest = { "generated_by" => "promote-universal-rules.sh", "rules" => {} }
  doc_rules = RULES.map do |r|
    manifest["rules"][r[:id]] = { "mode" => r[:mode], "patterns" => r[:patterns], "applies" => EXT,
                                  "source" => r[:source], "message" => "#{r[:name]} (#{r[:source]})" }
    {
      "id" => r[:id], "name" => r[:name], "description" => r[:desc],
      "detector" => "universal-pattern-rule.sh",
      "type" => "problem", "fixable" => nil, "has_suggestions" => false,
      "deprecated" => false, "replaced_by" => [], "docs_url" => "https://owasp.org/www-project-application-security-verification-standard/",
      "requires_type_checking" => false, "recommended" => true,
      "severity" => r[:severity], "version" => "1.0.0", "semver" => "1.0.0", "rule_state" => "stable",
      "provenance" => [ { "source" => r[:source], "section" => r[:section] } ],
    }
  end

  ids = RULES.map { |r| r[:id] }
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
  STDERR.puts "promote-universal-rules: #{RULES.size} g-universal rules across all languages (#{EXT.split(",").size} extensions)"
'
