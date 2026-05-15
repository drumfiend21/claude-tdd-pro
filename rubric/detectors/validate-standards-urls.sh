#!/usr/bin/env bash
# rubric/detectors/validate-standards-urls.sh — S-12 operator-facing
# STANDARDS-URLS.yaml validator per §2.6 operator schema:
#   id (required), name (required), url (required, https://),
#   tier (1|2), applies_to (non-empty array), fetch_frequency
#   (daily|weekly|monthly).
#
# Plugin-internal fields (class, authority_tier, ...) are NOT permitted
# in the operator-facing registry — those are derived in the merge step.
#
# Usage:
#   validate-standards-urls.sh <path-to-STANDARDS-URLS.yaml>
#
# Exit codes (per §2.2): 0 ok | 2 validation failure.

set -uo pipefail

REG="${1:-}"
[[ -z "$REG" ]] && { echo "validate-standards-urls: usage: <path>" >&2; exit 2; }
[[ ! -f "$REG" ]] && { echo "validate-standards-urls: file not found: $REG" >&2; exit 2; }

REG="$REG" ruby -ryaml -e '
  path = ENV["REG"]
  begin
    doc = YAML.load_file(path)
  rescue Psych::SyntaxError => e
    STDERR.puts "validate-standards-urls: YAML syntax error at line #{e.line}: #{e.problem}"
    exit 2
  end
  doc = [] if doc.nil?
  unless doc.is_a?(Array)
    STDERR.puts "validate-standards-urls: registry must be a YAML array"
    exit 2
  end
  errs = []
  required = %w[id name url tier applies_to fetch_frequency]
  ff_enum = %w[daily weekly monthly]
  doc.each_with_index do |entry, idx|
    unless entry.is_a?(Hash)
      errs << "entry ##{idx}: must be a YAML map"
      next
    end
    eid = entry["id"] || "(no id)"
    required.each { |k| errs << "id \"#{eid}\": #{k} required" unless entry.key?(k) }
    if entry.key?("tier") && ![1, 2].include?(entry["tier"])
      errs << "id \"#{eid}\": tier must be 1 or 2"
    end
    if entry.key?("fetch_frequency") && !ff_enum.include?(entry["fetch_frequency"])
      errs << "id \"#{eid}\": fetch_frequency \"#{entry["fetch_frequency"]}\" not in enum {#{ff_enum.join(", ")}}"
    end
    if entry.key?("url") && entry["url"].is_a?(String) && !entry["url"].start_with?("https://")
      errs << "id \"#{eid}\": url must start with https://"
    end
    if entry.key?("applies_to")
      a = entry["applies_to"]
      errs << "id \"#{eid}\": applies_to must be non-empty array" unless a.is_a?(Array) && !a.empty?
    end
  end
  if errs.empty?
    exit 0
  else
    errs.each { |e| STDERR.puts e }
    exit 2
  end
'
