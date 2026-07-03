# CTP → GCTP handoff — P-11 FIXED: full-surface architecture-production grounding consult

**Written:** 2026-07-02 · **From:** CTP (`claude-tdd-pro`) maintainer session
**Re:** GCTP inbound proposal P-11 / handoff `docs/handoff-ctp-p11-consult-118-rule-surface.md`
**Status:** ✅ ASSESSED · CONFIRMED · FIXED (additive) · TESTED · MERGED TO `main`
**Ask fulfilled:** new S-N feature + §2.X contract via the append-only §29 amendment.

## 0. TL;DR
P-11 is correct. The production chain (`business-translate.sh` → `architect-recommend.sh`) grounded
against a hardcoded ~18-source cloud subset and never ingested `rubric/aggregator.sh`'s full surface
(118 rules / 42 namespaces). Fixed additively with **S-56 `commands/full-surface-consult.sh`** +
**contract §2.34** (§29 amendment): the consult engine ingests the full surface and measures a produced
design against every namespace, surfacing un-consulted namespaces as `needs_grounding` (cite-or-decline)
and gating via `--require-complete`. **Re-pin CTP → `234eedf` and unblock TICKET-113.**

## 1. Coordinates
| | |
|---|---|
| Repo | `drumfiend21/claude-tdd-pro` (CTP) · Branch `main` |
| Re-pin target SHA | **`234eedf`** — `234eedf8bb08d18be37d7c2803e1f07f219ed35f` |
| Fix | `CL-541` (§29 / S-56 / §2.34) |
| New command | `commands/full-surface-consult.sh` |
| Design | `docs/design/v1.20-full-surface-grounding-consult.md` · Architecture §29 |
| Specs | `evals/specs/cl541-p11-01..10.json` |

## 2. Assessment (confirmed at pin a69f380)
- `rubric/aggregator.sh` builds the FULL surface: **118 rules**, each with `source_namespace` +
  `provenance[]`, top-level `namespaces_seen` (**42** namespaces).
- `business-translate.sh` grounds against a hardcoded **18-source** `source_id` set;
  `architect-recommend.sh` derives `grounding` only from those concerns. **Neither references the
  aggregator or `generated-code-quality-standards/`** — GAP CONFIRMED.
- Measured on a real produced design: **6 of 42 namespaces consulted, 36 un-consulted** (typescript,
  react, node, owasp, jwt, iam, ansible, azure, cfn, k8s, …).

## 3. The fix (S-56 / §2.34, at 234eedf)
`commands/full-surface-consult.sh --design <technical-requirements.json> [--surface <aggregator.json>]
[--require-complete] [--json]`:
- INGESTS the aggregator (auto-runs it when `--surface` omitted) — the composition the chain lacked.
- A namespace is `consulted` iff the design grounds against ≥1 source a rule in it cites
  (`provenance[].source`); else `needs_grounding` (cite-or-decline, surfaced not omitted).
- Marker: `full-surface-consult rules_total=118 namespaces_total=42 consulted=<c> needs_grounding=<u>
  status=<complete|incomplete>`; per un-consulted ns `consult namespace=<ns> status=needs_grounding`.
- `--require-complete` → exit 1 when any namespace is un-consulted = **the Stage-5 verdict-completeness
  gate (TICKET-113)**.

**Scope (honest):** this closes the COMPOSITION gap + provides the gate. Driving `needs_grounding → 0`
(broadening `business-translate`/`architect-recommend` to emit concerns grounded across all namespaces)
is the follow-on the §2.34 contract now mandates — a larger, separately-scoped CL.

## 4. Verification (CTP side)
- Full suite **4,885 / 0** at `234eedf`.
- `cl541-p11-01..10`: ingests-118-rules · every-namespace-measured · unconsulted-surfaced ·
  real-design-incomplete(P-11) · require-complete-gates · empty-consults-none · auto-composes-aggregator ·
  namespaces-total-full · positive-consult · requires-design. Deterministic + tool-independent.

## 5. GCTP next steps
1. Re-pin `docs/claude-tdd-pro.lock.yaml`: CTP `a69f380 → 234eedf` (ADR-0086-elect).
2. Wire `full-surface-consult --design <produced-design> --require-complete` as the **Stage-5
   verdict-completeness check** to unblock TICKET-113 (it now emits a real completeness verdict).
3. Flip §P-11 → ✅ ADOPTED at `234eedf`.

## 6. Boundary (unchanged)
CTP did not edit GCTP; GCTP does not edit CTP. Additive fix only (new command + specs + §29 amendment;
0 deletions). Mirror of the P-10 round-trip.
