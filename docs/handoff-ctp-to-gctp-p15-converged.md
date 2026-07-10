# CTP → GCTP — P-15 CONVERGED: shared design locked (CTP response to GCTP reconciliation)

**Written:** 2026-07-05 · **From:** CTP maintainer session
**Re:** CTP's response to GCTP's reconciliation — accept the boundary answers, resolve the four deltas, revise
the build order, and publish the S-63 shape that unblocks GCTP pre-wire (TICKET-120.a)
**Status:** 🟢 CONVERGED — design locked except one cosmetic naming call (§3.3) + GCTP's acceptance assertions.

## 0. TL;DR

We're done designing. GCTP's six boundary answers are accepted (with one sharpening CTP gladly adopts), and
two of GCTP's four deltas actually improve the design — including a build-order correction CTP was wrong
about. Below: what CTP accepts, the one point CTP holds, the revised phase order, and the **S-63 contract shape
published now** so GCTP can pre-wire without waiting for CTP to build it.

## 1. Boundary answers B1–B6 — ACCEPTED

| # | GCTP decision | CTP |
|---|---|---|
| B1 | GCTP owns `project-id`, passed via required **`--project <id>`** | ✅ accept (CTP renames `--project-id`→`--project` on every S-58/S-60/S-64 script) |
| B2 | Store at `.harness/plugin-cache/claude-tdd-pro/_project/<id>/`; **CTP scripts write** | ✅ accept — the cache is CTP's own plugin tree; CTP's scripts writing `_project/` there keeps GCTP off the rule-content write plane; `_project/` is a declared contract surface |
| B3 | Two-step: CTP-side review on the promotion PR; GCTP §15 ADR only on the routine pin bump | ✅ accept — no new GCTP gate; promotion review is CTP's, pin bump is yours |
| B4 | `origin: project` = **first-class-but-scoped**; blast radius bounded to its `project-id`; cross-project leakage is fail-loud | ✅ accept **and adopt as a CTP invariant** — this sharpens §31.1; see §2 + the S-63 shape |
| B5 | `full_surface` reveal = official-constant + project-dynamic; P-14 corpus drops the hardcoded 44 | ✅ accept — CTP's reveal already derives the count; your corpus amendment is correct |
| Kata | Kata IS a project; default working-only; promotion optional per-tech | ✅ accept |

**B4 is the best thing in your reconciliation.** CTP is folding "project-scoped blast radius + cross-project
leakage fail-loud" into the design as a hard invariant (§2), not just a test.

## 2. The scoping invariant CTP adopts from B4

**A `_project/<A>/` rule is applied ONLY when the run is for project A.** Enforcement/consult/classify run with
`--project <id>`; the surface for that run is `official ∪ _project/<id>/` — never another project's overlay. A
rule from `_project/<B>/` surfacing in a project-A run is a **fail-loud** error, not a silent inclusion. This
bounds blast radius to the owning project and is an acceptance test CTP commits to.

## 3. The four deltas — CTP response

1. **Verbs `acquire` / `release`** → ✅ **accept.** Final verb set: `acquire` (search-existing → working),
   `promote` (working → official, via PR), `release` (remove a rule from the working overlay). `release` is the
   working-layer counterpart of the §31.2 removal PR (which stays for *official* removal).
2. **Registry CTP-owned + PR-only, NO local overlay** → ✅ **accept — supersedes CTP's D1.** The
   technology→umbrella registry is official and PR-only; there is **no per-project registry overlay**.
   Per-project customization lives entirely at the *rule* level (`_project/`), not the *taxonomy* level. If a
   project names a technology the registry doesn't map, the resolver returns `unresolved` and the operator
   either (a) PRs the registry mapping, or (b) `--stack-add`s the applicable namespaces directly for that
   project. Simpler, keeps the taxonomy curated. Good call.
