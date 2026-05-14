---
name: Self-run the gap-check before requesting commit approval
description: For every CL on this plugin, run the user's gap-check criteria yourself, fix what you find, THEN ask for commit approval — do not make the user prompt the audit
type: feedback
originSessionId: 6d636ecc-f923-462a-943c-a116be00d582
---
**Canonical reference:** the full process is in `CLAUDE.md` at the
project root (auto-loaded by Claude Code every session). This memory
file is a cross-conversation backup; if there's any discrepancy,
CLAUDE.md wins. Both should be kept in sync.

For every changelist (CL) on this project, run this loop **yourself** before
asking the user to approve a commit:

0. **PRE-FLIGHT — architecture fidelity (do this BEFORE writing any spec):**
   Before naming any feature, contract, or §2.X reference, read
   `project-v19-architecture-text.md` (the canonical text saved to
   memory) and **quote the exact feature decomposition** for the scope
   you're about to work in. Examples:
   - About to write Phase E specs? Read §16 and write down the literal
     names of E-1..E-17 from the text. Do not invent or paraphrase.
   - About to write a §2.X cross-cutting contract spec? Read §2 and
     copy the literal heading for that contract.
   - About to define a Phase H feature? Read §11 and use the literal
     H-1..H-11 list.

   **If the text is not loaded** (compaction loss, new session), STOP.
   Either re-read the canonical memory file or request the relevant
   section from the user. Do NOT proceed from inference, ESLint domain
   knowledge, or "what makes sense for this layer." That is the
   substitution mechanism that produced ~297 deviating specs across
   CL-08 through CL-10 — the architecture's E-1 is severity override,
   not "rule registry"; H-1 is token-cost transparency, not
   "adversarial yaml"; §2.7 is the lock file, not "audit log."

1. **Write the unit tests** for the work the CL covers, using ONLY the
   literal architecture feature names and §2.X labels extracted in step 0.

2. **Self-audit** against the user's standing criteria (the same questions
   they used to prompt the assessment manually):
   - "Is all architecture worked on thus far defined by unit tests as
     instructed?"
   - "Are there any gaps due to deviating from instructions?"
   - "Are there areas for strengthening?"

3. **Close the gaps and harden.** Concretely, check for:
   - **Architecture fidelity (NEW, highest priority)**: every folder
     name must match an exact architecture feature ID + descriptive
     label that appears in the text. Cross-reference each E-N, H-N,
     §2.X label against the canonical text — if the topic doesn't
     match, the folder is mislabeled or invented and must be deleted
     or moved before the CL is committed. Do NOT use "I'll flag this
     deviation in the commit body" as a workaround.
   - **10-tests-per-feature rule**: every numbered architectural feature has
     ≥10 specs (active + pending combined). Flag and fix shortfalls.
   - **Non-shallow / every-piece-of-functionality**: each feature's 10 specs
     touch distinct functionality slices, not pattern-cloned variations.
   - **Naming**: zero opaque IDs in spec names (no `F-1`, `E-7`, `(§2.X)`,
     `(C-9)` — replace with descriptive phrases per "use a name that
     describes the thing").
   - **Google testing best practices** (already-codified): hermetic,
     state-asserting (exit_code + stderr_contains), behavior-named,
     no sleep in test body, no external network, public-API only,
     stubs-not-mocks at process boundary, `&&` between SUT and assertion
     when SUT must succeed.
   - **No invented surface area**: CLI flags, script paths, env var
     names that don't appear in the architecture text are inventions.
     Either extract from the text or remove.

4. **Verify**: run `bash evals/runner.sh` and confirm the active suite
   stays clean. Re-audit pending specs.

5. **Then** propose the commit message (with the gap-check results
   summarized in the body) and ask for approval.

**Why:** The user explicitly established this as a workflow pattern after
having to prompt the gap-check manually three times in a row. They want
the audit to be automatic so commit-approval is the only manual gate.

The pre-flight architecture-fidelity check (step 0) was added after a
post-mortem on CL-08 / CL-09 / CL-10 deviation: ~297 specs invented
features the architecture does not define (Phase E rule registry, AST
walker, parallel runner; Phase H all 11 adversarial-security topics;
13 of 14 cross-cutting contract labels). Root cause: I was working
from memory after compaction without the literal architecture text
loaded, and substituted plausible-feeling decompositions (ESLint domain
knowledge for E; "hardening = security" for H; intuitive mappings for
§2.X) when canonical knowledge was absent. The deviation compounded
silently because the user trusted my self-audit, which checked test
quality (Google best practices) but not test scope (does this folder
match an architecture feature). Pre-flight extraction from the text
is the only reliable defense.

**How to apply:** This is the loop for every architectural-definition CL
on `claude-tdd-pro`. Step 0 is non-negotiable — if you can't quote
the literal feature decomposition for the scope, you cannot proceed.
Do not skip steps 2–4 even when the work feels complete; the user
has shown they will catch missed gaps and ask for remediation, which
costs a round-trip. Always summarize the gap-check findings (even
when none) in the commit-approval message so the user can verify you
ran it.
