#!/usr/bin/env bash
# /legal-review-mark — C-2 skill backbone per §16:
#   "Control mapping → compliance/controls.yaml with legal_review_status;
#    /legal-review-mark skill."
#
# Updates the legal_review_status field of a controls.yaml entry to
# reviewed_by:<reviewer>:<date>. Refuses when the (framework, control_id)
# pair isn't present.
set -uo pipefail

FRAMEWORK=""; CONTROL_ID=""; REVIEWER=""; DATE=""; CONTROLS_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --framework) FRAMEWORK="$2"; shift 2 ;;
    --control-id) CONTROL_ID="$2"; shift 2 ;;
    --reviewer) REVIEWER="$2"; shift 2 ;;
    --date) DATE="$2"; shift 2 ;;
    --controls-file) CONTROLS_FILE="$2"; shift 2 ;;
    *) echo "legal-review-mark: unknown flag: $1" >&2; exit 2 ;;
  esac
done
[[ -z "$FRAMEWORK" || -z "$CONTROL_ID" || -z "$REVIEWER" || -z "$DATE" || -z "$CONTROLS_FILE" ]] && {
  echo "legal-review-mark: --framework, --control-id, --reviewer, --date, --controls-file required" >&2; exit 2; }
[[ ! -f "$CONTROLS_FILE" ]] && { echo "legal-review-mark: file not found: $CONTROLS_FILE" >&2; exit 2; }

FRAMEWORK="$FRAMEWORK" CONTROL_ID="$CONTROL_ID" REVIEWER="$REVIEWER" DATE="$DATE" CONTROLS_FILE="$CONTROLS_FILE" ruby -ryaml -e '
  path = ENV["CONTROLS_FILE"]
  fw = ENV["FRAMEWORK"]
  cid = ENV["CONTROL_ID"]
  doc = YAML.load_file(path) || []
  found = false
  doc.each do |entry|
    next unless entry.is_a?(Hash)
    if entry["framework"] == fw && entry["control_id"] == cid
      entry["legal_review_status"] = "reviewed_by:#{ENV["REVIEWER"]}:#{ENV["DATE"]}"
      found = true
    end
  end
  unless found
    STDERR.puts "legal-review-mark: (#{fw}, #{cid}) not found in #{path}"
    exit 2
  end
  File.write(path, doc.to_yaml.sub(/\A---\n/, ""))
  STDERR.puts "legal-review-mark: updated #{fw}/#{cid} -> reviewed_by:#{ENV["REVIEWER"]}:#{ENV["DATE"]}"
'
