# Google Engineering Practices — Code Review Standard

Source: https://google.github.io/eng-practices/

This is the condensed, enforceable subset that the `claude-tdd-pro`
skills and the `/pr` command reference. The originals are the canonical
authority — this document restates rules in a format the model can apply
directly.

> **The senior principle**: approve a CL once it definitely improves
> overall code health, even if not perfect. Never approve a CL that
> worsens code health (except true emergencies).

## What reviewers check (the 10 approval criteria)

A reviewer must form a judgment on each.

- **Design** — *most important.* Does the change belong here vs. a library? Does it integrate cleanly with the rest of the system? Are the interactions between new pieces sensible? Is now the right time to add it?
- **Functionality** — Does it do what the author intended, and is that intent good for end-users *and* for future developers who will maintain it? Reviewer actively hunts edge cases, race conditions, deadlocks, concurrency hazards. For UI changes, demand a screenshot/demo — code reading is insufficient.
- **Complexity** — Can a reader understand each line/function/class quickly? Will future devs introduce bugs trying to modify it? **Reject over-engineering**: solve today's known problem, not speculative future ones ("YAGNI"). Generic abstractions added "just in case" are a red flag.
- **Tests** — Unit/integration/e2e as appropriate, **in the same CL** as the production code (not a follow-up). Tests must: actually fail when code breaks, not produce false positives when unrelated code changes, make simple useful assertions, and be split sensibly across test methods. Test code is code — hold it to the same complexity bar.
- **Naming** — Long enough to fully communicate intent, short enough to read. `getUserById` good; `getUsr`, `processData`, `data2` bad.
- **Comments** — Explain *why*, not *what*. If the code needs a "what" comment, simplify the code instead. Exceptions: regex, complex algorithms, non-obvious tradeoffs, Chesterton's-fence rationale. Distinct from API/module documentation, which describes purpose/usage/behavior.
- **Style** — Conform to the language style guide (the absolute authority). Style-guide-mandated = blocking; personal preference beyond the guide = `Nit:` only. **Never bundle large reformatting with logic changes** — split into a pure-format CL first.
- **Consistency** — When the style guide is silent, match the surrounding code, unless that local convention is actively harmful. File a TODO + bug for cleanup of inconsistencies rather than expanding scope.
- **Documentation** — If the CL changes how users build, test, deploy, or call the code, READMEs / reference docs / runbooks must be updated in the same CL. Deleting code → consider deleting its docs.
- **Every line** — Reviewer reads every human-written line. Skim only generated code, data files, large fixtures. If you can't understand a section, ask the author to clarify (don't approve hopefully).

Plus three meta-checks:

- **Context** — Look beyond the diff hunks. A 4-line addition inside a 50-line method may signal the method needs splitting.
- **Specialized review** — Privacy / security / concurrency / accessibility / i18n need a qualified reviewer; flag if missing.
- **Good things** — Call out what the author did well. Mentoring is part of review.

## CL/PR description format

A description is a **permanent record** future engineers will search and rely on.

**Required structure:**

1. **First line** — Short, focused, imperative summary that stands alone in `git log`. Complete sentence written as an order. Followed by a blank line.
   - Good: `Delete the FizzBuzz RPC and replace it with the new system.`
   - Bad: `Deleting FizzBuzz RPC and replacing...` (gerund), `Fix bug` (no info), `Phase 1` (no info), `[banana peeler factory factory][apple picking service] Assemble fruit basket.` (tag overload).
2. **Body — What changed.** Major changes summarized so a reader gets the gist without reading the diff.
3. **Body — Why.** Problem being solved, why this approach over alternatives, decisions not visible in code, known shortcomings/tradeoffs.
4. **Context links** — Bug numbers, design docs, benchmark results. Inline enough context that the CL is understandable even if external links rot.
5. **Tags (optional)** — `[area]`, `#tag`, or `tag:`. Keep short; prefer body over first line if long.

**Good example (functionality change):**

```
RPC: Remove size limit on RPC server message freelist.

Servers like FizzBuzz have very large messages and would benefit from
reuse. Make the freelist larger, and add a goroutine that frees the
freelist entries slowly over time, so that idle servers eventually
release all freelist entries.
```

**Re-review the description before submit** — CLs evolve during review; the description must still match the final diff.

## Size + scope rules

