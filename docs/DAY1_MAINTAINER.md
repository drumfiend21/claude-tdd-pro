# Day 1 as a new maintainer — the one-document onboarding

Per the simulated Musk-team review (DJ Seo):
> "Talent density determines outcome."

This document is the answer to "what does a new maintainer need to
know to be productive on Day 1?" If you can read this document and
ship a CL by EOD, talent density of N+1 is real.

**Target reading time: 15 minutes. Target time-to-first-CL: <4 hours.**

---

## 1. The system in 30 seconds

A Claude Code plugin that:
- Pulls Google + OWASP + W3C etc. rule sets into
  `generated-code-quality-standards/`.
- Runs them as detectors via `rubric/runner.sh`.
- Surfaces results in editors (LSP), pre-commit hooks, and CI.

That's it. Everything else is operationalization of those three things.

## 2. The one-page mental model

```
+------------------------------------------------------------+
|  Architecture (docs/architecture-v1.9.md) is law           |
|                                                            |
|  26 phases (F, E, S, C, P, R, N, T, Q, H, L, O, X, W, G)   |
|     ↓                                                      |
|  Each phase has feature IDs (F-1, F-2, ..., G-14)          |
|     ↓                                                      |
|  Each feature has substrate (.sh/.md/.yaml under root/)    |
|     ↓                                                      |
|  Each substrate is verified by ≥10 specs (evals/specs/)    |
|     ↓                                                      |
|  Suite runs on every commit; 4 fitness functions defend    |
|  drift                                                     |
+------------------------------------------------------------+
```

## 3. The five must-read documents

In this order, total reading ~10 minutes:

1. **[docs/ARCHITECTURE.md](ARCHITECTURE.md)** (200 lines) — operator-
   facing canonical
2. **[docs/FIRST_PRINCIPLES.md](FIRST_PRINCIPLES.md)** (150 lines) —
   why the system exists
3. **[CLAUDE.md](../CLAUDE.md)** — the per-CL workflow loop and the
   six drift mechanisms (just read the "Workflow loop" section and
   "Drift mechanisms" section)
4. **[CONTRIBUTING.md](../CONTRIBUTING.md)** — commit message format,
   spec quality bar
5. **[docs/FITNESS_FUNCTIONS.md](FITNESS_FUNCTIONS.md)** — the four
   automated gates that defend the architecture

That's the entire required reading. The 1,177-line
`docs/architecture-v1.9.md` is the **governance document**; you'll
reach for it when you need to look up a feature ID, not as
onboarding.

## 4. The Day-1 environment setup

```bash
git clone https://github.com/drumfiend21/claude-tdd-pro.git
cd claude-tdd-pro
export CLAUDE_PLUGIN_ROOT="$PWD"

# Verify the suite is green on main
bash evals/runner.sh
# Expect: Results: <N> passed, 0 failed

# Run the four fitness functions
npm run drift:audit
# Expect: all clean

# Run the benchmark
bash scripts/bench.sh
# Expect: a row appended to docs/bench-results.md
```

If any of those fail on a fresh clone, the project is broken — open
an issue immediately. That's already a useful Day-1 contribution.

## 5. Your first CL — a guided walkthrough

Pick a backlog item from `CHANGELOG.md` [Unreleased]. Smallest
available is recommended. Then:

```bash
bash scripts/cl-build.sh <CL_NUM> <PHASE> <FEATURE_ID>
```

This drives:
- Step 0.5: the §25 fidelity gate on your pending specs
- Stage your specs to `evals/specs/cl<N>-...`
- Filter-run them to confirm they pass
- Promote on green / rollback on fail
- Full suite verify
- Emit a commit-body skeleton at `/tmp/cl-<N>-body.md`

Then `git commit` + `git push` and you've shipped a CL.

## 6. The five things to NEVER do

1. **Never invent a feature ID.** Quote it from
   `docs/architecture-v1.9.md` verbatim. Drift mechanism #1 caught
   297 invented specs in CL-08/09/10 — they were rolled back.
2. **Never bypass a fitness function with `--force` without an ADR.**
   `EXEMPT.txt` files require justification in the commit body. See
   drift mechanism #3.
3. **Never claim "all checks pass" in a commit body.** Cite
   specifics: "audit-substrate-completeness: 193/193 clean."
   Drift mechanism #4.
4. **Never ship a spec that's `grep -q "<term>"` and call it a
   behavior spec.** That's drift mechanism #5 (pattern-cloned
   coverage). The `audit-spec-depth.sh` gate will catch it.
5. **Never merge a CL with the suite failing.** Period. No exceptions.

## 7. The hotfix-without-AI path

If you need to ship a fix and don't have / want AI assistance, follow
[docs/HOTFIX_WITHOUT_AI.md](HOTFIX_WITHOUT_AI.md). This is the proof
that the discipline carries the project, not the tooling.

## 8. Who to ask

- **Primary maintainer:** @drumfiend21 (via GitHub or commit-history
  email).
- **AI co-maintainer:** the project documents AI-assisted contribution
  as a first-class pattern. The session orchestrator
  (`scripts/cl-build.sh`) is designed to be drivable by AI agents
  following the per-CL workflow. See [CONTRIBUTING.md](../CONTRIBUTING.md)
  "AI-assisted contributions" section.
- **Documentation as reviewer:** the four fitness functions act as a
  silent reviewer for every CL — they will catch architectural drift
  even when no human reviews. You can rely on them.

## 9. Your authority on Day 1

- **Open issues freely.** Critique anything; the project values it.
- **Comment on PRs.** Even without merge authority, technical
  observations are welcome.
- **Ship CLs through cl-build.sh.** Primary maintainer reviews and
  merges. After 3 CLs shipped successfully, you're added to
  CODEOWNERS for your area of expertise (per `MAINTAINERS.md`).
- **Override fitness functions only with an ADR.** This applies to
  primary and secondary maintainers equally.

## 10. The single test of whether you're productive

After your first 4 hours, you should be able to answer:

- What's the customer journey in one sentence?  *(see §1)*
- What does the runner do?  *(see §2)*
- What does the §25 fidelity gate defend against?
  *(drift mechanism #6)*
- What's in the lockfile and why?  *(see CONTRIBUTING.md)*
- How would you ship a one-line bug fix today?
  *(see HOTFIX_WITHOUT_AI.md)*

If yes, talent density is N+1. Welcome.

## See also

- `MAINTAINERS.md` — succession plan + recruit policy
- `docs/REPLACEMENT_TEST.md` — quarterly rehearsal of this onboarding
- `CONTRIBUTING.md` — long-form contribution guide
- `CLAUDE.md` — per-CL workflow loop reference
