# Claude TDD Pro — project instructions for Claude

## ARCHITECTURE IS LAW

**The canonical v1.9 architecture is at [docs/architecture-v1.9.md](docs/architecture-v1.9.md). It is the source of truth for every feature ID, every §2.X cross-cutting contract, every phase decomposition, and every CL plan.**

**Read it at the start of every prompt.** Before naming any feature, contract, folder, spec, or commit message, extract the literal feature ID and label from this file. Do not infer from memory, ESLint domain knowledge, or "what makes sense for this layer." Do not paraphrase. Do not invent.

If you find yourself reasoning "this should be E-N because…" — STOP. The architecture's E-1..E-17 are listed in §16. Look them up. The same rule applies to every other phase (F, G, S, C, P, R, N, T, Q, H, L, O, X, W) and every cross-cutting contract (§2.1..§2.22).

This rule exists because prior CLs (CL-08, CL-09, CL-10) deviated by inventing decompositions: Phase E's rule registry / AST walker / parallel runner / source code analyzer / suggestion API / performance budget were all invented (the architecture has none of those as features); Phase H's adversarial yaml / path traversal / sandbox / secret leak / privilege boundary were all invented (the architecture's H is operator polish: token-cost transparency, SECURITY.md, /doctor --watch, etc.); cross-cutting contract labels §2.7..§2.22 were assigned plausibly-sounding-but-wrong topics. ~297 specs were deleted in CL-11 to remove the deviation.

## Workflow loop for every CL

1. **Pre-flight (NON-NEGOTIABLE):** read [docs/architecture-v1.9.md](docs/architecture-v1.9.md) — quote the literal feature decomposition for the scope you're about to work in. If you can't quote it, you're not ready to write specs.

2. **Write the unit tests** for the work the CL covers. Use ONLY the literal architecture feature names and §2.X labels. Pending specs go in `evals/pending/<phase>/<feature-id>-<descriptive-label>/`. Active (regression baseline) specs go in `evals/specs/`.

3. **Self-audit** before requesting commit approval:
   - **Architecture fidelity:** every folder name maps to an exact feature ID + descriptive label that appears verbatim in `docs/architecture-v1.9.md`. If a folder doesn't, it's mislabeled or invented and must be deleted/moved before commit.
   - **10 specs per architecture feature** (active + pending combined).
   - **Non-shallow:** each feature's specs touch distinct functionality slices, not pattern-cloned variations.
   - **No opaque IDs in spec names** (no bare `F-1`, `E-7`, `(§2.X)`, `(C-9)`).
   - **Google testing best practices:** hermetic, state-asserting (exit_code + stderr_contains), behavior-named, no sleep in test body, no external network, public-API only, stubs-not-mocks at process boundary, `&&` between SUT and assertion when SUT must succeed.
   - **No invented surface area:** CLI flags, script paths, env var names that don't appear in the architecture text are inventions — extract them from the text or remove them.

4. **Verify:** run `bash evals/runner.sh` and confirm 58/58 active suite stays clean. Re-audit pending specs.

5. **Then** propose the commit message. Include the gap-check results in the body so the user can verify you ran it.

The user's job is to approve commits, not to prompt the audit.

## Project state

- Active suite: 58 specs (regression baseline — must stay clean across every CL)
- Pending specs: in `evals/pending/<phase>/<feature-id>/` — invisible to the active runner; promoted to `evals/specs/` when implementation lands
- Substrate already implemented: aggregator (G-5), source-file validator (§2.21 partial), rubric-rule schema validator (§2.1)
- Canonical CL execution order: see §20 of `docs/architecture-v1.9.md`

## What "ALWAYS read the architecture" means in practice

At the start of any task that touches phase work or cross-cutting contracts, the first action is `Read docs/architecture-v1.9.md` (or the relevant section). Examples:

- About to write Phase E specs → Read §16, list E-1..E-17 verbatim, then write specs only for those features.
- About to write a §2.X contract spec → Read §2, copy the literal heading for that contract.
- About to define a Phase H feature → Read §11 and use the literal H-1..H-11 list.
- Asked about phase ordering → Read §20.
- Asked about definition of done → Read §21.
- Asked about file inventory → Read §18.

Never proceed from memory. The architecture file is in the repo precisely so memory loss across sessions cannot cause drift.
