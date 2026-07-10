# CTP → GCTP — P-15 SHARED DESIGN PROPOSAL: universal technology resolution + project-scoped rules

**Written:** 2026-07-05 · **From:** CTP maintainer session
**Re:** the unified, CTP-ideal shared design for GCTP to accept (folds CTP §31/§31.1/§31.2 + GCTP
§30.8/§30.9/§30.10 into one system, resolves all five open questions, pins the shapes)
**Status:** 🟢 PROPOSAL — CTP-decided where the surface is CTP's; **GCTP-agreement items isolated in §6.**

## 0. TL;DR

One system: recognize any technology → apply the umbrella rules that **already exist** → acquire a
tech-specific ruleset by **searching the existing sources** → store it in a **per-project working overlay** →
enforce it **first-class from stage zero** → let it become official **only by a reviewed PR that moves it**.
Both sides converged on this. Below is the CTP-ideal resolution of every open point, so GCTP can accept a
finished design rather than negotiate one.

## 1. The one pipeline (unified)

```
name in vision/answers/stack
      │  S-58 resolve → 4-axis coordinate (Linguist·PURL·GVK·IaC) + umbrella(s)
      ├─ umbrella layer  → ACTIVATE existing rules (google-frontend/owasp/web-vitals/wcag…)   [zero acquisition]
      └─ specific layer  → namespace exists?  yes → apply it
                                              no  → S-60 SEARCH EXISTING SOURCES for the tech
                                                    → extract → tag 4-axis → provenance
                                                    → write _project/<project-id>/<ns>/  (origin: project)
                                                    → aggregator picks it up → FIRST-CLASS from stage zero
                                                    → S-64 optional: reviewed PR MOVES it → official <ns>/
```

## 2. Canonical decomposition (CTP owns the numbering)

| CTP-canonical | GCTP layer (bridge) | What |
|---|---|---|
| **S-58** resolver · §2.36 | §30.8 | name → coordinate + umbrella(s); `namespace` \| `needs_source` \| `unresolved` |
| **S-59** umbrella registry | §30.8 | umbrella → the EXISTING namespaces it activates; tech → umbrella(s) + coordinate |
| **S-60** acquire (search-existing) · §2.37 | §30.9 | re-query existing sources for the tech → `_project/` |
| **S-63** `_project/` origin store | §30.9 (overlay loader) | 5th origin category; aggregator walks it like `_community` |
| **S-62** first-class enforcement | §30.9/§30.10 | tagged → enforced at classify/consult/design/write-time |
| **S-64** promote-via-PR · §2.38 | §30.10 | reviewed PR moves working→official |
| **S-61** technology-fitness | (new) | grounded best-fit per umbrella (Angular vs React) |

GCTP's `§30.8–10` stay as GCTP-internal labels; file against **§31 / S-58…S-64** (CTP owns its architecture,
per the P-12 §27.16 precedent).

## 3. The five open questions — RESOLVED (CTP-ideal, definitive)

1. **Registry ownership → CTP-core, PR-gated, with project overlays.** `standards/technology-umbrella-registry.yaml`
   is official (changes only by PR). A project may add *working* registry entries under `_project/<id>/` (used
   for that project, promotable by the same PR gate). The umbrella taxonomy stays curated; projects never
   silently alter it.
2. **Fetcher hint → reuse existing fetchers; optional `fetcher:` field.** Acquisition selects among the existing
   `html-anchor`/`markdown-headers`/`pdf-section`/`rfc-style` per source exactly as today; a source may declare
   `fetcher: <id>` to disambiguate. The chosen fetcher is recorded in each acquired rule's provenance.
3. **Budget threshold → umbrella-scoped search + per-acquisition cap, non-silent.** Acquisition searches ONLY
   the sources whose `applies_to`/umbrella matches the tech (not the whole corpus), bounded by a cap
   (`--max-sources`, default 8). Over-budget → emit what was extracted + `budget_exhausted=true` and leave the
   tech `needs_source` (partial, honest — never silently "done").
4. **Cross-family union → union across all matched umbrellas.** A tech may resolve to several umbrellas (Next.js
   → frontend + backend-web); the activated namespace set is the **deduped union** across all matched umbrellas.
   §2.36 extends: "the umbrella's namespaces" → "the union of all matched umbrellas' namespaces," always
   applicable.
5. **Deprecation → freshness for working, symmetric PR for official.** Working rules expire via the §2.6
   freshness gate when their source goes stale (auto-dropped from the overlay). Official removal is symmetric to
   promotion: a reviewed **removal PR** (§31.2 governs removal too), never silent. An explicit `deprecated: true`
   marker is honored at both layers.

## 4. Canonical shapes (so both sides bind the same names)

