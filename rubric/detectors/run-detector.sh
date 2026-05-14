#!/usr/bin/env bash
# rubric/detectors/run-detector.sh — generic detector dispatcher per §2.2
# (line 119 standard flag surface) plus the E-12 cache layer per §16:
#   "Per-rule per-file cache .claude-tdd-pro/rule-cache/<rule-id>.json:
#    cache key sha256(file-content + rule-version + resolved-options +
#    plugin-version); auto-purge entries unused >30 days; max 100MB
#    LRU eviction; F-2 reports hit rate; H-1 token transparency shows
#    ~0 tokens for cache hits."
#
# Per §16 E-2 final clause: "detectors receive --options <json>".
#
# Usage:
#   run-detector.sh --rule <id> --in <file>
#                   [--options <json>] [--config <json>]
#                   [--rule-version <v>] [--parser-version <v>]
#                   [--cache | --no-cache] [--cache-location <path>]
#                   [--cache-strategy content|metadata]
#                   [--cache-max-bytes <N>] [--cache-stats]
#                   [--report-format json] [--trace-args]
#
# Exit codes (per §2.2): 0 ok | 1 violation | 2 usage error.

set -uo pipefail

RULE=""
IN=""
OPTIONS=""
CONFIG=""
RULE_VERSION=""
PARSER_VERSION=""
CACHE=0
NO_CACHE=0
CACHE_LOCATION=""
CACHE_STRATEGY="content"
CACHE_MAX_BYTES=0
CACHE_STATS=0
REPORT_FORMAT=""
TRACE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rule) RULE="$2"; shift 2 ;;
    --in) IN="$2"; shift 2 ;;
    --options) OPTIONS="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    --rule-version) RULE_VERSION="$2"; shift 2 ;;
    --parser-version) PARSER_VERSION="$2"; shift 2 ;;
    --cache) CACHE=1; shift ;;
    --no-cache) NO_CACHE=1; shift ;;
    --cache-location) CACHE_LOCATION="$2"; shift 2 ;;
    --cache-strategy) CACHE_STRATEGY="$2"; shift 2 ;;
    --cache-max-bytes) CACHE_MAX_BYTES="$2"; shift 2 ;;
    --cache-stats) CACHE_STATS=1; shift ;;
    --report-format) REPORT_FORMAT="$2"; shift 2 ;;
    --trace-args) TRACE=1; shift ;;
    --json|--dry-run|--fix|--fix-dry-run) shift ;;
    --paths|--rule-state-override|--format|--cache-key) shift 2 ;;
    *) echo "run-detector: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$RULE" ]] && { echo "run-detector: --rule <id> required" >&2; exit 2; }
[[ -z "$IN" ]] && { echo "run-detector: --in <file> required" >&2; exit 2; }

if [[ "$TRACE" -eq 1 ]]; then
  echo "run-detector: --rule $RULE --in $IN --options $OPTIONS" >&2
  exit 0
fi

# --no-cache trumps --cache. Without either, no cache I/O occurs.
if [[ "$NO_CACHE" -eq 1 ]]; then
  CACHE=0
fi

if [[ "$CACHE" -eq 0 ]]; then
  exit 0
fi

[[ -z "$CACHE_LOCATION" ]] && { echo "run-detector: --cache requires --cache-location <path>" >&2; exit 2; }

