#!/usr/bin/env bash
# L-9 profile activation validator. Enforces P0 severity rules must include
# at least one tier-1 published-standard provenance entry; pr-corpus alone
# is insufficient for P0 (see architecture §2.X provenance hierarchy).
set -uo pipefail
PROFILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    -h|--help) echo "Usage: validate-profile.sh --profile <yaml>"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$PROFILE" || ! -f "$PROFILE" ]] && { echo "validate-profile: --profile <yaml> required" >&2; exit 2; }

PROFILE="$PROFILE" LANG="${LANG:-en_US.UTF-8}" ruby -ryaml -e '# coding: utf-8
Encoding.default_external = Encoding::UTF_8
data = YAML.load_file(ENV["PROFILE"]) rescue {}
rules = (data["rules"] || [])
errors = []
rules.each do |r|
  id = r["id"]
  sev = r["severity"]
  prov = r["provenance"] || []
  if sev == "P0"
    has_tier1_published = prov.any? { |p| p["class"] == "published-standard" && (p["tier"] == 1) }
    if has_tier1_published
      STDERR.puts "validate-profile: rule=#{id} valid=true severity=P0 provenance=published-standard+tier1"
    else
      STDERR.puts "validate-profile: P0_requires_published_standard rule=#{id} (P0 severity rules must cite a tier-1 published standard; pr-corpus class alone is insufficient)"
      errors << id
    end
  else
    STDERR.puts "validate-profile: rule=#{id} valid=true severity=#{sev}"
  end
end
exit(errors.empty? ? 0 : 1)
'
