# Misfiled: E-11 RuleTester specs require ESLint runtime + path drift

## What is here

10 pending specs originally placed under `evals/pending/E/E-11-ruletester/`.
They test a JavaScript-based RuleTester implementation: each spec writes
an actual ESLint rule (`module.exports = { meta, create: ... }`) and
expects the runner to JS-eval it, drive an AST, run the rule's `create`
visitor, collect `report({...})` calls, and compare them to the spec's
`errors` array.

## Why this is misfiled

Per [docs/architecture-v1.9.md](../../../docs/architecture-v1.9.md) §16:

> **E-11** RuleTester-equivalent test framework:
> `tests/<rule-id>/{valid,invalid}/<case>.{ts,json}`;
> `bash rubric/test-rule.sh <rule-id>` and `--all`; H-11 CI gate.

Two distinct deviations:

1. **Path drift.** The 10 specs invoke `rule-engine/rule-tester.sh`,
   which does not appear in the architecture text. The architecture-
   named runner is `rubric/test-rule.sh`.
2. **ESLint runtime dependency.** The specs assume a working ESLint
   API (`module.exports`, `meta`, `create`, `context.report`, fix
   functions, `parserOptions`, `env`). The plugin does not bundle
   ESLint or Node, and §16 E-11 stops at the file-tree shape +
   runner path — it does not commit to ESLint as the eval engine.

## Where the behaviors actually belong

E-11's substrate naturally pairs with **E-15** ("ESLint rules as
detectors: `rubric/detectors/wrap-eslint.sh` generic wrapper; rule
schema `detector_config: { eslint_rule, eslint_plugin_npm,
eslint_plugin_version, eslint_options }`; auto-installs npm package
on first use"). When E-15 ships an ESLint dependency surface, E-11's
RuleTester can run real `module.exports = ...` rules through that
wrapper — and the architecture-named per-case file tree
(`tests/<rule-id>/valid/<case>.json`) becomes the canonical test
format on top.

A lightweight non-JS-AST alternative for `rubric/test-rule.sh`
(running grep/regex detectors against `code` + `errors` per case)
would handle the rubric-native rules but is incompatible with the
specs' ESLint-rule fixtures.

## Disposition

- Detected: CL-57 (during §20 Week 2 scan).
- Action: parked here intact; no substrate written; no specs promoted.
- Resolution: when §20 Week 14 ships **E-15** (ESLint-as-detector
  wraps with npm install + node_modules), revisit and either rewrite
  specs to the lightweight per-case JSON contract or build the full
  ESLint-driven RuleTester at `rubric/test-rule.sh`.
- The architecture-named file tree (`tests/<rule-id>/{valid,invalid}/`)
  remains unbuilt until then.
