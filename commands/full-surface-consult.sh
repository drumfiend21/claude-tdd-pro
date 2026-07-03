#!/usr/bin/env bash
# commands/full-surface-consult.sh — S-56 full-surface architecture-production grounding consult
# (§29 / contract §2.34). Closes the P-11 composition gap: rubric/aggregator.sh already builds the FULL
# rule surface (118 rules / N namespaces) but the architecture-production chain (business-translate ->
# architect-recommend) grounded only against a ~18-source cloud subset, never ingesting the full surface.
#
# STANDING INVARIANT (§2.34): everything CTP produces for a consumer MUST be reasoned against the FULL
# rule/namespace surface at architecture-production time. This engine ingests the aggregator's full
# surface and measures a produced design against EVERY namespace: a namespace whose rules the design
# grounds against is `consulted`; a namespace the design does not reason against is surfaced as
# `needs_grounding` (cite-or-decline) — never silently omitted.
#
# CLI:
#   --design <technical-requirements.json>   the produced design (concerns carry source_id grounding)
#   [--surface <aggregator.json>]            full surface (default: run rubric/aggregator.sh)
#   [--require-complete]                     exit 1 if any namespace is un-consulted (Stage-5 gate)
#   [--json]
# stderr: per un-consulted namespace `consult namespace=<ns> status=needs_grounding`;
#         summary `full-surface-consult rules_total=<r> namespaces_total=<n> consulted=<c> needs_grounding=<u> status=<complete|incomplete>`
# Exit: 0 ok (or complete) | 1 incomplete under --require-complete | 2 usage.
set -uo pipefail
DESIGN=""; SURFACE=""; REQUIRE=0; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --design)           DESIGN="${2-}"; shift 2 ;;
    --surface)          SURFACE="${2-}"; shift 2 ;;
    --require-complete) REQUIRE=1; shift ;;
    --json)             JSON=1; shift ;;
    -h|--help) echo "Usage: full-surface-consult.sh --design <technical-requirements.json> [--surface <aggregator.json>] [--require-complete] [--json]" >&2; exit 0 ;;
    *) echo "full-surface-consult: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$DESIGN" ] && { echo "full-surface-consult: --design <json> required" >&2; exit 2; }
[ -f "$DESIGN" ] || { echo "full-surface-consult: not a file: $DESIGN" >&2; exit 2; }
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"

# Materialize the full surface if not supplied (INGEST the aggregator — the composition the chain lacked).
SURF_TMP=""
if [ -z "$SURFACE" ]; then
  SURF_TMP="$(mktemp)"
  bash "$PLUGIN_ROOT/rubric/aggregator.sh" --root "$PLUGIN_ROOT/generated-code-quality-standards" --format json 2>/dev/null > "$SURF_TMP"
  SURFACE="$SURF_TMP"
fi
[ -f "$SURFACE" ] || { echo "full-surface-consult: surface not available" >&2; [ -n "$SURF_TMP" ] && rm -f "$SURF_TMP"; exit 2; }
trap '[ -n "${SURF_TMP:-}" ] && rm -f "$SURF_TMP" 2>/dev/null' EXIT

DESIGN="$DESIGN" SURFACE="$SURFACE" REQUIRE="$REQUIRE" JSON="$JSON" node -e '
  const fs=require("fs");
  let surf, design;
  try { surf=JSON.parse(fs.readFileSync(process.env.SURFACE,"utf8")); } catch(e){ process.stderr.write("full-surface-consult: surface not valid json\n"); process.exit(2); }
  try { design=JSON.parse(fs.readFileSync(process.env.DESIGN,"utf8")); } catch(e){ process.stderr.write("full-surface-consult: design not valid json\n"); process.exit(2); }
  const rules = surf.rules||[];
  const rulesTotal = rules.length;

  // full surface: namespace -> the set of grounding sources its rules cite (provenance[].source / source).
  const nsSources = {};
  for (const r of rules) {
    const ns = r.source_namespace || "unknown";
    (nsSources[ns] = nsSources[ns] || new Set());
    const prov = Array.isArray(r.provenance) ? r.provenance : [];
    for (const p of prov) { const s = (p && (p.source||p.source_id||p.class)); if (s) nsSources[ns].add(String(s)); }
    if (r.origin) nsSources[ns].add(String(r.origin));
  }
  const namespaces = Object.keys(nsSources).sort();

  // what the produced design reasons against: the grounding source_ids across all its concerns.
  const designSources = new Set();
  const pillars = design.pillars || {};
  for (const cs of Object.values(pillars)) for (const c of (cs||[])) { if (c && c.source_id) designSources.add(String(c.source_id)); }
  (design.needs_grounding||[]).forEach(()=>{});

  // a namespace is CONSULTED iff the design grounds against >=1 source that a rule in that namespace cites.
  const consulted = [], needs = [];
  for (const ns of namespaces) {
    let hit = false;
    for (const s of nsSources[ns]) if (designSources.has(s)) { hit = true; break; }
    (hit ? consulted : needs).push(ns);
  }
  for (const ns of needs) process.stderr.write(`consult namespace=${ns} status=needs_grounding\n`);
  const status = needs.length === 0 ? "complete" : "incomplete";
  process.stderr.write(`full-surface-consult rules_total=${rulesTotal} namespaces_total=${namespaces.length} consulted=${consulted.length} needs_grounding=${needs.length} status=${status}\n`);

  if (process.env.JSON==="1") process.stdout.write(JSON.stringify({
    rules_total: rulesTotal, namespaces_total: namespaces.length,
    consulted, needs_grounding: needs, status,
  }, null, 2));

  process.exit((process.env.REQUIRE==="1" && status!=="complete") ? 1 : 0);
'
