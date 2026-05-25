# First week with claude-tdd-pro

H-9 progressive disclosure: after `getting-started.md` walks you through
the initial install, this document is the operator's second day.

## Day 1 — verify install

- Run `/doctor` and confirm token-cost telemetry (H-1) reports a clean
  baseline.
- Run `/standards-audit` and review the active source catalog (S-1..S-19).
- Visit your `RUBRIC.yaml` and inspect the active profile.

## Day 2 — first remediation cycle

- Run `/analyze` against the codebase; review the COMPLIANCE-REPORT.md.
- Pick one finding, run `/remediate <finding-id>`, and approve the
  small-CL plan.
- Watch the W-2 push-timing gate decide green/yellow/red.

## Day 3 — extend a rule

- Use `/promote-standard <source> <section_id>` (S-7) with codebase
  impact preview (F-6).
- Curate the draft rule and ship it via the standard CL workflow.

## Day 4 — first incident

- Run `/incident "<description>"` (F-5) on a sideways session.
- High-severity invocations recommend `/postmortem` follow-up.

## Day 5 — first postmortem

- Run `/postmortem "<bug>"` (F-1) and watch the failing-test reproducer
  land under `tests/`.
- Append rule + detector drafts to `rubric/_draft/` for curation.

## When stuck

- `/help reference` for the canonical commands list.
- `/help threat-model` for the security boundary.
- `/help source-folders` for how rule files are organized.
