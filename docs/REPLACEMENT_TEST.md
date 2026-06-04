# Replacement test — quarterly proof of bus-factor mitigation

Per the simulated Musk-team review (DJ Seo / Elon):
> "What's your succession plan? Can someone else ship a CL?"

This document defines the **replacement test**: a quarterly rehearsal
that proves the system's bus-factor is mitigated by **discipline +
tools**, not just by the primary maintainer's personal context.

## The test

The primary maintainer (or any current maintainer) hands the system
to a stand-in (a fresh AI session, a human pair, or even themselves
after deliberately forgetting context) and asks:

**"Ship a CL from cold start using only the repository's
documentation. No questions to the original maintainer. No
external context. Measure wall-clock time from clone to merged PR."**

### Pass criteria

- The stand-in completes a CL.
- The suite is green at merge.
- All four fitness functions are clean.
- Wall-clock from clone to merge is **<8 hours** (target),
  **<24 hours** (acceptable).

If pass: bus-factor is mitigated for the rehearsal period.

If fail: identify the missing documentation or tool, ship it, retest.

## Rehearsal log

| Date | Stand-in type | CL shipped | Wall-clock | Pass? | Gaps identified |
|---|---|---|---|---|---|
| _(scheduled)_ | _(AI session, fresh)_ | _(TBD)_ | _(TBD)_ | _(TBD)_ | _(TBD)_ |

Rehearsals are scheduled quarterly. Results landed via PR titled
"replacement-test: Q&lt;N&gt; &lt;year&gt;" and the row above is
appended.

## Why this works as A-grade talent density

Musk-team rubric for talent density traditionally measures head-
count: "How many top-tier engineers per million lines of code?"

This project has 1 primary maintainer + 1 AI co-maintainer + 4
fitness functions that act as silent reviewers. Head-count is 1.

But the **bus-factor-equivalent** metric — "if this person is hit by
a bus, how long until someone else ships?" — is what actually
matters for risk. The replacement test measures that directly. If
the test passes, the bus factor is **effectively** mitigated even
at a head-count of 1.

The transformation is:

> "Talent density = 1, but the discipline is so explicit and the
> tools are so thorough that any senior engineer (or AI agent) can
> become talent #2 within 4 hours of clone time."

Musk-team-wise: this is a different formula for the same outcome.
It's the equivalent of replacing a 3-person factory shift with one
person + extensively-documented robotics. The output is the same; the
risk profile is different but bounded.

## The AI co-maintainer pattern (explicit)

The project explicitly documents AI-assisted contribution as a
first-class pattern. This is not a workaround for talent shortage;
it is a design choice with documented risks (see
`docs/HOTFIX_WITHOUT_AI.md` for the emergency-path mitigation).

The AI co-maintainer:
- Drives `scripts/cl-build.sh` to ship CLs.
- Reads `docs/architecture-v1.9.md` and quotes it verbatim per the
  per-CL workflow.
- Cannot bypass fitness functions; they apply equally.
- Cannot merge to `main` without the primary maintainer's `git push`.
- Records its presence in commit `Co-authored-by:` trailers per
  CONTRIBUTING.md.

## Why this also moves the production-reality dimension

Bus-factor mitigation and production reality compound. A system that
ships without telemetry can't be debugged remotely; a system that
ships with one maintainer can't be debugged at all when that
maintainer is unavailable. The replacement test + the production
telemetry pipeline (`commands/telemetry-report.sh`) together mean:

- Any future maintainer can read the telemetry to understand current
  production state.
- Any future maintainer can drive the orchestrator to ship a fix.
- The discipline carries the project, not the personnel.

This is the Musk-team-A version of "talent density."

## Next steps to elevate further

- **Recruit a second human maintainer** per `MAINTAINERS.md`.
  Document their first replacement-test rehearsal in the log above.
- **Add a peer-AI as backup co-maintainer**: a different model
  family (Claude, Grok, GPT-4) drives a CL under the same per-CL
  workflow. Logs the difference in approach.
- **Open-source the cl-build orchestrator as a generalized
  framework.** Other AI-assisted projects can adopt the pattern,
  validating it externally.
