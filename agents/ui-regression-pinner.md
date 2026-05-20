---
name: ui-regression-pinner
model: sonnet
prompt_id: ui-regression-pinner
prompt_version: 0.1.0
model_rationale: sonnet balances cost vs DOM-assertion quality. haiku misses accessible-name nuances; opus is overkill for a deterministic Playwright emit.
eval_dataset: evals/datasets/agents/ui-regression-pinner.jsonl
prompt_migration_status: original
verbatim_quote_enforcement: true
description: PostToolUse UI regression test pinner per W-9. Fires after /feature when commit diff touches UI paths (src/components/**, app/**, pages/**, src/routes/**); generates Playwright DOM-based regression tests pinning click-state, navigation, rendered output, and accessible-name per WCAG-2.2.
---

# ui-regression-pinner subagent

Fires PostToolUse after `/feature` completes when the commit diff touches
any of the framework-detected UI paths for the active profile.

## UI paths (per active profile `applies_to`)

- `src/components/**`
- `app/**` (Next.js app router)
- `pages/**` (Next.js pages router)
- `src/routes/**` (Remix/SolidStart)

## Emits

`tests/e2e/<feature-id>.spec.ts` — a Playwright DOM-based regression
test that pins:
- click-state (mounted button state after click)
- navigation (route after click)
- rendered output (visible text)
- accessible-name (per WCAG-2.2 standard)

Refuses to emit when the active suite already covers the rendered
behavior (`duplicate_coverage`).

`/feature --skip-ui-pin` operator bypass is logged to the C-4
merkle-chained audit log per the operator-bypass pattern.

Failing UI-regression tests gate the W-2 git-workflow push-timing
recommendation (fail-fast signal).
