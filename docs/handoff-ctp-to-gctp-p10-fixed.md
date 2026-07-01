# CTP → GCTP handoff — P-10 FIXED: `composite-dispatch.sh` bash-3.2 empty-array crash

**Written:** 2026-07-01 · **From:** CTP (`claude-tdd-pro`) maintainer session
**For:** GCTP (`grok-claude-tdd-pro`) — re-pin and flip P-10 to ADOPTED
**Re:** GCTP inbound handoff `docs/handoff-ctp-p10-composite-dispatch-crash.md` (P-10)
**Status:** ✅ ASSESSED · CONFIRMED · FIXED · TESTED · MERGED TO `main`

---

## 0. TL;DR

GCTP's P-10 report is correct. `rubric/composite-dispatch.sh` expanded EMPTY arrays
`"${ra[@]}"`/`"${toa[@]}"` in its per-tool routing loop; under `set -uo pipefail` on **bash 3.2**
(macOS default) that throws `ra[@]: unbound variable` and aborts before any verdict, leaving the
~80-tool routed-FOSS-tool path **inert on bash 3.2**. Fixed with the empty-safe expansion
`${ra[@]+"${ra[@]}"}`. **Re-pin CTP `4668c2e → 127804b`; no other GCTP change needed.**

## 1. Coordinates

| | |
|---|---|
| **Repo** | `drumfiend21/claude-tdd-pro` (CTP — the plugin) |
| **URL** | https://github.com/drumfiend21/claude-tdd-pro |
| **Branch** | `main` |
| **Fixed SHA (re-pin target)** | **`127804b`** — `127804ba7874d92edd5b1274b6ff2215936ae694` |
| **Fix commit** | `CL-538 (§28.70)` (merged to `main` via merge commit `127804b`) |
| **Changed file** | `rubric/composite-dispatch.sh` (routing loop) |
| **Regression specs** | `evals/specs/cl538-bash32-01..05.json` |
| **Architecture** | `docs/architecture-v1.9.md` §28.70 |
| **This handoff** | `docs/handoff-ctp-to-gctp-p10-fixed.md` |

## 2. What was wrong (exact site, at old pin `4668c2e`)

`rubric/composite-dispatch.sh`, per-tool routing loop:

```bash
ra=(); is_required "$t" && ra=(--required)            # ra EMPTY when tool is not --required (common)
toa=(); _topt="$(… node …)"                            # toa EMPTY when the rule has no tool-options (common)
[ -n "$_topt" ] && toa=(--tool-options "$_topt")
bash "$RUNNER" --tool "$t" --file "$FILE" "${ra[@]}" "${toa[@]}" --json > "$SARIF_DIR/$t.sarif" 2>/dev/null
```

Under `set -uo pipefail` on **bash 3.2.57**, `"${ra[@]}"` on an empty array → `ra[@]: unbound variable`
→ exit 1, **no `dispatch … status=` line**. bash ≥4.4 does not exhibit this (CTP CI runs bash 5.2, so
it was invisible upstream). Class = the classic bash-3.2 empty-array-under-`set -u` gotcha
(bash32-portability checklist #5); same class as P-1.

## 3. The fix (at `127804b`)

Empty-safe expansion — expands to nothing when the array is empty, passes the args when present:

```bash
bash "$RUNNER" --tool "$t" --file "$FILE" ${ra[@]+"${ra[@]}"} ${toa[@]+"${toa[@]}"} --json > "$SARIF_DIR/$t.sarif" 2>/dev/null
```

**Sibling sweep (per your ask):** `run-tool.sh`, `composite-audit.sh`, `sarif-aggregate.sh` — the
`ra`/`toa` pair in `composite-dispatch.sh` was the **only** empty-then-expanded array; every other
array is seeded non-empty (`ea`/`da`/`ba`/`EA`/`AGG_ARGS`/`_tlist`) or uses `:-`/`+=`. Conforms to the
`tdd-pro-bash32-portability` skill.

## 4. Verification (CTP side)

- Full suite **4,875 / 0** at `127804b`; dispatch consumers (`cl491/508/512/523/536`) green.
- `cl538-bash32-01..05`: empty-safe-form-present · pattern-does-not-trip-`set -u` ·
  dispatch-emits-verdict-no-crash (common case: not `--required`, no options) · required/options path
  intact · safe-form-in-loop.
- **Honest caveat:** CTP CI runs bash 5.2, so these specs guard the fix by **shape + functional
  behavior**, not by reproducing the 3.2 crash. Definitive confirmation is a run under `/bin/bash`
  3.2.57 (macOS) — GCTP-side, e.g. `CLAUDE_PLUGIN_ROOT=$PWD /bin/bash rubric/composite-dispatch.sh
  --file <any-routed-file>` should now print a `dispatch … status=` line with no `unbound variable`.

## 5. GCTP next steps

1. Re-pin `docs/claude-tdd-pro.lock.yaml`: CTP `4668c2e → 127804b` (ADR-0072 ADR-gated pin bump).
2. No other change — the already-wired routed-tool paths (ADR-0075 pre-write, ADR-0076 on-save,
   ADR-0077 audit-time) **activate automatically** once dispatch emits real verdicts on bash 3.2.
3. Flip `docs/upstream-ctp-proposals.md` §P-10 🟥 OPEN → ✅ ADOPTED at `127804b`.
4. (Optional but decisive) run the composite path once under macOS `/bin/bash` 3.2 to confirm live.

## 6. Boundary (unchanged)

CTP did not edit GCTP; GCTP does not edit CTP. The only surface that moved is
`rubric/composite-dispatch.sh` + the new `cl538` specs + the §28.70 note. Precedent for this class:
P-1 (adopted in CTP CL-476 / §28.16).

---

## 7. Adoption confirmed (GCTP, 2026-07-01)

GCTP re-pinned `4668c2e → 127804b` (their ADR-0079 / TICKET-107, resolved at GCTP `d5f16b1`) and ran
the **decisive check on `/bin/bash` 3.2.57** — the run CTP CI (bash 5.2) cannot reproduce:

```
before (4668c2e):  composite-dispatch --file  →  "line 119: ra[@]: unbound variable"  (no verdict)
after  (127804b):  composite-dispatch --file  →  "dispatch … status=green|red"        (real verdict)
```

- **Bad file** (`0.0.0.0/0` + `Action:"*"`) → `status=red` via native fallback (correct).
- **Clean file** (.yaml/.md) → `status=green` (native fallback handles absent tools, finds nothing) —
  so the now-live governors **allow clean writes and deny real violations, no false-reds.**
- GCTP suite **41/41** (activating composite-dispatch regressed nothing).

**§P-10 → ✅ ADOPTED.** Both native and the ~80 routed FOSS tools now enforce across GCTP's pre-write
(ADR-0075), on-save (ADR-0076), and audit-time (ADR-0077) surfaces on the default macOS shell. The
honest caveat in §4 is now closed by live bash-3.2 evidence.
