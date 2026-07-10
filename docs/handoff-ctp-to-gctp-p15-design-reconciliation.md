# CTP → GCTP — P-15 design reconciliation (response to GCTP's design consult)

**Written:** 2026-07-05 · **From:** CTP maintainer session
**Re:** GCTP's P-15 design (§30.8/§30.9/§30.10 — family-umbrella / per-project provisioning / PR-promotion) vs CTP's already-landed design (§31/§31.1/§31.2)
**Status:** 🟡 RECONCILING — the two designs are the **same feature**; this maps them, resolves numbering, answers your 5 open questions provisionally, and names the verbatim content CTP needs to finalize (GCTP's design doc is in the GCTP repo, not reachable from this session).

## 0. TL;DR

Good news: **we converged independently.** GCTP's three layers and CTP's three amendments describe the same
system, including the same hard invariant (GCTP "no silent globalization" = CTP "official ruleset is PR-gated,
§31.2"). Two things to settle: (1) **numbering** — CTP owns its architecture numbering, and this feature is
already committed at **§31 / S-58…S-64 / §2.36–38**; GCTP's `§30.8–10` are fine as GCTP-side design refs but
the CTP-canonical IDs are §31. (2) The **five open questions** — provisional answers below, grounded in CTP's
design; confirm my read of each, and send the verbatim §2 shape + §7 questions + 14 assertions so I answer
against your exact wording (P-13 lesson: align to the spec, don't guess).

## 1. Decomposition mapping (they're the same)

| GCTP layer | CTP amendment | CTP feature IDs / contract |
|---|---|---|
| **§30.8** family/umbrella registry + classifier widen | **§31 + §31.1** (S-58/S-59 refined: activate EXISTING umbrella rules) | S-58 resolver, S-59 umbrella registry; §2.36 |
| **§30.9** provisioning + overlay loader | **§31.1** (S-60 search-existing + S-63 per-project store) | S-60 acquire, S-63 `_project/` origin store; §2.37 |
| **§30.10** PR-promotion mechanics | **§31.2** (S-64 promote via PR; acceptance invariant) | S-64 promote-project-rule; §2.38 |

**Terminology bridge:** GCTP "overlay loader" = CTP's aggregator walking the new **`origin: "project"`**
category (`_project/<project-id>/`) alongside the existing `_operator`/`_community` origins — the overlay *is*
the fifth origin. GCTP "no silent globalization" = CTP §31.2: acquisition writes ONLY to the working store;
the official corpus (`generated-code-quality-standards/<ns>/`) changes ONLY via a reviewed PR that MOVES a
rule working→official. Your **byte-identical `active.json` check** is exactly CTP's invariant expressed as a
test — official `active.json` is unchanged by any acquisition; it moves only on a merged promotion PR.

## 2. Numbering reconciliation (CTP owns its architecture)

This feature is already committed to CTP at **§31 / §31.1 / §31.2**, feature IDs **S-58…S-64**, contracts
**§2.36 / §2.37 / §2.38** (CTP `main` `7e930db`; designs `docs/design/v1.22` + `v1.23`). Per the boundary that
has held since P-12 (CTP owns its decomposition; a consumer's numbering is an input, not an assignment — same
as the §27.16 collision correction), please reference the CTP-canonical IDs above. Keep your `§30.8–10` as
internal GCTP design labels if useful, but file any P-15 ticket against **§31 / S-58…S-64**.

## 3. Provisional answers to your 5 open questions

*(Grounded in CTP's committed design; each flags my read of the question — correct me where I've mis-scoped.)*

1. **Registry ownership.** The umbrella/technology registry (`standards/technology-umbrella-registry.yaml`,
   S-59) is **CTP-core and OFFICIAL** — it changes only via PR (§31.2). A project may add *working* registry
   entries in its `_project/<id>/` overlay; those are used for that project and promotable to the official
   registry by the same PR gate. So: CTP owns the official registry; projects overlay working entries; the
   official registry never changes except by review.
2. **Fetcher hint.** Acquisition (S-60) reuses the existing fetchers (`html-anchor` / `markdown-headers` /
   `pdf-section` / `rfc-style`) selected per source exactly as today. If a source's fetcher is ambiguous, add an
   optional `fetcher:` field to the source-catalog schema as the hint. *(Read: "how does acquisition pick a
   fetcher per source?" — confirm.)*
3. **Budget threshold.** *(Read: a cost/time cap on the search-existing acquisition.)* CTP's bound: acquisition
   searches only the sources whose `applies_to`/umbrella matches the tech's umbrella (not the whole corpus),
   with a per-acquisition cap; over-budget → return what was extracted + leave the tech `needs_source` (partial,
   honest). Confirm the threshold is per-technology and where it should live (source catalog vs a config knob).
4. **Cross-family union.** *(Read: a technology spanning umbrellas — e.g. Next.js = frontend + backend.)* When a
   tech resolves to multiple umbrellas, **union** the activated namespaces across all matched umbrellas (dedup);
   §2.36 already makes umbrella namespaces always-applicable — this extends "the umbrella" to "all matched
   umbrellas." Confirm that's the case you mean.
5. **Deprecation flow.** *(Read: how working/official rules are retired.)* Working rules are ephemeral
   (gitignored `_project/`) and expire via the §2.6 freshness gate when their source goes stale; **official**
   rule removal is symmetric to promotion — a reviewed PR (§31.2 applies to removal too), never silent. Confirm
   you want a distinct deprecation marker vs. relying on freshness + PR.

## 4. What CTP needs to finalize

GCTP's `docs/handoff-ctp-p15-…md` + `.harness/consult-work/FEATURE-003/ctp-chat-handoff.md` are in the GCTP
repo — **not reachable from the CTP session** (same access boundary as P-13/P-14's acceptance tests). To lock
the reconciliation, paste:
- **§2 shape proposal** (the exact registry entry shape, the overlay-loader interface, the promotion mechanics)
  so CTP's S-59/S-63/S-64 field names match yours where they cross the boundary;
- **§7 five open questions verbatim** (so my §3 answers hit your exact wording);
- **§4 the 14 acceptance assertions** — CTP will build S-63…S-64 green against them the first time (the P-13
  lesson, applied up front).

## 5. Reconciled build order (once §3 is confirmed + §4 received)

CTP §20 sequence: **S-63** (`_project/` origin category + working/official write-plane split — foundation) →
S-58/S-59 (resolver + umbrella activation) → S-60 (search-existing acquisition) → S-62 (first-class
enforcement from stage zero) → S-64 (promotion PR). CTP holds until we've agreed §3 and CTP has your §4
assertions.

## 6. Boundary (unchanged)

CTP does not edit GCTP; GCTP does not edit CTP. This is design alignment only — nothing built either side. The
one cross-repo action the design introduces is a **reviewed PR into CTP core**, which is exactly the existing
"official rules change only via review" guarantee. Mirror of P-12/P-13/P-14, but designs-first because the
surface is shared.
