# CTP → GCTP handoff — P-13 BUILT: classify-from-answers (§30.4) + explicit stack (§30.5)

**Written:** 2026-07-05 · **From:** CTP (`claude-tdd-pro`) maintainer session
**Re:** GCTP inbound proposal P-13 (cloud classification from answers) / TICKET-117..118
**Status:** ✅ ASSESSED · BUILT (additive) · TESTED · MERGED TO `main`
**Boundary:** CTP is authoritative on the shipped shape; reconcile your pre-wired tests to the exact strings in §3.

## 0. TL;DR

After §30.3 the kata vision classifies cleanly but to **no cloud platform** — the prose is cloud-agnostic; the
cloud is architectural, not a vision fact. P-13 sources the cloud/stack from the profile. Both halves built:

- **§30.4 (Tier A) — classify from answers.** The classification haystack is now `vision + all business-answer
  values`, so a technology STATED in an answer ("we deploy on AWS") fires its platform type. Works in
  `--classify` mode (Stage 0).
- **§30.5 (Tier B) — explicit stack.** `--stack-add <ns>` declares the stack; cite-or-decline rejects an unknown
  namespace. The declared ns is forced into scope and flows through the existing §30.1/§30.2/§29 surface.

**Re-pin CTP → the SHA in §1 (ADR-0091).**

## 1. Coordinates

| | |
|---|---|
| Repo | `drumfiend21/claude-tdd-pro` (CTP) · Branch `main` |
| Re-pin target SHA | **`a2d05d4`** — `a2d05d4c0831d70d88c0a66c55223102101b90c0` (adopts CL-550+551) |
| Change | `CL-550` (§30.4 Tier A) + `CL-551` (§30.5 Tier B) |
| Files | `commands/full-surface-intake.sh` (classifier haystack + `--stack-add`) |
| Design | `docs/design/v1.14-full-surface-intake.md` · Architecture §30.4 / §30.5 |
| Specs | `evals/specs/cl550-answers-01..04`, `cl551-stack-01..08.json` |

## 2. What was built

**§30.4 — classify from answers.** Haystack = `vision text + every business-answer value`. Raw
`--answers`/`--answer` are parsed directly in the classifier (so Stage-0 `--classify` sees them even though the
S-32 universal layer isn't run there). Word-boundary matching (§30.3) keeps the wider haystack from over-firing.

**§30.5 — explicit stack.** `--stack-add <ns>` (repeatable). Each declared ns is validated against the real rule
surface, forced into scope, and recorded. Composes with everything downstream (probes activate, unprobed
reported, grounding, §29 output).

## 3. THE EXACT SHIPPED CONTRACT (reconcile your pre-wired tests to this)

**CLI:** `full-surface-intake.sh … [--stack-add <ns>]…` (repeatable).

**Namespace validity (cite-or-decline):** a valid `<ns>` is a directory under
`generated-code-quality-standards/` whose name does not start with `_`. Unknown → **reject**:
```
invalid=<ns> reason=unknown-namespace                                   # machine-grep marker (stderr)
stack-add: unknown namespace "<ns>" is not in the rule surface (cite-or-decline)   # human (stderr)
exit code 2
```

**Profile additive keys (v1.1) — tolerate as optional, exactly like `unprobed_in_scope`:**
```json
{
  "workload_classification": {
    "workload_types": [...],
    "namespaces": [...],
    "activated_probe_namespaces": [...],
    "unprobed_in_scope": [...],
    "stack": [                          // §30.5/§30.6 — provenance objects, sorted by namespace, [] when none
      { "namespace": "aws",   "source": "stack-add", "trigger": "--stack-add aws",   "added_at": "<iso-8601 utc>" },
      { "namespace": "react", "source": "stack-add", "trigger": "--stack-add react", "added_at": "<iso-8601 utc>" }
    ]
  },
  "stack": [ /* …same array of provenance objects, top-level… */ ]
}
```

**§30.6 acceptance-test alignment (built per operator directive — the 19 assertions are the spec):**
- **T-B.2 entry shape:** each `stack` entry is an object with exactly the four keys `{added_at, namespace, source, trigger}` (sorted-keys check passes). `source="stack-add"` (CLI provenance; `vision`/`answer` reserved for future haystack-inferred stack). `trigger` = the CLI invocation. `added_at` = ISO-8601 UTC (`--now` or current).
- **T-B.3 idempotency:** repeated `--stack-add <ns>` collapses to ONE entry (dedupe by namespace, first-write wins).

**Markers (stderr):** `--classify` and the run both add `stack=<csv>`. §30.4 adds no new marker (behavioral).

**Five append sites** (where a declared ns lands): (1) `namespaces` (in-scope); (2) `activated_probe_namespaces`
(if it has a probe group); (3) `unprobed_in_scope` (if it doesn't); (4) `workload_classification.stack`;
(5) top-level `profile.stack`.

**Alignment status:** per the operator directive, CTP built §30.6 to your acceptance test (the 19 assertions
are the spec) — the `stack` entry-object shape (T-B.2) and idempotency (T-B.3) now match. The rejection surface
(`invalid=<ns> reason=unknown-namespace`, exit 2) follows the existing probe-rejection convention; if your test
asserts a different *human* rejection wording, that's the one remaining string to confirm — tell me the expected
line and I'll align it. Everything else in §3 is the shipped shape.

## 4. Verification (CTP side)

- Full suite **4,960 / 0** (4947 → 4951 → 4959 → 4960 across CL-550/551/552; §30.6 alignment last).
- Tier A `cl550-answers-01..04`: cloud-from-answer / no-cloud-without-signal / cloud-forces-scope /
  answers-boundary-safe. Tier B `cl551-stack-01..08`: stack-forces-scope / stack-activates-probes /
  stack-recorded / unknown-ns-rejected / declared-noprobe-reported / stack-persisted-grounded / stack-dedupes /
  empty-stack-backcompat.
- Append-only: `git diff --numstat docs/architecture-v1.9.md` = 20 insertions / 0 deletions.
- Back-compat: no `--stack-add` and no cloud-in-answer → classification + profile byte-for-byte unchanged
  except `stack: []`.

## 5. GCTP next steps

1. §15-gated pin bump to the §1 SHA (**ADR-0091**; additive — only `architecture-v1.9.md` §30.4/§30.5 append +
   the `full-surface-intake.sh` classifier/CLI change; no schema-key removal).
2. Tolerate the additive `stack` key in `--validate-profile` (optional field, like `unprobed_in_scope`).
3. Run your `docs/handoff-ctp-p13-acceptance-test.sh` against the new cache; reconcile any string diffs to §3.
4. Re-run the live kata pre-flight: `--classify` on the real vision + `--stack-add aws` (or the operator's
   stated cloud) → `aws-platform` in scope, `stack=[aws]`.
5. Flip `docs/upstream-ctp-proposals.md §P-13` 📋 FILED → ✅ ADOPTED.

## 6. Boundary (unchanged)

CTP did not edit GCTP; GCTP does not edit CTP. Additive: classifier haystack + `--stack-add` + 12 specs +
§30.4/§30.5 append (0 deletions to existing architecture content). Mirror of P-10/P-11/P-12.
