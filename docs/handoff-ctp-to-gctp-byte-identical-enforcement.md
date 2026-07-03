# CTP → GCTP handoff — §29.6: byte-identical native enforcement (consult == development)

**Written:** 2026-07-03 · **From:** CTP (`claude-tdd-pro`) maintainer session
**Re:** operator-directed correctness invariant — consult's native enforcement == development's write-time
**Status:** ✅ BUILT · TESTED · MERGED TO `main`
**Change class:** additive + single-source-of-truth refactor. No new feature ID / §2.X contract; no behavior change for GCTP except the consult marker's engine name.

## 0. TL;DR

CTP's architectural-design consult and its development write-time governor now enforce the entire repo
ruleset through **one shared primitive** — `rubric/enforce-write-time.sh`. The native enforcement of
every rule during consult is therefore **byte-identical** to development's write-time enforcement **by
construction** (one code path, no duplicated flag logic), not merely "identical by inspection." **Re-pin
CTP → `de4edec`.** Nothing GCTP calls changes shape; the only observable delta is the consult stderr
marker's engine field: `engine=enforce-file` → `engine=enforce-write-time`.

## 1. Coordinates

| | |
|---|---|
| Repo | `drumfiend21/claude-tdd-pro` (CTP) · Branch `main` |
| Re-pin target SHA | **`de4edec`** — `de4edecdfe70e220b51a68bf6260237052b28b1b` |
| Change | `CL-545` (§29.6) |
| New primitive | `rubric/enforce-write-time.sh` |
| Design | `docs/design/v1.21-byte-identical-native-enforcement.md` · Architecture §29.6 |
| Specs | `evals/specs/cl545-byteident-01..06.json` |

## 2. What changed and why

- **The gap:** §29.5 (`engine=enforce-file`) claimed "byte-identical flags" but achieved it by
  *duplicating* the `enforce-file.sh --single-file-gate [--include-app-code]` invocation independently in
  both callers — the pre-write governor and `architect-session.sh`. Two copies are identical only by
  inspection and can silently drift (e.g. a new app-code extension added to one caller's `case` but not
  the other; a flag added to one path only).
- **The fix — one shared primitive.** `rubric/enforce-write-time.sh <file>` owns the canonical write-time
  flag set in exactly one place:
  - `--single-file-gate` always (tree-context rules like coverage are not per-file decidable → skipped);
  - `--include-app-code` for app-code kinds
    (`.ts .tsx .js .jsx .mjs .cjs .py .go .rb .rs .java .kt .php .cs .swift .scala .ex`);
  - then runs `rubric/enforce-file.sh`.
  - Exit contract: `0` clean/advisory · `1` blocking (P0/P1) · `3` not_enforced · `2` usage.
- **Both callers invoke it, nothing else:**
  - development write-time — `hooks/scripts/enforce-standards-pre-write.sh` → exit `1` denies the write;
  - consult — `commands/architect-session.sh` → `design_enforcement=green|red engine=enforce-write-time
    rules_total=118`.

Because there is exactly one code path, the native enforcement of the entire ruleset is byte-identical
across consult and development by construction.

## 3. Verified byte-identical

Same file → same native verdict, character-for-character. For `a.ts` = `const x: any = 1;`:

- consult-style direct call (`enforce-write-time.sh a.ts`) → `status=red rules_checked=22 blocking=2`,
  exit `1`;
- development governor (Write of identical content) → embeds `status=red rules_checked=22 blocking=2`,
  denies with exit `2`.

The `status= rules_checked= blocking=` summary line is identical.

## 4. Verification (CTP side)

- Full suite **4,911 / 0** at `de4edec` (4905 → 4911; cold run — the `architect-session.sh` change
  invalidates the e2e dependency-closure cache).
- `cl545-byteident-01..06`: one-shared-primitive · byte-identical-verdict · deterministic ·
  fullstack-native-enforced · flags-only-in-primitive · clean-green. Deterministic + tool-independent.
- Reconciled `cl543-abide-08`, `cl544-parity-01`, `cl544-parity-03` (marker engine
  `enforce-file` → `enforce-write-time`; flag assertions moved to the primitive).
- Append-only: `git diff --numstat docs/architecture-v1.9.md` = 10 insertions / 0 deletions.

## 5. GCTP next steps

1. Re-pin `docs/claude-tdd-pro.lock.yaml`: CTP → `de4edec`.
2. If any GCTP stage greps the consult stderr for the enforcement engine, update the expected token
   `engine=enforce-file` → `engine=enforce-write-time` (the `design_enforcement=green|red` field and its
   semantics are unchanged; the routed opt-in `design_enforcement_routed=… engine=composite-audit
   tools=80` under `ARCHITECT_ENFORCE_ROUTED=1` is also unchanged).
3. No interface CTP exposes to GCTP changed shape — `full-surface-consult`, `architect-session`,
   `composite-audit`, and the SARIF bus are all unaffected. This is safe to adopt as a straight re-pin.

## 6. Boundary (unchanged)

CTP did not edit GCTP; GCTP does not edit CTP. Additive primitive + specs + §29.6 amendment (0 deletions
to existing architecture content). Mirror of the P-10 / P-11 round-trips.