The unit is **one self-contained change**.

**Hard heuristics:**

- ~100 lines: usually fine. ~1000 lines: usually too large.
- Spread matters: 200 lines in 1 file may be fine; 200 lines across 50 files is not.
- Reviewers may **reject outright for size alone.**
- "Too small" almost never happens — when in doubt, smaller.

**A CL is right-sized when:**

- It addresses exactly one thing (one slice of a feature, not the whole feature).
- It includes the related tests.
- It includes a usage example if it adds a new API.
- Everything needed to understand it is in the CL, the description, the existing codebase, or a previously reviewed CL.
- The system still works for users and developers after submit.

**Large CLs acceptable only when:**

- Pure deletion of files.
- Output of a trusted automated refactoring tool.
- Pre-negotiated with the reviewer (rare).

**Never bundle:**

- Refactoring + feature change. (Tiny renames inside a feature CL are OK.)
- Reformatting + logic change.
- Multiple independent features.
- Unrelated drive-by fixes.
- Proto/schema changes + the code that consumes them (split — they can review in parallel, submit in order).

**Splitting strategies:**

- **Stacked CLs** — write CL #2 on top of CL #1 while #1 is in review.
- **By file group** — different reviewers, self-contained subsets.
- **Horizontal** — by layer (model → service → API → client).
- **Vertical** — by feature slice (full-stack thin slice).
- **Test-first CL** — characterization tests landing before the refactor they protect.

**If you genuinely can't split:** get reviewer consent in advance, expect a long review, write extra tests, do not introduce drive-bys.

## Author best practices (handling comments)

- **Don't take it personally.** Critique is about the codebase, not you.
- **Never reply in anger.** Comments live forever in the tool.
- **Fix the code, not the comment thread.** If a reviewer didn't understand something, the right response is usually to clarify the code; second-best is a code comment; last resort is an explanation only in the review tool.
- **Disagree collaboratively, with data:**
  - Bad: "No, I'm not going to do that."
  - Good: "I went with X because of [pros/cons] with [tradeoffs]. My understanding is Y would be worse because [reasons]. Are you suggesting Y better serves the original tradeoffs, that we should weigh them differently, or something else?"
- **When to push back:** when you have context the reviewer lacks (user data, prior decision, performance numbers).
- **When to defer:** style preferences in your favor; nits in code you'll touch again soon; anything where the reviewer's option is also valid.
- **When to escalate:** consensus fails after a real attempt. Path: chat → tech lead → code maintainer → eng manager.
- **Resolve every comment.** Mark `Done`, reply with rationale, or `Will-do in follow-up CL #NNNN`.
- **Comment severity labels:**
  - `Nit:` — polish; optional.
  - `Optional:` / `Consider:` — reviewer thinks it's a good idea, not required.
  - `FYI:` — informational, no action expected.
  - Unlabeled = required.

## Reviewer turnaround norms

- **Max latency: one business day** to first response.
- **Don't break flow** — review at natural breaks, not interrupts.
- **Response time > total time.** Authors tolerate multi-round reviews if each round is fast.
- **Too busy?** Send a holding response with ETA or alternate reviewer.
- **Cross-time-zone:** finish before the author's next workday.
- **LGTM-with-comments** to unblock when comments are non-blocking or trivial.
- **An LGTM means "this meets our standards."** Don't rubber-stamp under speed pressure.

## Meta / Phabricator-specific conventions

(From public Phabricator/Phorge docs and ex-Meta engineering blog posts; verify against current `arc` config before treating as canonical.)

- **One-diff-per-change** is enforced culturally and by tooling.
- **Stacked diffs are the default workflow.** Each commit on a branch becomes its own reviewable diff (`D12345`); dependencies expressed via `Depends on D12344`.
- **Test Plan is a required field** in every Phabricator diff. Summary answers *why*, Test Plan answers *how I verified it works*. Acceptable contents:
  - Commands run + observed output (`buck test //foo:bar`, paste of green output).
  - New unit/integration tests added.
  - Manual UI verification with screenshots / screen recording.
  - Load-test or benchmark numbers, before/after.
  - For pure refactors: "Existing tests pass; no behavior change intended."
  - "Tested in prod" or empty Test Plan → reject.
- **CI signal must be green** before requesting human review.
- **Land via the tool** (`arc land`), not manual push.
