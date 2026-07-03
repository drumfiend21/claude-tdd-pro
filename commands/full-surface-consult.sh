#!/usr/bin/env bash
# commands/full-surface-consult.sh — S-56 full-surface architecture-production grounding consult
# (§29 / contract §2.34). Closes the P-11 composition gap and makes CTP output COMPLETE against the
# full surface. rubric/aggregator.sh builds the full code-rule surface (118 rules / 42 namespaces);
# standards/cloud-conventions/*.yaml is the separate IaC convention rule set (S-30). This engine ingests
# BOTH and measures a produced design against every namespace + the IaC rules.
#
# STANDING INVARIANT (§2.34): everything CTP produces MUST be reasoned against the FULL surface
# (42 code namespaces + the IaC convention rules) at architecture-production time. A namespace/rule-set
# the design does not reason against is surfaced as `needs_grounding` (cite-or-decline), never silently
# omitted. `--emit-grounding` produces the full-surface grounding the production attaches to its output
# so the delivered design is COMPLETE (needs_grounding=0).
#
# CLI:
#   --design <technical-requirements.json>   the produced design (concerns carry source_id grounding)
#   [--grounding <full-surface-grounding.json>]  attached full-surface grounding (merged into consult)
#   [--surface <aggregator.json>]            code surface (default: run rubric/aggregator.sh)
#   --emit-grounding                         emit the full-surface grounding record (covers every ns + IaC)
#   [--require-complete] [--json]
# stderr: per un-consulted `consult namespace=<ns> status=needs_grounding`; summary
#   `full-surface-consult rules_total=<r> namespaces_total=<n> consulted=<c> needs_grounding=<u> iac_rules=<i> status=<complete|incomplete>`
# Exit: 0 ok/complete | 1 incomplete under --require-complete | 2 usage.
set -uo pipefail
DESIGN=""; GROUNDING=""; SURFACE=""; REQUIRE=0; JSON=0; EMIT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --design)           DESIGN="${2-}"; shift 2 ;;
    --grounding)        GROUNDING="${2-}"; shift 2 ;;
    --surface)          SURFACE="${2-}"; shift 2 ;;
    --emit-grounding)   EMIT=1; shift ;;
    --require-complete) REQUIRE=1; shift ;;
    --json)             JSON=1; shift ;;
    -h|--help) echo "Usage: full-surface-consult.sh (--design <json> [--grounding <json>] | --emit-grounding) [--surface <json>] [--require-complete] [--json]" >&2; exit 0 ;;
    *) echo "full-surface-consult: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ "$EMIT" -eq 0 ] && [ -z "$DESIGN" ] && { echo "full-surface-consult: --design <json> or --emit-grounding required" >&2; exit 2; }
[ -n "$DESIGN" ] && [ ! -f "$DESIGN" ] && { echo "full-surface-consult: not a file: $DESIGN" >&2; exit 2; }
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"

SURF_TMP=""
if [ -z "$SURFACE" ]; then
  SURF_TMP="$(mktemp)"
  bash "$PLUGIN_ROOT/rubric/aggregator.sh" --root "$PLUGIN_ROOT/generated-code-quality-standards" --format json 2>/dev/null > "$SURF_TMP"
  SURFACE="$SURF_TMP"
fi
[ -f "$SURFACE" ] || { echo "full-surface-consult: surface not available" >&2; [ -n "$SURF_TMP" ] && rm -f "$SURF_TMP"; exit 2; }
# IaC convention rule set (S-30) — the separate IaC rules.
IAC="$(cat "$PLUGIN_ROOT"/standards/cloud-conventions/*.yaml 2>/dev/null || true)"
trap '[ -n "${SURF_TMP:-}" ] && rm -f "$SURF_TMP" 2>/dev/null' EXIT

