---
name: pr-to-eval-dataset
description: Convert a PR diff into eval-dataset entries (before/after pairs) for P-2 prompt-quality datasets.
trigger: after-pattern-extraction
---

# PR-to-Eval-Dataset Skill

Converts an upstream PR diff into one or more eval-dataset entries
(before/after fixture pairs) usable by the P-2 prompt evaluation
substrate. Runs after `pr-pattern-extractor` (L-4) so the extracted
pattern context can tag the dataset entry with its inferred category.

## When to fire

Trigger: `after-pattern-extraction` — the extractor emits a pattern
list, and this skill follows by converting the contributing diff into
dataset entries that downstream prompt evals can score against.

## Inputs

- `--diff <patch>` — unified diff (one or more files)
- `--emit before|after|dataset` — output mode
- `--out <file>` — destination
- `--pattern-category <kind>` — optional tag (security|correctness|...)
- `--pr-number <int>` — optional traceability link

## Output

When `--emit dataset`:
- one JSONL entry per file in the diff
- `{file, before, after, ...}` for normal hunks
- `{file, skipped:"binary"}` for binary diffs
- `{file, before, after:"", deleted:true}` for deletions
- `{file, renamed_from, renamed_to, before, after}` for renames

`pattern_category` and `source_pr` fields are added when the
corresponding flags are supplied.
