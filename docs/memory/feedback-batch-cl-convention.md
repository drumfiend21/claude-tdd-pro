---
name: Substrate-touch CL batching convention
description: For CLs that touch a shared substrate file (commands/doctor.sh, profiles/active.sh, hooks/scripts/tdd-guard.sh, etc.), batch them into a single CL with per-feature audit in the commit body. Saves ~30% per merged batch without weakening any drift guard from CLAUDE.md.
type: feedback
---

**Rule:** Features that extend the same substrate file (e.g. several H-* CLs that each add a `--check <mode>` branch to doctor.sh) ship as ONE commit, not N commits.

**Why:** During CL-190..196, H-1/H-5/H-7 all extended commands/doctor.sh in distinct ways. I did three separate commits, each with its own full-suite wait (~3-5 min). Batched into one CL with three per-feature audit sections in the body, the suite-wait amortizes once. Saves ~10 min across 3 commits while preserving every drift-guard.

**How to apply:**

1. Pre-flight: identify the substrate file the next 2-3 pending features touch.
2. Promote all features' specs in one pass.
3. Write substrate touching the shared file once.
4. Run a single `bash evals/runner.sh "cl<low>\|cl<mid>\|cl<high>"` to verify all features pass.
5. Commit ONCE with a multi-feature body that includes per-feature audit findings (architecture quote, 10-per-feature count, non-shallow check, test-affordance flags) for EACH feature in the batch.
6. Single full-suite verification before commit, not per-feature.

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

- Features that touch DIFFERENT substrate files: ship separately (no shared work, no savings).
- Features that introduce architectural deviation: ship alone so the commit message reads as the deviation disclosure.
- W-phase features that depend on each other (W-7 → W-8 → W-9): ship in order, not as a batch.

## Reference

Validated in CL-146..161 (the L-7..L-23 batch, 16 features in 1 commit) — no drift detected in the 2026-05-19 architectural audit. The batched commit body cited every feature ID, counts, and audit findings explicitly.
