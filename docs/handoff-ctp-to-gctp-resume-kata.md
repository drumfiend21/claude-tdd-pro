# CTP → GCTP handoff — re-pin to `f39fcdc` and RESUME the O'Reilly kata submission

**Written:** 2026-07-05 · **From:** CTP (`claude-tdd-pro`) maintainer session
**Re:** resume the Certifiable, Inc. kata `/consult` after the classifier-precision fix
**Status:** ✅ CTP feature-complete for the kata · classifier verified clean on the real prose · submission isolation hardened
**Supersedes pin:** `43ea692` → **`f39fcdc`** (adds §30.3 + the submission-isolation guard)

## 0. TL;DR

Two things landed since your last pin (`43ea692`):

1. **§30.3 (CL-549) — the classifier-precision fix** for the exact misfires your kata pre-flight caught
   (`aks` matching inside "le**aks**", `ci` inside "certifi**c**ation"/"a**cc**reditation"). Signal matching is
   now **word-boundary**, so the real Certifiable, Inc. vision classifies **cleanly** — `ai-governed` +
   `baseline-quality`, no phantom `azure-platform` / `container-orchestration` / `ci-cd`.
2. **Submission-isolation guard (chore)** — the plugin now gitignores the consult chain's default output
   paths, so a kata submission can never leak into the CTP plugin. Run consult with `--out` into **your own
   submission tree**.

**Re-pin CTP → `f39fcdc` (ADR-0090), then resume the live `/consult` on the actual kata vision.** This is
the go-step you correctly held back from until the classifier was precise.

## 1. Coordinates

| | |
|---|---|
| Repo | `drumfiend21/claude-tdd-pro` (CTP) · Branch `main` |
| Re-pin target SHA | **`f39fcdc`** — `f39fcdc6a8a450a087389f22a95ed17f9cfec7d1` |
| Prior pin | `43ea692` (P-12 §30/§30.1/§30.2 — still valid; this adds §30.3 + guard) |
| Full contract detail | `docs/handoff-ctp-to-gctp-p12-fixed.md` (authoritative v1.1 shape — unchanged) |

## 2. What changed since `43ea692`

| Commit | Kind | What | Adopt? |
|---|---|---|---|
| `b2a6a01` / merge `3e0fec7` | **semantic** | **CL-549 / §30.3** word-boundary classifier matching — the kata-precision fix | **YES (ADR-0090)** |
| `ba6fdc0` / merge `f39fcdc` | chore | `.gitignore` guard: consult/kata output can't be committed into the plugin | adopt-by-pin (no ADR needed) |
| `03d962e` | unrelated | automated "fitness weekly trend row" — not CTP semantic | ignore |

**§30.3 detail:** signal matching changed from substring (`hay.include?(sig)`) to word-boundary
(`(?<![a-z0-9])<sig>s?(?![a-z0-9])`) — alphanumeric boundaries so phrases (`amazon web services`) and internal
punctuation (`ci/cd`) still match; optional trailing `s` so plurals (`microservices`) still match. Can only
**tighten** the classifier (fewer false-positive types), never loosen. **No schema / contract-key change** —
the v1.1 `business-profile.json` shape in the P-12 packet is unchanged; only classification *behavior* is more
precise. 8 new specs (`cl549-precision-01..08`); full suite **4,947 / 0** at this pin.

## 3. Verified pre-flight at `f39fcdc` (reproduce before the live run)

Running `full-surface-intake.sh --classify` on the AI-credentialing prose (certification / accreditation /
content-leak wording) now yields:

```
workload_types            = ai-governed, baseline-quality
activated_probe_namespaces = documentation, european-union, observability, owasp,
                             security-governance, us-government
unprobed_in_scope         = industry-self-regulatory
```

No `azure-platform`, no `container-orchestration`, no `ci-cd`. Real `AKS` / `CI/CD` tokens still fire when
actually present.

## 4. One nuance to decide before the run — the vision is cloud-agnostic

With the noise gone, the kata vision classifies to **no cloud platform type at all** — because the prose is
(correctly) cloud-agnostic; the AWS choice is an **architectural decision**, not a vision fact. So the intake
will **not** probe AWS region strategy from the vision alone. If your `/consult` cascade expects the cloud
target surfaced at intake, source it as a **Stage-2 design-time** question, not a classifier signal. (If you
want the classifier to fire `aws-platform` when the operator *states* "AWS" in a business answer, that's a
small CTP-side signal addition — tell me and I'll add it; otherwise the design-stage sourcing is correct.)

## 5. Submission isolation — write artifacts to YOUR tree

The plugin now gitignores the consult chain's default output paths (`standards/business-profile.json`,
`technical-requirements.json`, `architecture-options.json`, `explanation.md`, `session.*`,
`full-surface-grounding.json`, `architect-session/`). **Convention:** run each consult step with `--out`
pointing into your submission tree (e.g. `../softarchcert-win25/…`) so the deliverable lands where it belongs.
Even without `--out`, an in-repo run can no longer pollute the plugin.

## 6. Go-steps to resume the kata

1. **Re-pin** `docs/claude-tdd-pro.lock.yaml` → `f39fcdc` via **ADR-0090** (semantic change: classifier
   precision; additive contract-drift — only `architecture-v1.9.md` §30.3 append + the classifier corpus /
   `full-surface-intake.sh` matcher line; no schema-key change).
2. **Re-run the pre-flight** (`--classify` on the real vision) → confirm the clean §3 result at the new pin.
3. **Live `/consult`** on the actual Certifiable, Inc. vision, writing artifacts into the submission tree via
   `--out`.
4. **Validate** the produced v1.1 profile: `--validate-profile` → exit 0, `schema_version=1.1`; tolerate the
   additive `unprobed_in_scope` key (per the P-12 packet).
5. **Crosscheck invariant 4** on the produced decisions (keys on `activated_probe_namespaces`).
6. **Assemble the submission** (architecture.json, ADRs, WAR) in the submission tree; flip
   `docs/upstream-ctp-proposals.md §P-12` context to reflect the `f39fcdc` pin.

## 7. Standing offer

I'm on for the live run. If the real prose surfaces anything — a workload type that should fire but doesn't,
a probe prompt that reads poorly to the operator, or the cloud-sourcing decision in §4 — that's the next
targeted CTP-side CL (signal addition, question-bank prompt refinement, or a §30.4 refinement).

## 8. Boundary (unchanged)

CTP did not edit GCTP; GCTP does not edit CTP. All changes additive (matcher line + 8 specs + §30.3 append +
`.gitignore` guard; 0 deletions to existing architecture content). Kata submission lives in the operator's own
tree, never the plugin. Mirror of the P-10 / P-11 / P-12 round-trips.
