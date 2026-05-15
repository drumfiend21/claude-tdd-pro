# getting-started

# Getting Started

Welcome to Claude TDD Pro. Quick Start:

1. Run `/init-guardrails --emit-baseline .claude-tdd-pro/telemetry-baseline.json`
2. Run `/doctor --check directory-layout`
3. See [first-week.md](first-week.md) for the first-week loop.

## Optional: pre-commit framework integration (X-3)

If you use the [pre-commit framework](https://pre-commit.com), add the
plugin's hook to your `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: local
    hooks:
      - id: rubric-check
        name: rubric-check
        entry: bash rubric/runner.sh --format markdown --severity-floor P0
        language: system
        pass_filenames: true
        files: '\.(ts|tsx|js|jsx|mts|cts|mjs|cjs|py)$'
```

Then run `pre-commit install` once to wire the hook into `.git/hooks/`.
The hook blocks the commit on any P0 / severity=error finding and honors
the `lock.json` plugin_version pin per architecture section 2.7. See
`ci/pre-commit-hooks.yaml` for the canonical hook definition.
