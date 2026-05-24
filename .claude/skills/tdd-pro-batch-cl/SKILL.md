---
name: tdd-pro-batch-cl
description: Substrate-touch CL batching convention for claude-tdd-pro. Use BEFORE planning the next CL boundary. Decides when to ship multiple features as ONE commit (range CL-N..M) vs. as separate commits. Preserves every drift guard while amortizing full-suite waits.
---

# Substrate-Touch CL Batching Convention

**Rule:** Features that extend the same substrate file (e.g. several H-* features that each add a `--check <mode>` branch to `commands/doctor.sh`) ship as ONE commit, not N commits.

**Why:** During CL-190..196, H-1/H-5/H-7 all extended `commands/doctor.sh` in distinct ways. Three separate commits, each with its own full-suite wait (~3-5 min), is ~10 minutes wasted vs. one batch with three per-feature audit sections. Batching amortizes the suite-wait while preserving every drift-guard from CLAUDE.md.

This convention is the canonical reference for the source-of-truth: [docs/memory/feedback-batch-cl-convention.md](../../../docs/memory/feedback-batch-cl-convention.md).

## How to apply

1. **Pre-flight**: identify the substrate file the next 2-3 pending features touch.
2. **Promote all features' specs in one pass** (cp `evals/pending/<phase>/<feature>/*` → `evals/specs/cl<N>-<feature>-*`).
3. **Write substrate touching the shared file once** (or build new files if substrate doesn't exist).
4. **Filter-run** each promoted feature: `bash evals/runner.sh --filter "cl<N>-<feature>-"` for each, to surface drift before the full-suite wait.
5. **Run a single full-suite** before commit: `bash evals/runner.sh`.
6. **Commit ONCE** with a multi-feature body that includes per-feature audit findings (architecture quote, 10-per-feature count, non-shallow check, test-affordance flags) for EACH feature in the batch.

## What this preserves (CLAUDE.md drift guards)

- ✅ Architecture-quote pre-flight: still done per feature.
- ✅ Folder-name → feature-ID literal match: still done per feature.
- ✅ Test-affordance flag disclosure: still per-feature in commit body.
- ✅ Specific audit findings: still per-feature (counts, mappings).
- ✅ Non-shallow verb-diversity: still per-feature.
- ✅ Filter-run as commit gate: still mandatory.

## What this changes (purely process)

- N commits become 1 commit. CL numbering uses a range: `CL-N..M`.
- Commit message body is longer (per-feature audit sections), not weaker.

## When NOT to batch

- **Different substrate files**: ship separately (no shared work, no savings).
- **Architectural deviation**: ship alone so the commit message reads as the deviation disclosure.
- **W-phase features that depend on each other** (W-7 → W-8 → W-9): ship in order, not as a batch.
- **First-time substrate creation** where each feature needs its own new file: probably batch is still fine, but per-feature audit sections become essential.

## Promotion-only batching (variant)

When existing substrate already satisfies pending specs from multiple features (often the case mid-project), the batch is even cleaner:

1. Probe each feature: `cp evals/pending/X/F/*.json evals/specs/cl<N>-F-*.json && bash evals/runner.sh --filter "cl<N>-F-"`
2. Keep promotions where filter-run is clean; roll back where it fails (substrate gap → ship feature individually with new substrate).
3. Single commit with `[substrate already shipped]` tag and `(N specs pending→active)` count in title.

This pattern landed CL-237..253 (17 L-phase features, 170 specs) in one commit with zero spec patches.

## Commit message template

```
impl: CL-N..M -- F1 + F2 + ... + Fk (<batch label>) (<old>→<new>) [<status tag>]

<2-3 line summary of what the batch covers and why batched>

Active suite: <new>/<new> passed (was <old>, +<diff>).

CL-N — F1 short title
- Substrate (new | already shipped): <files>
- Spec count: 10/10 active (was 0 active, 10 pending → 0 pending).
- Architecture fidelity: <§X F-Y quote>
- Test-affordance flags invented: <list, or "none">

CL-(N+1) — F2 short title
  <same shape>

...

Audit findings:
- Per-folder mapping: cl<N>-F1 → §X F-1; cl<N+1>-F2 → §X F-2; ...
- 10/10 specs per feature, <total> total.
- No opaque IDs in names.
- <new substrate written | no new substrate (promotion-only)>.

Architecture sections quoted: §<X>, §<Y>, ...

Next-CL scope per §20: <what's next>.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

## Reference

Validated on:
- CL-146..161 (16 L-features, 1 commit) — no drift in 2026-05-19 audit
- CL-197 H-8 promotion (10/10 first-run after applying bash-3.2 portability checklist)
- CL-220..236 (15 features, 150 specs, promotion-only)
- CL-237..253 (17 L-features, 170 specs, promotion-only)
- CL-254..263 (10 H-features, 100 specs, promotion-only)

## When to invoke this skill

- After the architecture-quote pre-flight, when deciding the CL boundary.
- When the next 2-3 pending features touch the same substrate file.
- When existing substrate may already satisfy multiple pending features (run the probe variant).

## Related skills

- [`tdd-pro-cl-workflow`](../tdd-pro-cl-workflow/SKILL.md) — the per-CL discipline that runs INSIDE each batch.
- [`tdd-pro-bash32-portability`](../tdd-pro-bash32-portability/SKILL.md) — apply BEFORE writing new substrate inside a batch.
