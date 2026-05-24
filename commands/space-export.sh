#!/usr/bin/env bash
# Q-6 SPACE export. Privacy-aware export per architecture section 16 Q-6:
# gitignored output, redacted (PII guard), local-only, share-never gate.
set -uo pipefail

COLLECTED=""; OUT=""; CONFIG=""; SHARE_TO=""; ROOT=""; DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --collected) COLLECTED="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    --share-to) SHARE_TO="$2"; shift 2 ;;
    --root) ROOT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) echo "Usage: space-export.sh --collected <jsonl> --out <path> [--config <yaml>] [--share-to <url>] [--root <dir>] [--dry-run]"; exit 0 ;;
    *) shift ;;
  esac
done

# Share-never gate: when --share-to is requested AND share=never, block.
if [[ -n "$SHARE_TO" ]]; then
  SHARE="never"
  if [[ -n "$CONFIG" && -f "$CONFIG" ]]; then
    SHARE=$(CONFIG="$CONFIG" ruby -ryaml -e 'd=YAML.unsafe_load_file(ENV["CONFIG"]) rescue {}; print(d["share"] || "never")')
  fi
  if [[ "$SHARE" == "never" ]]; then
    echo "space-export: share=never blocked --share-to $SHARE_TO (network egress disabled by config)" >&2
    exit 2
  fi
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "space-export: dry-run; would write export to $OUT (no writes)" >&2
  exit 0
fi

[[ -z "$COLLECTED" || ! -f "$COLLECTED" ]] && { echo "space-export: --collected <path> required" >&2; exit 2; }
[[ -z "$OUT" ]] && { echo "space-export: --out <path> required" >&2; exit 2; }

COLLECTED="$COLLECTED" OUT="$OUT" CONFIG="$CONFIG" ROOT="$ROOT" \
LANG="${LANG:-en_US.UTF-8}" ruby -ryaml -rjson -e '# coding: utf-8
Encoding.default_external = Encoding::UTF_8
collected_path = ENV["COLLECTED"]
out_path = ENV["OUT"]
config_path = ENV["CONFIG"]
root = ENV["ROOT"]

cfg = config_path && !config_path.empty? && File.file?(config_path) ? (YAML.unsafe_load_file(config_path) rescue {}) : {}
dims = cfg["dimensions"] || {}
share = cfg["share"] || "never"
retention = cfg["retention_days"] || 90

# Filter: include only opted-in dimensions.
included_dims = []
%w[satisfaction performance activity collaboration efficiency_and_flow].each do |d|
  cfg_d = dims[d] || {}
  included_dims << d if cfg_d["enabled"] == true
end

# Read & filter records.
records = []
File.foreach(collected_path) do |line|
  rec = (JSON.parse(line) rescue nil)
  next unless rec
  if rec["dimension"] && !included_dims.include?(rec["dimension"])
    next
  end
  # Redact PII: emails, phone numbers, user, hostname.
  rec.delete("user")
  rec.delete("hostname")
  if rec["note"]
    rec["note"] = rec["note"].gsub(/[\w._%+-]+@[\w.-]+\.[A-Za-z]{2,}/, "[REDACTED-EMAIL]")
                              .gsub(/\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b/, "[REDACTED-PHONE]")
  end
  # Relativize file paths (canonicalize first so .. segments resolve).
  if rec["file"] && root && !root.empty?
    canon_file = File.expand_path(rec["file"]) rescue rec["file"]
    canon_root = File.expand_path(root) rescue root
    if canon_file.start_with?(canon_root + "/")
      rec["file"] = canon_file.sub(/^#{Regexp.escape(canon_root)}\/?/, "")
    end
  end
  records << rec
end

STDERR.puts "space-export: pii_guard=invoked records=#{records.size}"

bundle = {
  "share" => share,
  "retention_days" => retention,
  "included_dimensions" => included_dims,
  "records" => records,
  "exported_at" => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
  "scope" => "solo-self-observation",
}
File.write(out_path, JSON.generate(bundle))
STDERR.puts "space-export: wrote=#{out_path} network=disabled (local-only)"
'
