#!/usr/bin/env bash
set -uo pipefail
SOURCE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[[ -z "$SOURCE" || ! -f "$SOURCE" ]] && { echo "validate-source: --source required" >&2; exit 2; }

VALID_CLASSES="federal-financial-regulator federal-government cloud-platform-vendor framework-maintainer open-source-foundation security-foundation standards-body community-curated"
VALID_STACKS="react node typescript javascript go ruby python rust"
VALID_TIERS="1 2"

SOURCE="$SOURCE" VC="$VALID_CLASSES" VS="$VALID_STACKS" VT="$VALID_TIERS" ruby -ryaml -e '
d = YAML.unsafe_load_file(ENV["SOURCE"]) rescue {}
errs = []
classes = ENV["VC"].split(" ")
stacks = ENV["VS"].split(" ")
tiers = ENV["VT"].split(" ").map(&:to_i)
errs << "source_class \"#{d["source_class"]}\" not in valid set [#{classes.join(", ")}]" if d["source_class"] && !classes.include?(d["source_class"])
errs << "tier #{d["tier"]} must be one of #{tiers.inspect}" if d["tier"] && !tiers.include?(d["tier"].to_i)
(d["applies_to"]||[]).each do |s|
  errs << "applies_to \"#{s}\" not in valid stack set [#{stacks.join(", ")}]" unless stacks.include?(s)
end
if errs.any?
  errs.each { |e| STDERR.puts "validate-source: #{e}" }
  exit 2
end
STDERR.puts "validate-source: ok"
'
