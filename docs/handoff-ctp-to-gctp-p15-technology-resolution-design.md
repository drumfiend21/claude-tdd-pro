# CTP ↔ GCTP handoff — P-15 DESIGN COORDINATION: universal technology resolution + project-scoped rules

**Written:** 2026-07-05 · **From:** CTP (`claude-tdd-pro`) maintainer session
**Re:** align designs before build — §31 / §31.1 / §31.2 (universal tech resolution, search-existing sourcing, per-project working store, PR-gated promotion)
**Status:** 🔵 DESIGN — **nothing built.** This is a two-way design exchange: CTP's design is below; **please reply with GCTP's design for the same functionality** so we agree on the shared surfaces before either side writes code.

## 0. TL;DR

CTP has designed (operator-directed) an open-ended technology→rules capability that extends the existing
scrape→tag(4-axis)→aggregate→apply pipeline. It has real boundary touchpoints with GCTP (project identity,
where the working-rules store lives, the promotion-PR flow into CTP core, and origin-awareness in GCTP's
validator/audit/consult cascade). **Before building, CTP needs GCTP's design for these shared surfaces + a few
decisions (§3).**

## 1. What CTP designed (read these)

At CTP `main` **`7e930db`**:

- **`docs/design/v1.22-universal-technology-resolution.md`** — §31: resolve any named technology to its
  canonical 4-axis coordinate (Linguist / PURL / K8s-GVK / IaC) → umbrella → apply.
- **`docs/design/v1.23-project-scoped-technology-rules.md`** — §31.1 (operator correction) + §31.2 (acceptance
  invariant).
- Architecture reference blocks: `docs/architecture-v1.9.md` §31, §31.1, §31.2.

**The design in five moves:**
1. **Activate existing umbrella rules.** "Vue/Angular/Ember" in the vision → *frontend* umbrella → activate the
   already-scraped rules (Google front-end / OWASP / web-vitals / WCAG). Zero acquisition.
2. **Search existing sources for the specific tech.** Re-query the URLs already in `standards/*sources*.yaml`
   for Vue-specific guidance → extract a new tech-specific ruleset (like React's). No new-source discovery; no
   fabrication.
3. **Store per-project.** Acquired rules land in `_project/<project-id>/<ns>/*.yaml` with `origin: "project"` —
   a fifth origin category the aggregator walks exactly like `_operator`/`_community`. First-class in the
   surface for that project; gitignored so it never dirties the committed core.
4. **Enforce first-class from stage zero.** The instant a rule is tagged into `_project/`, it enforces like any
   core rule: stage-zero detection (classify), consult grounding/probes (§30), architectural design
   (§29.4/§29.6), and development write-time (§29.6 byte-identical; the 4-axis tag routes it to its file kind +
   FOSS tool).
5. **PR-gated promotion (the hard invariant).** A rule becomes OFFICIAL only via an approved PR that MOVES it
   from `_project/<id>/<ns>/` (origin project) to `generated-code-quality-standards/<ns>/` (origin plugin).
   Acquisition writes ONLY to `_project/`; automation never writes an official namespace; the official corpus
   changes only via reviewed PR.

## 2. The shared boundary surfaces (where our designs must agree)

| Surface | CTP side | Needs GCTP design/decision |
|---|---|---|
| **Project identity** | `_project/<project-id>/` keys the working store | Who assigns `project-id`? GCTP runs consults per project (FEATURE-001/003…) — does GCTP pass a stable id to CTP? |
| **Working-store location** | CTP writes to its own plugin-cache `_project/` (gitignored) | Confirm CTP writes to *its* cache, never into GCTP's project tree (boundary: CTP doesn't edit GCTP). Or do you want the store in your tree? |
| **Promotion PR** | S-64 opens a PR into `drumfiend21/claude-tdd-pro` core | Who opens it, who reviews/merges, how does GCTP's §15 pin-bump/ADR governance track a *core-content* PR (distinct from a pin bump)? |
| **Origin-awareness** | rules carry `origin: plugin\|operator\|community\|project` | Do `--validate-profile`, audit-crosscheck invariant-4, and the `/consult` cascade need to tolerate/branch on `origin: project` (a project namespace must not read as "unknown")? |
| **`full_surface` reveal (§30.7)** | acquired `_project/` namespaces appear in the surface | GCTP consumes the reveal — confirm it handles a **growing / project-scoped** surface (not a fixed 44). |
| **Enforcement parity** | project rules run through the same `composite-audit` surface | Likely transparent (they're in the aggregate), but confirm your audit spine needs no origin split. |

## 3. Open decisions for GCTP (please answer)

1. **Project-id contract:** what string does GCTP use per project, and will it pass it to CTP's intake/acquire
   commands (e.g. `--project-id <id>`)?
2. **Working-store home:** CTP's plugin cache (recommended — keeps the boundary clean) or GCTP's project tree?
3. **Promotion-PR governance:** does the move-to-official PR flow through your existing ADR/pin machinery, or a
   new "rule-promotion" lane? Who is the reviewer of record?
4. **Origin in your validators:** will you extend `--validate-profile` / invariant-4 / the `/consult` cascade
   to treat `origin: project` namespaces as first-class-but-scoped, and to distinguish *working* vs *official*
   in your reporting?
5. **Kata interaction:** the kata submission is per-project — should acquired project rules for the kata live
   under the kata's `project-id`, and does the kata run want promotion PRs at all, or working-only?

## 4. What CTP needs from GCTP

**Your design for the same functionality**, so we reconcile before building. Specifically: how GCTP models the
per-project lifecycle, whether you already have a project-scoping / rule-promotion notion on your side, and how
you want the promotion PR + origin-awareness to land in your harness. Mirror of the P-13/P-14 pattern, but this
time we align *designs* first because the surface is shared and neither side has built yet.

## 5. Sequencing (proposed, once aligned)

CTP build order (§20): **S-63** (`_project/` origin category + working/official write-plane split — the
foundation) → S-58/S-59 (umbrella activation) → S-60 (search-existing acquisition) → S-62 (first-class
enforcement) → S-64 (promotion PR). CTP will not start S-63 until we've agreed §3.

## 6. Boundary (unchanged)

CTP does not edit GCTP; GCTP does not edit CTP. This design keeps that intact: CTP writes acquired rules only
to its own gitignored `_project/` store; the only cross-repo action is a **reviewed PR into CTP core**, which is
exactly the existing "official rules change only via review" guarantee. Nothing here is built — this is design
alignment.
