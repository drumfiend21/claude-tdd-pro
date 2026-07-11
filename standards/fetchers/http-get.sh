#!/usr/bin/env bash
# standards/fetchers/http-get.sh — generic upstream stub for standards/fetcher.sh.
#
# The plugin's per-source fetchers (html-anchor.sh, markdown-headers.sh, pdf-section.sh,
# rfc-style.sh) take an already-downloaded local file (--in <file>) and extract ONE known
# section. This script is different: it is a generic upstream stub that emits the RAW URL
# content to stdout, so standards/fetcher.sh can wrap it with fragility-tier + cache
# preservation for any URL — no per-source stub required.
#
# Usage:
#   URL=<url> [TIMEOUT=<seconds>] http-get.sh
#
# Contract (per standards/fetcher.sh line 80): upstream stub is invoked with no arguments,
# reads its inputs from environment, emits raw source content on stdout, non-zero exit on
# failure (fetcher.sh preserves the prior cache on failure per §16 S-2 cache discipline).
#
# Exit codes:
#   0 — content emitted
#   1 — curl failed (dns / timeout / http error)
#   2 — usage (URL env unset)

set -uo pipefail

if [ -z "${URL:-}" ]; then
  echo "http-get: URL env required" >&2
  exit 2
fi
TIMEOUT="${TIMEOUT:-20}"

if ! command -v curl >/dev/null 2>&1; then
  echo "http-get: curl not available" >&2
  exit 1
fi

exec curl --fail --silent --show-error --location --max-time "$TIMEOUT" "$URL"
