#!/usr/bin/env bash
# /standards-audit — S-4 entry point per §16:
#   "/standards-audit + gap analyzer."
#
# Emits a Markdown audit report covering:
#   - Per-source coverage state
#   - Overall coverage percentage
#   - Gaps (--include-gaps): catalog sources with zero citing rules
#   - Stale sources (--check-freshness): sources whose last-fetch
#     marker is older than fetch_frequency
#   - Shallow provenance (--check-shallow-provenance): rules with
#     empty provenance entries
#   - Recommendations (--recommend): "PROMOTE:" action cards
#   - Archived (--include-archived): sources moved to _archived/
#
# Usage:
#   standards-audit.sh --emit <path>
#                      [--tree <dir>]
#                      [--catalog <path>]
#                      [--link-to <coverage.md>]
#                      [--dry-run]
#                      [--threshold <N>]
#                      [--include-gaps]
#                      [--check-shallow-provenance]
#                      [--check-freshness --now <iso>]
#                      [--recommend]
#                      [--include-archived]
#
# Exit codes (per §2.2):
#   0 — audit emitted (or printed under --dry-run)
#   1 — coverage below --threshold
#   2 — usage error

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
EMIT=""
TREE=""
CATALOG=""
LINK_TO=""
DRY_RUN=0
THRESHOLD=0
INCLUDE_GAPS=0
CHECK_SHALLOW=0
CHECK_FRESHNESS=0
NOW_ISO=""
RECOMMEND=0
INCLUDE_ARCHIVED=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --emit) EMIT="$2"; shift 2 ;;
    --tree) TREE="$2"; shift 2 ;;
    --catalog) CATALOG="$2"; shift 2 ;;
    --link-to) LINK_TO="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --threshold) THRESHOLD="$2"; shift 2 ;;
    --include-gaps) INCLUDE_GAPS=1; shift ;;
    --check-shallow-provenance) CHECK_SHALLOW=1; shift ;;
    --check-freshness) CHECK_FRESHNESS=1; shift ;;
    --now) NOW_ISO="$2"; shift 2 ;;
    --recommend) RECOMMEND=1; shift ;;
    --include-archived) INCLUDE_ARCHIVED=1; shift ;;
    *) echo "standards-audit: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$EMIT" ]] && { echo "standards-audit: --emit <path> required" >&2; exit 2; }

# Default catalog: operator-facing first, then plugin-internal.
if [[ -z "$CATALOG" ]]; then
  if [[ -f ".claude-tdd-pro/STANDARDS-URLS.yaml" ]]; then
    CATALOG=".claude-tdd-pro/STANDARDS-URLS.yaml"
  else
    CATALOG="$PLUGIN_ROOT/standards/sources.yaml"
  fi
fi

# Default tree: auto-detect when caller didn't specify. Local tree/
# fixture takes precedence over the canonical project location, so test
# harnesses that mkdir -p tree/google/x.yaml are picked up automatically.
if [[ -z "$TREE" ]]; then
  if [[ -d "tree" ]]; then
    TREE="tree"
  elif [[ -d "generated-code-quality-standards" ]]; then
    TREE="generated-code-quality-standards"
  fi
fi

