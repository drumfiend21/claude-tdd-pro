# Pending eval specs — architecture definition

This directory holds eval specs that **define the v1.9 architecture** before
the corresponding features are implemented.

## Convention

```
evals/pending/<phase>/<feature-id>/<test-name>.json
```

- `<phase>` = phase letter or letter-number (e.g., `F-0`, `E-1`, `G-5`)
- `<feature-id>` = the specific architectural sub-item being tested
- `<test-name>` = descriptive kebab-case name

Each pending spec is a **complete, runnable JSON eval** that would pass if
the feature it defines were implemented. Specs use the existing
`evals/runner.sh` schema: `name`, `command`, `setup`, `expect`.

## Runner behavior

The active runner scans only `evals/specs/*.json` (flat, no recursion). It
does **not** see pending specs. The active suite therefore stays
regression-clean throughout the architecture-definition phase.

When a feature is implemented, its pending specs move from
`evals/pending/<phase>/<feature-id>/` to `evals/specs/` and become live
regression tests for that feature.

## Coverage target

Per the architecture-definition plan, every numbered architectural feature
gets **10 non-shallow tests** that touch every piece of its documented
functionality. The complete v1.9 architecture decomposes into roughly
180 features, yielding ~1,800 pending specs across the full definition.
