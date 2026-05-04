---
name: remember
description: Compound Engineering loop. Convert a recurring mistake (or a hard-won lesson from this session) into a durable rule pinned in CLAUDE.md and, when applicable, a new RUBRIC.yaml rule with a detector. Pattern from Boris Cherny's "every Claude mistake → new rule" practice and Fowler's AI Feedback Flywheel.
disable-model-invocation: true
---

The user wants to capture something that just happened so it doesn't
happen again. Two paths:

## Path A: pin the lesson in CLAUDE.md (always)

1. Ask the user (in one short prompt) to summarize the mistake or
   lesson in one sentence. If they already provided it as
   `$ARGUMENTS`, skip the ask.
2. Append a dated entry to `${CLAUDE_PROJECT_DIR}/CLAUDE.md` under a
   `## Failure-domain log` section (creating the section if absent):
   ```markdown
   ## Failure-domain log

   ### 2026-05-04 — <one-sentence lesson>
   - Context: <one sentence on what was happening>
   - The mistake: <what went wrong>
   - The rule: <imperative phrasing of what to do next time>
   - Trigger: <how future sessions will know this applies>
   ```
3. Reuse the existing `failure-domain-log` skill's discipline. This
   command is the lightweight, in-session entry; the skill handles
   the deep version when invoked directly.

## Path B: promote to RUBRIC.yaml (when mechanically detectable)

If the lesson can be expressed as a check against a diff or a file,
do path A and additionally:

1. Ask whether to promote. Show a one-line preview: "This lesson
   could be a rule. Add to RUBRIC.yaml with a custom detector? (y/N)"
2. If yes, draft the rule entry:
   ```yaml
   - id: g-local-NNN-<short-slug>
     axis: <design|complexity|tests|naming|comments|style|consistency|...>
     severity: P1
     source:
       upstream: "(local rule — captured by /remember)"
       local: CLAUDE.md#failure-domain-log
     detector:
       kind: script
       ref: <slug>.sh
     remediation:
       kind: refusal
       ref: <slug>
     languages: [ANY]
   ```
   Show it; ask for the user's accept token (`CONFIRM-RULE`).
3. On accept, insert the YAML at the end of the rules: list in
   `${CLAUDE_PLUGIN_ROOT}/rubric/RUBRIC.yaml` AND scaffold the
   detector at `${CLAUDE_PLUGIN_ROOT}/rubric/detectors/<slug>.sh` with
   a TODO marker. The user will fill the detector logic when they
   commit the new rule.

## Refusals

- **Don't promote a rule** the user can't articulate as a concrete,
  testable assertion. Vague rules (e.g. "be more careful") belong in
  CLAUDE.md only.
- **Don't add a rule with the same id** as an existing one. If
  promoted twice, increment the suffix.
- **Don't write directly to RUBRIC.yaml without the token.** This is
  the plugin's machine-checkable contract — protect it.

## Output

After path A: print the appended CLAUDE.md entry (4 lines).
After path B: print the rule id added and the detector path
scaffolded; tell the user what to fill in.

Optional argument: $ARGUMENTS — if given, treat it as the lesson
sentence and skip the initial prompt.
