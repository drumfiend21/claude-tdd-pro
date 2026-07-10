# CTP → GCTP handoff — P-14 BUILT: Stage-0 full-surface reveal (non-committing)

**Written:** 2026-07-05 · **From:** CTP (`claude-tdd-pro`) maintainer session
**Re:** GCTP inbound proposal P-14 (Stage-0 full-surface reveal, non-committing) / FEATURE-003
**Status:** ✅ BUILT (additive) · TESTED · MERGED TO `main` · **built on CTP's anticipated shape — reconcile to your §4 assertions**

## 0. TL;DR

Even after §30.4/§30.5, Stage-0 (`--classify`) revealed only the classified in-scope subset — **7 of 44**
namespaces for the kata vision — leaving the operator blind to the rest. P-14 reveals the whole surface as a
**non-committing menu**: `full_surface[]`, one entry per namespace, annotated `activated` + `via`. Promoting
a revealed namespace stays explicit via `--stack-add` (§30.5). **Re-pin CTP → `fc423cb` (ADR-0092).**

**Honest note:** your P-14 handoff + the 6 §4 acceptance assertions were **not reachable** from my session
(GCTP repo). I built to the anticipated shape in §3. Per your P-13 ruling ("treat the assertions as the
spec"), **reconcile §3 to your §4** — or paste the acceptance test and I'll align in a fast follow-up.

## 1. Coordinates

| | |
|---|---|
| Repo | `drumfiend21/claude-tdd-pro` (CTP) · Branch `main` |
| Re-pin target SHA | **`fc423cb`** — `fc423cbe29d8e8fafe6a0987000ea1e7e75108a8` |
| Change | `CL-553` (§30.7) |
| Files | `commands/full-surface-intake.sh` |
| Design | `docs/design/v1.14-full-surface-intake.md` · Architecture §30.7 |
| Specs | `evals/specs/cl553-reveal-01..08.json` |

## 2. What was built

Stage-0 `--classify` (and the persisted profile) now carry `full_surface[]` — the whole rule surface (every
namespace folder under `generated-code-quality-standards/`, 44 today), each annotated by whether it is in
scope and how. The reveal is derived, not hardcoded; it changes nothing about scope/probes/grounding.

## 3. THE EXACT SHIPPED SHAPE (reconcile your pre-wired assertions to this)

**`full_surface` — sibling of `workload_classification` on `--classify` stdout, and top-level in the profile:**
```json
"full_surface": [
  { "namespace": "aws",  "activated": true,  "via": "aws-platform" },
  { "namespace": "documentation", "activated": true, "via": "baseline-quality" },
  { "namespace": "helm", "activated": false, "via": null }
]
```
- one entry per real namespace, **sorted by `namespace`**;
- `activated` (bool) — true iff the namespace is in the in-scope set (classifier-inferred OR `--stack-add`);
- `via` — the workload_type that scoped it, `"stack"` if declared via `--stack-add`, else `null`.

**Marker (stderr, on `--classify` and the run):** `full_surface_revealed=<n> activated=<m>`.

**NON-COMMITTING invariant (T-? in your §4):** a revealed-but-un-activated namespace is **not** in
`workload_classification.namespaces`, **not** in `activated_probe_namespaces`, and **not** in
`unprobed_in_scope`. Revealing does not commit. Promotion is explicit: `--stack-add <ns>` flips that entry to
`activated: true, via: "stack"` (and only then does it enter scope / activate probes).

**Likely field-name reconciliation points** (where your §4 may differ): the array key (`full_surface` vs e.g.
`surface`/`revealed`), the annotation key (`activated` vs `in_scope`), and `via` (vs `source`/`scoped_by`).
Tell me your names and I'll rename in one pass — the mechanism is settled; only the labels are in question.

## 4. Verification (CTP side)

- Full suite **4,968 / 0** (4960 → 4968).
- `cl553-reveal-01..08`: reveals-full-surface / reveal-annotated / activated-has-via / unactivated-null-via /
  reveal-non-committing / stack-promotes-reveal / reveal-persisted / reveal-marker.
- Reconciled `cl546-fsintake-02` (its "k8s not in scope" check now parses `activated_probe_namespaces`, since
  the raw JSON now legitimately lists k8s as a non-committing reveal entry).
- Append-only: `git diff --numstat docs/architecture-v1.9.md` = 10 insertions / 0 deletions.

## 5. GCTP next steps

1. Pin bump to **`fc423cb`** (ADR-0092; additive — only `architecture-v1.9.md` §30.7 append + the
   `full-surface-intake.sh` reveal block; no schema-key removal).
2. Run your P-14 acceptance test (6 assertions) against the new cache. Where a field name differs from §3,
   send it — I rename in a fast follow-up (mechanism won't change).
3. Tolerate the additive `full_surface` key in `--validate-profile` (optional, like `stack`/`unprobed_in_scope`).
4. Live kata Stage-0: `--classify` on the real vision → 44 revealed, the in-scope handful `activated:true`, the
   rest a non-committing menu the operator can `--stack-add` from.

## 6. Boundary (unchanged)

CTP did not edit GCTP; GCTP does not edit CTP. Additive: `full_surface[]` + 8 specs + §30.7 append (0
deletions). Mirror of P-10/P-11/P-12/P-13.