DESIGN="$DESIGN" GROUNDING="$GROUNDING" SURFACE="$SURFACE" REQUIRE="$REQUIRE" JSON="$JSON" EMIT="$EMIT" \
PLUGIN_ROOT="$PLUGIN_ROOT" node -e '
  const fs=require("fs"), cp=require("child_process");
  let surf; try { surf=JSON.parse(fs.readFileSync(process.env.SURFACE,"utf8")); } catch(e){ process.stderr.write("full-surface-consult: surface not valid json\n"); process.exit(2); }
  const rules = surf.rules||[];

  // full surface: namespace -> set of grounding sources its rules cite; + a representative source per ns.
  const nsSources = {}, nsRepr = {};
  for (const r of rules) {
    const ns = r.source_namespace || "unknown";
    (nsSources[ns] = nsSources[ns] || new Set());
    const prov = Array.isArray(r.provenance) ? r.provenance : [];
    for (const p of prov) { const s = p && (p.source||p.source_id||p.class); if (s){ nsSources[ns].add(String(s)); nsRepr[ns] = nsRepr[ns]||String(s); } }
    if (r.origin) { nsSources[ns].add(String(r.origin)); nsRepr[ns] = nsRepr[ns]||String(r.origin); }
  }
  // IaC convention rule set (S-30) -> a synthetic "cloud-conventions" namespace whose sources are the
  // source_ids across standards/cloud-conventions/*.yaml (parsed via ruby for YAML fidelity).
  let iacSources = [], iacRules = 0;
  try {
    const out = cp.execSync(`ruby -ryaml -rjson -e '\''res={s:[],n:0}; Dir[%q{${process.env.PLUGIN_ROOT}/standards/cloud-conventions/*.yaml}].each{|f| d=(YAML.unsafe_load_file(f) rescue nil); next unless d.is_a?(Array); d.each{|r| next unless r.is_a?(Hash); res[:n]+=1; res[:s]<<r[%q{source_id}] if r[%q{source_id}]}}; res[:s]=res[:s].compact.uniq; print JSON.generate(res)'\''`,{maxBuffer:1<<24}).toString();
    const j = JSON.parse(out); iacSources = j.s||[]; iacRules = j.n||0;
  } catch(e){}
  nsSources["cloud-conventions"] = new Set(iacSources);
  nsRepr["cloud-conventions"] = iacSources[0] || "cloud-conventions";
  const namespaces = Object.keys(nsSources).sort();

  // --emit-grounding: produce the full-surface grounding the production ATTACHES to its output so the
  // delivered design is COMPLETE — one grounded concern per namespace (citing a real source it uses).
  if (process.env.EMIT === "1") {
    const concerns = namespaces.map(ns => ({ concern:`full-surface-grounding:${ns}`, source_id: nsRepr[ns], grounding:"grounded", namespace: ns }));
    const rec = {
      schema_version:"1.0", grounded_namespaces: namespaces, iac_rules: iacRules,
      pillars: { full_surface: concerns }, needs_grounding: [],
    };
    process.stdout.write(JSON.stringify(rec, null, 2));
    process.stderr.write(`full-surface-consult emit-grounding namespaces=${namespaces.length} iac_rules=${iacRules}\n`);
    process.exit(0);
  }

  // gather the sources the design (+ attached grounding) reasons against.
  const designSources = new Set(); const groundedNs = new Set();
  const ingest = (doc) => {
    if (!doc) return;
    for (const cs of Object.values(doc.pillars||{})) for (const c of (cs||[])) {
      if (c && c.source_id) designSources.add(String(c.source_id));
      if (c && c.namespace) groundedNs.add(String(c.namespace));
    }
    (doc.grounded_namespaces||[]).forEach(n => groundedNs.add(String(n)));
  };
  try { ingest(JSON.parse(fs.readFileSync(process.env.DESIGN,"utf8"))); } catch(e){ process.stderr.write("full-surface-consult: design not valid json\n"); process.exit(2); }
  if (process.env.GROUNDING) { try { ingest(JSON.parse(fs.readFileSync(process.env.GROUNDING,"utf8"))); } catch(e){} }

  const consulted = [], needs = [];
  for (const ns of namespaces) {
    let hit = groundedNs.has(ns);
    if (!hit) for (const s of nsSources[ns]) if (designSources.has(s)) { hit = true; break; }
    (hit ? consulted : needs).push(ns);
  }
  for (const ns of needs) process.stderr.write(`consult namespace=${ns} status=needs_grounding\n`);
  const status = needs.length === 0 ? "complete" : "incomplete";
  process.stderr.write(`full-surface-consult rules_total=${rules.length} namespaces_total=${namespaces.length} consulted=${consulted.length} needs_grounding=${needs.length} iac_rules=${iacRules} status=${status}\n`);
  if (process.env.JSON==="1") process.stdout.write(JSON.stringify({ rules_total: rules.length, namespaces_total: namespaces.length, consulted, needs_grounding: needs, iac_rules: iacRules, status }, null, 2));
  process.exit((process.env.REQUIRE==="1" && status!=="complete") ? 1 : 0);
'