EMIT="$EMIT" TREE="$TREE" CATALOG="$CATALOG" LINK_TO="$LINK_TO" DRY_RUN="$DRY_RUN" \
THRESHOLD="$THRESHOLD" INCLUDE_GAPS="$INCLUDE_GAPS" CHECK_SHALLOW="$CHECK_SHALLOW" \
CHECK_FRESHNESS="$CHECK_FRESHNESS" NOW_ISO="$NOW_ISO" RECOMMEND="$RECOMMEND" \
INCLUDE_ARCHIVED="$INCLUDE_ARCHIVED" node -e '
  const fs = require("fs");
  const path = require("path");
  const emit = process.env.EMIT;
  const tree = process.env.TREE;
  const catalogPath = process.env.CATALOG;
  const linkTo = process.env.LINK_TO;
  const dryRun = process.env.DRY_RUN === "1";
  const threshold = parseInt(process.env.THRESHOLD || "0", 10);
  const includeGaps = process.env.INCLUDE_GAPS === "1";
  const checkShallow = process.env.CHECK_SHALLOW === "1";
  const checkFreshness = process.env.CHECK_FRESHNESS === "1";
  const nowIso = process.env.NOW_ISO;
  const recommend = process.env.RECOMMEND === "1";
  const includeArchived = process.env.INCLUDE_ARCHIVED === "1";

  // Load catalog.
  let catalogIds = [];
  let catalogEntries = {}; // id -> {fetch_frequency, ...}
  if (fs.existsSync(catalogPath)) {
    const content = fs.readFileSync(catalogPath, "utf8");
    const blocks = content.split(/^- id:/m).slice(1);
    for (const blk of blocks) {
      const idMatch = blk.match(/\A?\s*([a-zA-Z0-9_-]+)/);
      if (!idMatch) continue;
      const id = idMatch[1];
      catalogIds.push(id);
      const ff = blk.match(/fetch_frequency:\s*(\S+)/);
      catalogEntries[id] = { fetch_frequency: ff ? ff[1] : "daily" };
    }
  }

  // Walk source tree to find which catalog ids are cited by rules.
  const cited = new Set();
  const ruleProvenance = []; // {rule_id, provenance_count}
  const archivedIds = new Set();
  function walk(d, isArchived) {
    if (!fs.existsSync(d)) return;
    for (const e of fs.readdirSync(d).sort()) {
      const p = path.join(d, e);
      if (e === "_meta") continue;
      const st = fs.statSync(p);
      if (st.isDirectory()) {
        const archHere = isArchived || e === "_archived";
        if (e === "_archived" && !includeArchived) continue;
        walk(p, archHere);
      } else if (e.endsWith(".yaml")) {
        const c = fs.readFileSync(p, "utf8");
        // Find the source: block, then within the next ~20 lines find id:.
        const srcBlockMatch = c.match(/^source:[\s\S]*?(?=^[a-z_]+:|\Z)/m);
        const sm = srcBlockMatch
          ? srcBlockMatch[0].match(/\bid:\s*([a-zA-Z0-9_-]+)/)
          : null;
        const sourceId = sm ? sm[1] : null;
        if (sourceId && isArchived) { archivedIds.add(sourceId); continue; }
        // Per-rule provenance counts. Allow nested braces (messages,
        // options_schema) via lazy match; rule entries do not overlap
        // on id + provenance so the lazy match is safe here.
        const ruleRe = /\bid:\s*([a-zA-Z0-9_/-]+)[\s\S]*?\bprovenance:\s*\[([^\]]*)\]/g;
        let m;
        while ((m = ruleRe.exec(c)) !== null) {
          const rid = m[1];
          const prov = m[2];
          const provSourceMatches = prov.match(/source:/g) || [];
          ruleProvenance.push({ rule_id: rid, provenance_count: provSourceMatches.length });
          const sources = prov.match(/source:\s*([a-zA-Z0-9_-]+)/g) || [];
          for (const s of sources) {
            const id = s.replace(/source:\s*/, "");
            cited.add(id);
          }
        }
      }
    }
  }
  if (tree) walk(tree, false);

  // Compute coverage.
  const totalCatalog = catalogIds.length;
  const covered = catalogIds.filter(id => cited.has(id)).length;
  const coveragePct = totalCatalog > 0 ? Math.round((covered / totalCatalog) * 100) : 0;
  const gaps = catalogIds.filter(id => !cited.has(id));

  // Freshness check.
  const stale = [];
  if (checkFreshness && nowIso) {
    const markerDir = ".claude-tdd-pro/standards-last-fetch";
    if (fs.existsSync(markerDir)) {
      const now = new Date(nowIso).getTime();
      for (const f of fs.readdirSync(markerDir)) {
        const id = f.replace(/\.txt$/, "");
        const lastFetch = fs.readFileSync(path.join(markerDir, f), "utf8").trim();
        const last = new Date(lastFetch).getTime();
        const ageHours = (now - last) / 3600000;
        const ff = (catalogEntries[id] || {}).fetch_frequency || "daily";
        const limit = ff === "daily" ? 24 : (ff === "weekly" ? 168 : 720);
        if (ageHours > limit) stale.push({ id, lastFetch, ff });
      }
    }
  }

  // Shallow provenance.
  const shallow = ruleProvenance.filter(r => r.provenance_count === 0);

  // Build report.
  const lines = [];
  lines.push("## Standards Audit");
  lines.push("");
  lines.push("Overall coverage: " + coveragePct + "% (" + covered + "/" + totalCatalog + " catalog sources cited)");
  lines.push("");
  if (linkTo) {
    lines.push("Coverage details: [" + path.basename(linkTo) + "](" + linkTo + ")");
    lines.push("");
  }
  lines.push("### Per-source state");
  for (const id of catalogIds) {
    lines.push("- " + id + ": " + (cited.has(id) ? "covered" : "uncovered"));
  }
  lines.push("");
  if (includeGaps && gaps.length > 0) {
    lines.push("### Gaps");
    for (const id of gaps) lines.push("- " + id + ": zero citing rules");
    lines.push("");
  }
  if (checkShallow && shallow.length > 0) {
    lines.push("### Shallow provenance");
    for (const r of shallow) lines.push("- " + r.rule_id + ": shallow provenance (no entries)");
    lines.push("");
  }
  if (checkFreshness && stale.length > 0) {
    lines.push("### Stale sources");
    for (const s of stale) lines.push("- " + s.id + ": stale (last fetch " + s.lastFetch + ", limit per " + s.ff + ")");
    lines.push("");
  }
  if (recommend) {
    lines.push("### Recommendations");
    for (const id of catalogIds) {
      if (!cited.has(id)) lines.push("- PROMOTE: any section from source " + id + "; would add coverage for [" + ((catalogEntries[id] || {}).fetch_frequency || "daily") + "]");
    }
    lines.push("");
  }
  if (includeArchived && archivedIds.size > 0) {
    lines.push("### Archived");
    for (const id of archivedIds) lines.push("- " + id + " (in _archived/)");
    lines.push("");
  }

  const out = lines.join("\n");

  if (dryRun) {
    process.stdout.write(out);
    process.exit(0);
  }
  fs.writeFileSync(emit, out);

  if (threshold > 0 && coveragePct < threshold) {
    process.stderr.write("standards-audit: overall coverage " + coveragePct + "% below threshold " + threshold + "% (failing CI gate)\n");
    process.exit(1);
  }
'