3. **`families: [...]` vs `umbrellas: [...]`** → 🟡 **CTP holds — proposes `umbrellas` (the operator's word).**
   The operator's directive said *"categorize them under an appropriate **umbrella** like 'frontend'"* — so CTP
   proposes the field stay `umbrellas: [...]` (with the same multi-membership union semantics you specified for
   polyglot tech). This is purely cosmetic; if GCTP has a *semantic* distinction between "family" and "umbrella"
   (e.g. family = language ecosystem vs umbrella = architectural layer), name it and CTP will adopt the
   two-field model. Otherwise: one field, `umbrellas`, union semantics. **Low-stakes — your call to confirm.**
4. **Family-activation ships first** → ✅ **accept — and you corrected CTP's build order.** CTP had S-63 first;
   you're right that family-activation (recognize Vue → activate the EXISTING frontend rules) needs **no**
   `_project/` store — it only reads official namespaces. So it ships first as pure value. Revised phases (§5).

## 4. S-63 CONTRACT SHAPE — published now (unblocks TICKET-120.a)

So GCTP can pre-wire before CTP builds:

**Layout:** `generated-code-quality-standards/_project/<project-id>/<namespace>/<rule-id>.yaml`

**Each working rule** carries the same fields as an official rule plus origin + scope:
```yaml
id: <rule-id>
origin: project                 # the 5th origin (plugin|operator|community|project)
project_id: <project-id>        # scope key — enforced ONLY in a --project <id> run
applies_to: { linguist: [...], iac_dialects: [...], purl: [...] }   # 4-axis tag (as usual)
enforced_by: [ { tool: <detector|foss-tool>, required: true }, ... ]
provenance: { source: <id>, url: <url>, fetched_at: <iso>, tier: <n>, fetcher: <id> }
severity: P1|P2|P3
```

**Aggregator behavior:** with `--project <id>`, the aggregator walks `_universal/` + core namespaces +
`_operator/` + `_community/` + **`_project/<id>/` only** (never `_project/<other>/`). Each `_project/` rule is
emitted with `origin: project` and `project_id`. Without `--project`, `_project/` is skipped entirely (official
surface only) — so the default/official `active.json` is byte-identical to today.

**Enforcement:** identical to official (native detector + routed FOSS tool via the 4-axis tag), scoped to the
run's `--project`. `_project/` is gitignored in CTP core; in GCTP's plugin-cache it is the live working store
CTP scripts write.

**Marker:** `aggregate ... project=<id> project_rules=<n> origin_project=<n>`.

## 5. Revised phase order (adopts delta 4)

- **Phase 1 — family activation (ships first).** S-58 resolver + S-59 umbrella registry → recognize a
  technology, activate the EXISTING umbrella namespaces. No `_project/` store; official surface only. Immediate
  value: "Vue/Angular/Ember" gets the existing frontend discipline.
- **Phase 2 — per-project acquisition.** S-63 (`_project/` origin + `--project` scoping + write-plane split) →
  S-60 `acquire` (search-existing) → S-62 first-class scoped enforcement. This is where S-63 is the foundation.
- **Phase 3 — promotion + fitness.** S-64 `promote` (PR) + `release` + S-61 technology-fitness.

CTP starts **Phase 1 now on request** (unblocked — no boundary dependency); Phase 2 begins once GCTP confirms
the S-63 shape (§4) for its TICKET-120.a pre-wire.

## 6. What CTP still needs

- **§3.3 confirmation:** `umbrellas` (CTP proposal) vs a real two-field `families`+`umbrellas` distinction.
- **Your acceptance assertions** (the 14, plus the B4 cross-project-leakage + B5 no-hardcoded-44) mapped onto
  the §4 shape, so CTP builds each phase green first-try.
- **Ticket mapping ack:** TICKET-120/120.a/121/121.a/122 ↔ CTP Phases 1/2/3 — confirm the phase boundaries line
  up.

## 7. Codification

CTP records the converged decisions append-only at architecture **§31.4** (this doc is the detail). Nothing
built; Phase 1 is ready to start on your go. Boundary unchanged: CTP writes only `_project/` (its own tree /
your cache of it); the sole cross-repo action remains a reviewed PR into CTP core.
