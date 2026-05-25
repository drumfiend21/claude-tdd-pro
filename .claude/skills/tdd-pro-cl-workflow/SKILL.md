---
name: tdd-pro-cl-workflow
description: The per-CL workflow loop for developing the claude-tdd-pro plugin. Use BEFORE writing any new specs, substrate, or commit on this repo. Enforces architecture-quote pre-flight → spec-write → self-audit → verify → propose commit. Reference at the start of every implementation turn.
---

# TDD-Pro CL Workflow Loop

The canonical per-CL process for this plugin. Every commit on `main` follows it exactly. No deviation. The user's job is to approve commits, not to prompt the audit.

The full text lives in [CLAUDE.md](../../../CLAUDE.md) "Workflow loop for every CL". This skill is the invokable summary — when you call it, walk through each step.

## Step 0 — Pre-flight architecture extraction (NON-NEGOTIABLE)

Read [docs/architecture-v1.9.md](../../../docs/architecture-v1.9.md) for the scope you're about to work in. **Quote the literal feature decomposition** before writing any spec. If you can't quote it, you're not ready.

- About to write Phase E specs → Read §10, list E-1..E-17 verbatim.
- About to write a §2.X contract spec → Read §2, copy the literal heading.
- About to define a Phase H feature → Read §11 and use the literal H-1..H-11 list.

Never proceed from memory. The architecture file is in the repo precisely so memory loss across sessions cannot cause drift.

## Step 0.5 — Pending-spec content fidelity check (v1.9.2 §25)

**Only applies when this CL promotes pre-existing pending specs (via `probe-feature` or `promote-pending`) rather than writing fresh ones in Step 1.** Run the §2.25 fidelity gate before any substrate work:

```bash
bash rubric/detectors/audit-pending-spec-fidelity.sh \
  --pending evals/pending/<phase>/<feature-id>-<label>/ \
  --arch docs/architecture-v1.9.md \
  --section "<§X>"
```

Exit 0 → proceed to substrate. Exit 1 → triage each `unknown_vocab=<token> spec=<file>` line via one of the §25.3 paths: (1) Spec rewrite, (2) Architecture amendment as a separate governance CL, or (3) Misfiled relocation to `evals/pending/_misfiled/<feature-id>/`. Disclose every chosen path in the commit body under "Spec patches in this CL (architecture-fidelity corrections):". See `docs/memory/feedback-pending-spec-content-fidelity.md` for the §2.6 worked example.

## Step 1 — Write the unit tests

Use ONLY the literal architecture feature names and §2.X labels from Step 0. Pending specs go in `evals/pending/<phase>/<feature-id>-<descriptive-label>/`. Active (regression baseline) specs go in `evals/specs/`.

Spec contents must satisfy:

- **Hermetic:** runner provides a clean tmpdir; setup arrays create all fixtures.
- **State-asserting:** `expect.exit_code` is explicit; `expect.stderr_contains` checks meaningful output.
- **Behavior-named:** name describes what the SUT does, not its mechanics. Minimum 20 characters.
- **No opaque IDs in names:** never `F-1`, `E-7`, `(§2.X)`, `(C-9)`. Use descriptive phrases.
- **Google testing best practices:** no sleep in test body (except when testing time-elapsed mechanisms), no external network, public-API only, stubs-not-mocks at process boundary, `&&` (not `;`) between SUT and assertion when SUT must succeed.

## Step 2 — Self-audit (BEFORE asking for commit approval)

Verify all of:

- **Architecture fidelity:** every folder name maps to an exact feature ID + descriptive label that appears verbatim in `docs/architecture-v1.9.md`. If a folder doesn't, it's mislabeled or invented and must be deleted/moved before commit.
- **10 specs per architecture feature** (active + pending combined).
- **Non-shallow:** each feature's specs touch distinct functionality slices, not pattern-cloned variations. Shape-only specs (`test -f <file>`) are acceptable only when the architecture text literally says "ships at install time" for that file.
- **CLI-flag-invention disclosure:** flags not in the architecture text are test-affordances and must be listed in the commit body.
- **Spec count:** confirm new spec count and total pending spec count.

## Step 3 — Verify

Run `bash evals/runner.sh` and confirm the full active suite stays clean. If flake on a known-flaky spec (e.g. the 500ms perf test), retry once and note.

## Step 4 — Propose commit

Write the commit message. Include in the body:

- Per-feature spec counts.
- All audit findings from Step 2 (architecture fidelity, 10-per-feature, non-shallow check, public-API only) — show the audit was run, don't just claim it.
- Architecture sections quoted in pre-flight.
- Any test-affordance flags invented in this CL.
- Numbers: total pending count before/after.
- Next-CL scope per §20 execution order.

Ask "Approve?" — no other questions. The user approves or sends back specific edits.

## Drift mechanisms to watch

Read [docs/memory/project-v19-architecture-canonical.md](../../../docs/memory/project-v19-architecture-canonical.md) for the catalog of what caused prior deviations (CL-08/09/10 invented ~297 specs of wrong features). Key recognition signals:

- You're reasoning "this should be E-N because…" without having quoted the architecture this turn.
- You're writing a spec for a feature whose folder name isn't in `docs/architecture-v1.9.md` if you search for the exact ID.
- You're inventing a new CLI flag and haven't listed it in a "test-affordance" disclosure section.
- The audit results in your commit body are vague ("all checks pass") rather than specific (per-folder mapping table).

If any of these is true: STOP. Re-read the relevant architecture section. Restart the CL from Step 0.

## When to invoke this skill

- At the start of any implementation turn where the next move is "write specs" or "write substrate".
- Before drafting a commit message.
- When unsure whether a spec name / folder / flag would survive audit.

## Related skills

- [`tdd-pro-batch-cl`](../tdd-pro-batch-cl/SKILL.md) — when to ship multiple features in one commit.
- [`tdd-pro-bash32-portability`](../tdd-pro-bash32-portability/SKILL.md) — bash 3.2 / BSD-tool gotchas to check before substrate writes.
