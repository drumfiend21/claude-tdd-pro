---
name: tdd-feature-build
description: Use when the user describes a NEW feature to add ("add X to Y", "implement Z", "build a feature that…", "make it possible to…"). Enforces TDD — failing test first, minimum code to pass, refactor. Refuses to ship code without a test that demonstrably catches its absence. Does NOT trigger on bug fixes (use bug-fix-discipline) or refactors (use test-first-extract). Will ask 1-3 clarifying questions before writing any code; safe to delegate from /feature command.
---

# TDD Feature Build

You are building a new feature using strict test-driven development.
The user describes WHAT they want; you decide HOW, and you build it
the right way.

## Pre-flight (do this once, before any code)

1. **Read the standards.** Look for `QUALITY-BAR.md` at the project
   root. If absent, fall back to the plugin's at
   `${CLAUDE_PLUGIN_ROOT}/QUALITY-BAR.md`. Internalize: naming,
   formatting, types, error handling, forbidden patterns.
2. **Read the project's CLAUDE.md** (if present) for any
   project-specific conventions that override the defaults.
3. **Detect the test framework.** Look at `package.json` /
   `pyproject.toml` / existing `*.test.*` files. If no framework
   is set up at all, STOP and tell the user to run `/init-guardrails`
   first — TDD without a test runner is a non-starter.
4. **Check git state.** If there are uncommitted changes, tell the
   user and ask whether to (a) commit them as a separate WIP first,
   (b) stash, or (c) include them in the upcoming feature commits.
5. **Create a feature branch** from the current HEAD:
   `git switch -c feature/<short-slug>`. Do not work on `main`/`master`.

## Clarifying questions (ask 1–3 before writing any code)

If the feature is ambiguous in any of these dimensions, ASK before
proceeding. Do not assume.

- **Behavior boundary**: what does success look like? What are 2-3 happy
  cases and 2-3 edge cases?
- **Data shape**: any new state, props, fields, schema changes?
- **UI surface** (if applicable): where does this appear? Does it need
  to integrate with existing components or is it standalone?
- **Persistence**: does this need to survive reload (localStorage / DB)?
- **Auth scope**: who can do this — anonymous, logged-in, owner-only?
- **Failure modes**: what should happen on network error / invalid
  input / concurrent modification?

If the user has already answered all of these in their request, skip
to the next section.

## The TDD cycle (one cycle per scenario)

For each scenario you identified above, run a complete red-green-refactor
cycle. **Do not write multiple scenarios in one cycle.**

### Red

1. **Write a failing test** that captures exactly this scenario. Use
   the project's existing test structure as a guide. Apply the strict
   assertions from `QUALITY-BAR.md`:
   - `getByRole('button', { name: /Save/ })` not `queryAllByText`.
   - Exact equality where possible; `toHaveLength(N)` not `>= 1` unless
     duplicates are inherent.
   - Mock external dependencies (fetch, timers, DOM APIs); never let
     a unit test hit the network.
2. **Run the test.** It must fail. Read the failure message — does it
   fail for the RIGHT reason (the behavior under test isn't there yet)
   or the WRONG reason (typo, missing import, fixture mismatch)?
   - Wrong reason → fix the test, re-run, get to the right red.
   - Right reason → proceed to green.

### Green

3. **Write the minimum code to pass the test.** Not the most general
   solution, not the most "correct" abstraction — the smallest change
   that turns the red into green. YAGNI applies aggressively here.
4. **Run the test.** Should pass.
5. **Run the entire test suite.** Confirm no other tests broke. If
   they did, your minimum code was too aggressive — pull back.

### Refactor

6. **Look at what you wrote with fresh eyes.** Is there duplication
   you should remove? A name that's wrong? A type missing? A
   QUALITY-BAR rule violated?
7. **Refactor in small steps**, running tests after each. Tests must
   stay green throughout. Common refactors at this stage:
   - Extract a helper if you wrote inline logic that has 2+ uses.
   - Rename for clarity (`x` → `userId`).
   - Add type annotations where inference is awkward.
   - Add a comment explaining WHY (never WHAT).

### Commit

8. **Commit the cycle.** Use the format from QUALITY-BAR.md:
   ```
   feat(scope): imperative summary

   What changed and why. Behavior visible to user. Trade-offs noted.

   Behavior: …
   Tests: +N tests covering …; suite NN/NN green.

   Assisted-by: Claude (claude-tdd-pro 0.3.0)
   ```

Repeat for the next scenario.

## After all scenarios are green

1. **Final lint + format + typecheck + test pass.** Everything must
   be green. If any step fails, fix it before declaring done.
2. **Re-read your own diff.** Look for: dead code from refactor,
   commented-out code, leftover `console.log`, TODOs you forgot to
   resolve.
3. **Tell the user the feature is done** with a one-line summary plus
   the suggestion: `Ready for /pr.`

## What to refuse / push back on

- **"Just write it without tests; I'll add them later"** — refuse.
  Tests-after almost never happen, and the test isn't a
  regression-catcher unless it was actually red first. Politely
  explain and proceed with the test.
- **"Don't bother with edge cases for now"** — push back gently.
  Identify the most important 1-2 edge cases (null inputs, empty
  collections, network failure) and at least cover those.
- **"Make it work in the existing god-file"** — push back if the
  god-file is over ~1000 lines. Suggest the new code goes in a
  separate file from day one; integrate via import.

## What to delegate

For multi-scenario autonomous work where the user wants minimal
involvement until PR time, delegate to the `tdd-driver` subagent:
"I'm going to delegate this to the tdd-driver agent which will run the
full red-green-refactor loop autonomously and report back when ready
for /pr."
