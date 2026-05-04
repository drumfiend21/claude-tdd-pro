# Plugin evals

Regression tests for `claude-tdd-pro` itself. Without these, future
Claude Code updates can silently break the plugin's discipline.

## Structure

```
evals/
├── README.md           # this file
├── runner.sh           # the eval runner (bash; uses node for assertions)
├── specs/              # one .json per scenario
│   ├── lint-hook-rejects-symlinked-ancestor.json
│   ├── secret-scan-blocks-aws-key.json
│   ├── secret-scan-blocks-private-key.json
│   ├── secret-scan-blocks-ghp-token.json
│   ├── tdd-guard-blocks-without-failing-test.json
│   ├── tdd-guard-allows-test-file-edits.json
│   └── pr-refuses-without-token.json
└── fixtures/           # test data: sample diffs, sample test runs, etc.
```

## Running

```bash
bash evals/runner.sh           # runs all specs
bash evals/runner.sh secret    # runs specs with "secret" in the name
```

Exit 0 = all pass. Exit non-zero = at least one fail; runner prints
which.

## Scope

These evals test the PLUGIN, not the harness. Specifically:

| Tested | Not tested (by design) |
|---|---|
| Hook scripts: input parsing, allowlist enforcement, exit codes | Whether Claude Code actually invokes the hooks (that's a harness test) |
| Secret-scan: every regex pattern, false-negative resistance | The model's choice to call secret-scan vs not |
| Plugin manifest: schema validity | Plugin marketplace install flow |
| Skill descriptions: not over-triggering vocabulary | Whether the model invokes the right skill (that's an eval suite for the model itself) |

## Adding a spec

Each `specs/*.json` file declares:

```json
{
  "name": "secret-scan blocks AWS access key",
  "command": "bash hooks/scripts/secret-scan.sh",
  "setup": [
    "git init -q tmp-repo",
    "cd tmp-repo && git config user.email t@t.test && git config user.name t",
    "echo 'AWS_KEY=AKIAIOSFODNN7EXAMPLE' > config.txt",
    "git add config.txt"
  ],
  "expect": {
    "exit_code": 2,
    "stderr_contains": ["secret-shaped string", "AKIA"]
  },
  "cleanup": ["rm -rf tmp-repo"]
}
```

The runner shells out to `command` after `setup`, asserts the
specified `expect` conditions, then runs `cleanup`.

## When to add an eval

- Every time you find a bug in a hook script — write the spec that
  reproduces it BEFORE fixing.
- Every time you change a skill description that affects auto-trigger.
- Every time you add a new pre-flight check to `/pr`.
