#!/usr/bin/env bash
# rubric/detectors/validate-standards-catalog.sh — S-1 catalog validator
# per §2.6 standards source contract (two-tier).
#
# Validates that standards/sources.yaml entries satisfy the operator-
# facing schema (id, name, url, tier, applies_to, fetch_frequency) plus
# the plugin-internal schema (class, authority_tier, fragility_tier,
# fragility_strategy, fetcher, identifier_pattern, license_note,
# origin, added_by, added_at). Constraints:
#   - tier ∈ {1, 2}
#   - fragility_tier ∈ {high, medium, low}
#   - fragility_strategy ∈ {silent-replace, prompt-on-change, manual-only}
#   - applies_to: non-empty array
#   - fetcher ∈ {html-anchor.sh, markdown-headers.sh, pdf-section.sh,
#     rfc-style.sh} (per §16 S-2)
#   - id unique within catalog
#
# Usage:
#   validate-standards-catalog.sh <path-to-catalog.yaml>
#                                 [--check operator-facing|plugin-internal|fetcher-allowlist]
#
# Exit codes (per §2.2):
#   0 — catalog valid
#   2 — validation failure (errors written to stderr)
#   1 — tooling error

set -uo pipefail

CATALOG=""
CHECK=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK="$2"; shift 2 ;;
    -*) echo "validate-standards-catalog: unknown flag: $1" >&2; exit 2 ;;
    *) [[ -z "$CATALOG" ]] && CATALOG="$1" || { echo "validate-standards-catalog: unexpected arg: $1" >&2; exit 2; }; shift ;;
  esac
done

[[ -z "$CATALOG" ]] && { echo "validate-standards-catalog: usage: validate-standards-catalog.sh <catalog.yaml>" >&2; exit 2; }
[[ ! -f "$CATALOG" ]] && { echo "validate-standards-catalog: catalog not found: $CATALOG" >&2; exit 2; }

CATALOG="$CATALOG" CHECK="$CHECK" ruby -ryaml -e '
  catalog_path = ENV["CATALOG"]
  check        = ENV["CHECK"]
  doc = YAML.load_file(catalog_path)
  unless doc.is_a?(Array)
    STDERR.puts "catalog must be a YAML array of source entries"
    exit 2
  end

  errs = []
  ids_seen = {}

  required_operator = %w[id name url tier applies_to fetch_frequency]
  required_internal = %w[class authority_tier fragility_tier fragility_strategy fetcher identifier_pattern license_note origin added_by added_at]
  fetcher_allowlist = %w[html-anchor.sh markdown-headers.sh pdf-section.sh rfc-style.sh]
  fragility_tier_enum = %w[high medium low]
  fragility_strategy_enum = %w[silent-replace prompt-on-change manual-only]

  doc.each_with_index do |entry, idx|
    unless entry.is_a?(Hash)
      errs << "entry ##{idx}: must be a YAML map"
      next
    end
    eid = entry["id"] || "(no id)"
    if entry["id"].is_a?(String)
      if ids_seen[entry["id"]]
        errs << "id \"#{entry["id"]}\": duplicate (also at entry ##{ids_seen[entry["id"]]})"
      else
        ids_seen[entry["id"]] = idx
      end
    end

    # Conditional checks based on --check flag (when given), otherwise validate all.
    do_op = check.empty? || check == "operator-facing"
    do_pi = check.empty? || check == "plugin-internal"
    do_fa = check.empty? || check == "fetcher-allowlist"

    if do_op
      required_operator.each do |k|
        errs << "id \"#{eid}\": missing operator-facing required field: #{k}" unless entry.key?(k)
      end
      if entry.key?("tier") && ![1, 2].include?(entry["tier"])
        errs << "id \"#{eid}\": tier must be 1 or 2 (got #{entry["tier"].inspect})"
      end
      if entry.key?("applies_to")
        a = entry["applies_to"]
        if !(a.is_a?(Array) && !a.empty?)
          errs << "id \"#{eid}\": applies_to must be a non-empty array"
        end
      end
    end

    if do_pi
      required_internal.each do |k|
        errs << "id \"#{eid}\": missing plugin-internal required field: #{k}" unless entry.key?(k)
      end
      if entry.key?("fragility_tier") && !fragility_tier_enum.include?(entry["fragility_tier"])
        errs << "id \"#{eid}\": fragility_tier not in enum {high, medium, low} (got #{entry["fragility_tier"].inspect})"
      end
      if entry.key?("fragility_strategy") && !fragility_strategy_enum.include?(entry["fragility_strategy"])
        errs << "id \"#{eid}\": fragility_strategy not in enum {silent-replace, prompt-on-change, manual-only} (got #{entry["fragility_strategy"].inspect})"
      end
    end

    if do_fa
      if entry.key?("fetcher") && !fetcher_allowlist.include?(entry["fetcher"])
        errs << "id \"#{eid}\": fetcher \"#{entry["fetcher"]}\" not in S-2 allowlist {#{fetcher_allowlist.join(", ")}}"
      end
    end
  end

  if errs.empty?
    exit 0
  else
    errs.each { |e| STDERR.puts e }
    exit 2
  end
'
