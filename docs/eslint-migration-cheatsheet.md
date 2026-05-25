# ESLint migration cheatsheet

H-9 progressive disclosure: for teams moving from ESLint to
claude-tdd-pro. Maps the most-used ESLint concepts to their
claude-tdd-pro equivalents.

## Concept map

| ESLint                              | claude-tdd-pro                                       |
|-------------------------------------|------------------------------------------------------|
| `.eslintrc.json`                    | `profiles/active.sh` + a profile YAML                |
| `extends: ["foo"]`                  | profile `extends: [foo]`                             |
| `rules: { "no-eval": "error" }`     | profile `rules: { no-eval: error }`                  |
| `overrides: [{ files, rules }]`     | Same syntax; per-glob fnmatch (E-3)                  |
| `// eslint-disable-line rule`       | `// rubric-disable-line rule -- <justification>` (E-5) |
| `// eslint-disable-next-line rule`  | `// rubric-disable-next-line rule -- <justification>`  |
| `/* eslint-disable */ ... /* eslint-enable */` | `/* rubric-disable */ ... /* rubric-enable */`  |
| `--report-unused-disable-directives`| Same flag on `rubric/detectors/inline-suppression.sh` |
| Shareable config (npm package)      | Source folder under `generated-code-quality-standards/` |
| Custom rule plugin                  | `rubric/detectors/<id>.sh` + `rubric/tests/<id>/`    |
| RuleTester                          | `bash rubric/test-rule.sh <id>` (E-11)               |
| `--fix` codemod                     | Out of scope; pair with Biome / dprint / Prettier    |

## What's different

1. **Justification mandatory.** Inline `// rubric-disable-*` directives
   require `-- <justification>` text by default. F-4 drift-detection
   tracks repeated bypasses across commits.
2. **Detectors are shell scripts.** No JS plugin loading; each rule
   maps to a detector script via the rule YAML's `detector` field.
3. **Profile precedence is explicit.** Per-glob overrides win over
   profile defaults; later `overrides[]` entries win on conflict
   (E-3, §16).
4. **Standards have provenance.** Each rule cites an upstream source
   (§2.6); stale citations auto-demote to warn via S-16.

## Migration steps

1. Pick the profile closest to your stack (`react.yaml`, `node.yaml`,
   `library.yaml`, ...).
2. Map your ESLint `rules: { ... }` block into the profile YAML.
3. Add operator-only rule overrides to a profile-specific section
   instead of editing source-folder YAMLs (those are
   upstream-citation-pinned).
4. Run `/analyze` and triage findings; use `/remediate` for batched
   changes.