# E-12 cache layer.
RULE="$RULE" IN="$IN" OPTIONS="$OPTIONS" CONFIG="$CONFIG" \
RULE_VERSION="$RULE_VERSION" PARSER_VERSION="$PARSER_VERSION" \
CACHE_LOCATION="$CACHE_LOCATION" CACHE_STRATEGY="$CACHE_STRATEGY" \
CACHE_MAX_BYTES="$CACHE_MAX_BYTES" CACHE_STATS="$CACHE_STATS" \
REPORT_FORMAT="$REPORT_FORMAT" \
node -e '
  const fs = require("fs");
  const crypto = require("crypto");
  const path = process.env.CACHE_LOCATION;
  const file = process.env.IN;
  const rule = process.env.RULE;
  const options = process.env.OPTIONS || "";
  const config = process.env.CONFIG || "";
  const ruleVersion = process.env.RULE_VERSION || "";
  const parserVersion = process.env.PARSER_VERSION || "";
  const strategy = process.env.CACHE_STRATEGY;
  const maxBytes = parseInt(process.env.CACHE_MAX_BYTES || "0", 10);
  const reportFormat = process.env.REPORT_FORMAT;
  const cacheStats = process.env.CACHE_STATS === "1";

  const stats = { hits: 0, misses: 0, invalidations: 0, bytes: 0, pruned: 0 };
  let cacheRecovered = false;

  // Plugin version: stable per repo (treated as "1.0" until G-9 surfaces it).
  const pluginVersion = "1.0";

  // Load cache (corruption-safe).
  let cache = { entries: {}, lru: [] };
  if (fs.existsSync(path)) {
    try {
      const raw = fs.readFileSync(path, "utf8");
      const parsed = JSON.parse(raw);
      if (parsed && typeof parsed === "object" && parsed.entries) {
        cache = parsed;
      } else {
        throw new Error("malformed cache");
      }
    } catch {
      try { fs.unlinkSync(path); } catch {}
      cacheRecovered = true;
      stats.invalidations += 1;
    }
  }

  // Compute cache key per §16 E-12: sha256 over the canonical inputs.
  const fileBytes = fs.readFileSync(file);
  let fileSig;
  if (strategy === "metadata") {
    const st = fs.statSync(file);
    fileSig = `mtime:${st.mtimeMs}|size:${st.size}`;
  } else {
    fileSig = "sha256:" + crypto.createHash("sha256").update(fileBytes).digest("hex");
  }
  const keyInput = JSON.stringify([rule, fileSig, ruleVersion, parserVersion, options || config, pluginVersion]);
  const cacheKey = "sha256:" + crypto.createHash("sha256").update(keyInput).digest("hex");

  // Cache hit?
  let status;
  if (cache.entries[cacheKey]) {
    status = "hit";
    stats.hits += 1;
    cache.entries[cacheKey].last_used = Date.now();
    // Move to MRU end.
    cache.lru = cache.lru.filter((k) => k !== cacheKey);
    cache.lru.push(cacheKey);
  } else {
    status = "miss";
    stats.misses += 1;
    // Run detector (substrate-stage stub: always returns clean).
    const result = { clean: true };
    const entry = {
      result,
      stored_at: Date.now(),
      last_used: Date.now(),
      // Bytes counts the input footprint that motivated the cache entry
      // (file size + result + key) so size-bounded eviction (§16 E-12
      // "max 100MB LRU eviction") corresponds to actual workload size.
      bytes: fileBytes.length + Buffer.byteLength(JSON.stringify(result), "utf8") + cacheKey.length
    };

    // Size-bounded admission.
    if (maxBytes > 0 && entry.bytes > maxBytes) {
      stats.pruned += 1;  // entry too big — admission denied
    } else {
      // Evict oldest until total + new fits under cap.
      if (maxBytes > 0) {
        let totalBytes = Object.values(cache.entries).reduce((s, e) => s + (e.bytes || 0), 0);
        while (cache.lru.length > 0 && totalBytes + entry.bytes > maxBytes) {
          const oldest = cache.lru.shift();
          totalBytes -= (cache.entries[oldest] || {}).bytes || 0;
          delete cache.entries[oldest];
          stats.pruned += 1;
        }
      }
      cache.entries[cacheKey] = entry;
      cache.lru.push(cacheKey);
    }
  }

  stats.bytes = Object.values(cache.entries).reduce((s, e) => s + (e.bytes || 0), 0);

  // Persist cache (single-file model).
  fs.writeFileSync(path, JSON.stringify(cache));

  // Emit report.
  if (reportFormat === "json" || cacheStats) {
    const report = Object.assign(
      { cache_status: status, cache_recovered: cacheRecovered, cache_strategy: strategy, cache_key: cacheKey },
      cacheStats ? stats : {}
    );
    process.stderr.write(JSON.stringify(report));
  }
'
