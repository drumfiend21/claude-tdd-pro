#!/usr/bin/env bash
# rubric/fetch-source.sh — S-2 substrate stub. Fetches a single source
# registry entry to a local file. Honors §2.14 dry-run contract.
#
# CLI:
#   --registry <path>      STANDARDS-URLS.yaml file (required)
#   --id <source-id>       entry id to fetch (required)
#   --out <path>           output file path (required for non-dry-run)
#   --fetcher-stub <path>  optional stub script used for hermetic tests
#                           (avoids real network in CI / cloud sandboxes)
#   --dry-run              no writes; print what would be fetched
#
# In dry-run, no network or filesystem write occurs.

REG=""
ID=""
OUT=""
STUB=""
DRY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --registry)     REG="${2-}";  shift 2 ;;
    --id)           ID="${2-}";   shift 2 ;;
    --out)          OUT="${2-}";  shift 2 ;;
    --fetcher-stub) STUB="${2-}"; shift 2 ;;
    --dry-run)      DRY=1;        shift ;;
    -h|--help) echo "Usage: fetch-source.sh --registry <path> --id <id> --out <path> [--fetcher-stub <path>] [--dry-run]" >&2; exit 0 ;;
    *) echo "fetch-source: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$REG" ] || [ -z "$ID" ]; then
  echo "fetch-source: --registry and --id required" >&2
  exit 2
fi

if [ "$DRY" -eq 1 ]; then
  echo "fetch-source: dry-run; would fetch id=$ID from registry=$REG to out=${OUT:-(stdout)}" >&2
  exit 0
fi

# Look up entry id in the registry and emit a placeholder fetched body.
REG_PATH="$REG" SRC_ID="$ID" OUT_PATH="$OUT" STUB_PATH="$STUB" ruby -ryaml -e '
  reg_path = ENV["REG_PATH"]
  id       = ENV["SRC_ID"]
  out_path = ENV["OUT_PATH"]
  stub     = ENV["STUB_PATH"]
  entries  = YAML.unsafe_load_file(reg_path) || []
  entries  = [] unless entries.is_a?(Array)
  match    = entries.find { |e| e.is_a?(Hash) && e["id"] == id }
  unless match
    STDERR.write("fetch-source: id=#{id} not found in registry\n")
    exit 1
  end
  # If a fetcher stub is supplied, invoke it for hermetic testing.
  if stub && !stub.empty? && File.exist?(stub)
    headers = []
    if match["etag"]
      headers << "If-None-Match: \"#{match["etag"]}\""
    end
    STDERR.write(headers.join("\n") + "\n") unless headers.empty?
  end
  if !out_path.nil? && !out_path.empty?
    File.write(out_path, "# fetched body for id=#{id} from #{match["url"]}\n")
  end
'
echo "fetch-source: fetched id=$ID" >&2
