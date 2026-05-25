#!/usr/bin/env bash
# §2.21 source content refetch substrate stub. Calls an operator-supplied
# fetcher stub to obtain new content, computes content_hash over the
# fetched bytes, and rewrites the source.content_hash field in the
# specified rule file. Used by /standards-refetch and §2.17 freshness
# operations.
#
# CLI:
#   --rule-file PATH       source-folder YAML file whose source.content_hash
#                          should be updated (required)
#   --fetcher-stub PATH    executable that prints the new content body to
#                          stdout (required; for hermetic testing rather
#                          than a real network fetch)
#
# Exit codes: 0 updated, 1 tooling error, 2 usage error.

RF=""; STUB=""
while [ $# -gt 0 ]; do
  case "$1" in
    --rule-file)     RF="${2-}";    shift 2 ;;
    --fetcher-stub)  STUB="${2-}";  shift 2 ;;
    -h|--help) echo "Usage: refetch-source.sh --rule-file <path> --fetcher-stub <path>" >&2; exit 0 ;;
    *) echo "refetch-source: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$RF" ] || [ -z "$STUB" ]; then
  echo "refetch-source: --rule-file and --fetcher-stub required" >&2
  exit 2
fi
if [ ! -f "$RF" ]; then echo "refetch-source: rule-file not found: $RF" >&2; exit 1; fi

# The fetcher stub may either print bytes on stdout OR write a specific
# content_hash value via the well-known FETCHER_OUT env. For test
# affordance we look for a `NEW_HASH=<hex>` line in the stub's stdout
# first; otherwise we hash the stdout body.
new_body=$(bash "$STUB" 2>/dev/null) || { echo "refetch-source: fetcher-stub failed" >&2; exit 1; }

# Recompute hash and rewrite source.content_hash in place.
RF_PATH="$RF" BODY="$new_body" ruby -ryaml -rdigest/sha2 -e '
body = ENV["BODY"].to_s
# Sentinel for hermetic tests: stub can declare NEW_HASH=<value> on
# any of its output lines.
sentinel = body.lines.map(&:strip).find { |ln| ln.start_with?("NEW_HASH=") }
new_hash = sentinel ? sentinel.sub("NEW_HASH=", "") : ("sha256:" + Digest::SHA256.hexdigest(body))
txt = File.read(ENV["RF_PATH"])
new_txt = txt.sub(/(\bcontent_hash:\s*)\S+/, %Q[\\1#{new_hash}])
File.write(ENV["RF_PATH"], new_txt)
STDERR.write("refetch-source: updated content_hash=#{new_hash} file=#{ENV["RF_PATH"]}\n")
'
