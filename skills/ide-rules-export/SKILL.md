---
name: ide-rules-export
description: X-6 per §23 — one-way IDE rules export. Use when the operator wants to consume the active profile's resolved standards in Cursor / VS Code Copilot / Continue / Aider / Windsurf. Emits a read-only artifact per target IDE; rules never flow back into TDD Pro (the architectural moat — provenance per §2.1, control mapping per §2.9, grounded-standards citation — cannot be reconstructed from systems that do not produce it).
budget_impact_estimate: 0 tokens (mechanical config emit; no LLM in the path).
paths: ["**/*"]
---

# X-6 IDE rules export (§23 amendment)

Reads every rule from the active profile + resolved standards source
folders (G-1 directory) and emits a target-IDE-shaped artifact.

## Targets

- **cursor** — `.cursorrules` + per-rule prompts at `.cursor/rules/<rule-id>.md`
- **vscode-copilot** — `.github/copilot-instructions.md` + `.github/prompts/<rule-id>.md`
- **continue** — `config.json` rules section
- **aider** — `.aider.conf.yml` + `CONVENTIONS.md`
- **windsurf** — `.windsurfrules`

## Invocation

```
/export-rules <ide> [--profile <name>] [--include <ns>] [--exclude <ns>] [--out <dir>] [--skip-fresh] [--dry-run]
```

- `<ide>` — positional; one of `cursor` / `vscode-copilot` / `continue` / `aider` / `windsurf`
- `--profile <name>` — override active profile (default: from `.claude-tdd-pro/userConfig.yaml`)
- `--include <ns>` — include only this source-namespace (repeatable)
- `--exclude <ns>` — exclude this source-namespace (repeatable)
- `--out <dir>` — output root (default: repo root)
- `--skip-fresh` — bypass the §2.17 freshness gate; logged to C-4
- `--dry-run` — emit plan; no file writes (per §2.14)

## Provenance

Output artifacts carry a header stamp:
`profile_snapshot_hash` + `exported_at` + `tdd_pro_version`. `/doctor`
warns when the stamp is stale.

## Cross-references

- §23 v1.9.1 amendment (this skill)
- §2.1 rubric rule schema (per-rule provenance)
- §2.9 controls mapping
- §2.17 freshness gate
- C-4 audit log
- G-1 standards source directory
