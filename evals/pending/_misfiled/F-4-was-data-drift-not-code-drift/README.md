# Misfiled: data-drift specs incorrectly labeled F-4

## What is here

10 pending specs originally placed under `evals/pending/F-4/F-4-drift-detection/`.
They test an upstream-content-hash drift detector (walks
`generated-code-quality-standards/`, compares each rule's
`source.content_hash` and `source.fetched_at` against an upstream
fetcher stub, reports drift in JSONL format).

## Why this is misfiled

Per [docs/architecture-v1.9.md](../../../docs/architecture-v1.9.md) §16, F-4 is verbatim:

> **F-4** Drift-detection skill: post-commit scan for `// rubric: ignore`,
> `--no-verify`, repeated bypass; tracks E-5 inline suppressions.

That is **code-side bypass tracking** — scanning committed code for
suppression patterns. The misfiled specs test **upstream data-drift
detection** — comparing fetched standards content hashes to live
upstream values. Two different features.

## Where the behaviors actually belong

The closest architectural homes are:

- **S-2** Standards fetcher (per-tier fragility behavior; high tier
  silent-replaces, medium tier prompts on >5% structure delta).
- **S-13** Daily-fresh fetch guarantee (per-operation gate).
- **S-16** Live freshness gate on rule activation (auto-demote/restore
  — but S-16 already has its own 10 pending specs covering the
  demote/restore behavior).
- An **unnamed sub-feature** of S-2/S-13/S-16 — the actual content-hash
  comparator that powers the freshness gates.

## Disposition

- Detected: CL-52/53 (during §20 Week 2 scan).
- Action: parked here intact; no substrate written; no specs promoted.
- Resolution: when §20 Week 5-7 brings S-phase work online, evaluate
  whether these belong to S-2 fragility behavior, a new
  `standards/freshness-check.sh` sub-feature, or are subsumed by the
  S-16 demote/restore mechanism. Rewrite to architecture-named paths
  at that time.
- The actual §16 F-4 (code-side suppression scan) has no pending
  specs and remains unimplemented in CL plan terms.