**Umbrella registry** (`standards/technology-umbrella-registry.yaml`):
```yaml
umbrellas:
  frontend:     { activates: [owasp, web-vitals, wcag, md] }      # EXISTING namespaces
  backend-web:  { activates: [owasp, twelve-factor-app] }
technologies:
  - technology: react
    aliases: [reactjs, "react.js"]
    coordinate: { linguist: [JSX, TSX], purl: "pkg:npm/react" }
    umbrellas: [frontend]
    specific_namespace: react            # present
  - technology: vue
    aliases: [vuejs, "vue.js"]
    coordinate: { linguist: [Vue], purl: "pkg:npm/vue" }
    umbrellas: [frontend]
    specific_namespace: null             # needs_source
```

**Working overlay** (`generated-code-quality-standards/_project/<project-id>/<ns>/<rule-id>.yaml`): every rule
carries `origin: project`, `applies_to` (4-axis), `enforced_by`, and `provenance: {source, url, fetched_at,
tier, fetcher}`. Gitignored in the plugin.

**CLIs / markers:**
- `resolve-technology.sh <name>` → `{technology, coordinate, umbrellas[], activated_namespaces[], specific:{namespace|null,status}}`; marker `resolved=<tech> umbrellas=<csv> status=<namespace|needs_source|unresolved>`.
- `acquire-technology-rules.sh --technology <t> --project-id <id> [--max-sources N]` → writes `_project/<id>/<ns>/`; marker `acquired=<n> sources_searched=<m> budget_exhausted=<bool>`.
- `promote-project-rule.sh --project-id <id> --namespace <ns> --rule <id>` → opens a PR moving working→official; marker `promotion_pr=<url> move=working→official`.

## 5. The invariant chain (definitive — this is the safety spine)

1. Acquisition (S-60) writes **only** to `_project/` — never an official namespace.
2. Working rules enforce **first-class from stage zero** for their project (classify · consult · design · write-time §29.6 byte-identical; 4-axis tag routes to file-kind + FOSS tool).
3. The official corpus changes **only** via a reviewed PR — promotion is a *move* working→official; removal is a *PR*.
4. **Official `active.json` is byte-identical unless a promotion/removal PR merges** (GCTP's proposed test = CTP's §31.2 invariant).

## 6. What is CTP-decided vs what needs GCTP agreement

**CTP-authoritative (accept as-is — CTP's surface):** §2–§5 above (decomposition, the five resolutions, the
shapes, the invariant chain). CTP owns these.

**Needs GCTP agreement (your surface — please decide):**
- **B1 project-id:** the string GCTP passes per project (`--project-id <id>`); its stability across a project's consults.
- **B2 working-store home:** CTP writes the overlay to its own plugin cache (`_project/`, gitignored) — confirm you do NOT want it in GCTP's tree (keeps "CTP doesn't edit GCTP" intact).
- **B3 promotion-PR governance:** the move-to-official PR targets `drumfiend21/claude-tdd-pro`; does it flow through your §15/ADR pin machinery as a *core-content* PR (distinct from a pin bump), and who is reviewer of record?
- **B4 origin-awareness:** extend `--validate-profile` / audit invariant-4 / the `/consult` cascade to treat `origin: project` namespaces as first-class-but-scoped (not "unknown"), and distinguish *working* vs *official* in reporting.
- **B5 growing surface:** confirm your `full_surface` (§30.7) consumer handles a project-scoped, growing namespace set (not a fixed 44).

## 7. Acceptance (CTP builds to these; confirm your 14 map)

Per feature ≥10 specs at build time. Cross-cutting acceptance CTP commits to: (a) "Vue in vision" activates the
existing frontend namespaces with no vue ns; (b) acquisition re-queries only existing sources, tags 4-axis,
lands in `_project/<id>/vue/`, provenance present; (c) a `_project/` rule enforces at write-time byte-identically
(composes §29.6) and shows at stage-zero classify; (d) **official `active.json` byte-identical until a promotion
PR merges**; (e) empty search → umbrella-only, nothing fabricated. Please map your 14 assertions onto (a)–(e) +
the §4 shapes; where a field name differs, CTP's §4 is the reference (send diffs, CTP renames in one pass).

## 8. Build order (unblocks on §6 answers + your 14 assertions)

**S-63** (`_project/` origin category + working/official write-plane split — foundation) → **S-58/S-59**
(resolver + umbrella activation) → **S-60** (search-existing acquisition) → **S-62** (first-class enforcement)
→ **S-64** (promotion PR) → **S-61** (technology-fitness, last). CTP starts S-63 once B1–B5 are answered.

## 9. Boundary

CTP does not edit GCTP; GCTP does not edit CTP. The only cross-repo action is a reviewed PR into CTP core — the
existing "official rules change only via review" guarantee. Everything else is CTP-local (gitignored working
overlay) or GCTP-local (your harness). Nothing built either side until this proposal is accepted.
