# Misfiled: E-3 specs require ESLint-style cascading config

10 pending specs that test a full ESLint-style cascading config
resolver (.eslintrc-style root: true, --print-effective-config,
shareable extends with cycle detection, package-config overrides
root, unknown-rule throws). All invoke `rule-engine/cli.sh`.

§16 E-3 (verbatim): "Glob-based overrides: overrides: [{ files, rules }];
fnmatch globs; later wins; per-file resolution at runtime;
profiles/_overrides/test-files.yaml, critical-paths.yaml, scripts.yaml,
stories.yaml, generated.yaml."

The architecture-named home is profiles/_overrides/<topic>.yaml +
profiles/active.sh overrides[].files glob resolution (already supported
in CL-49 substrate). But these specs go far beyond that — they assume
the full ESLint cascading-config model + a JS rule engine that doesn't
exist in our lightweight detector model.

When E-15 (ESLint-as-detector wraps) lands in §20 Week 14, revisit
either by rewriting these specs to test profiles/active.sh's overrides[]
behavior, or by building the full ESLint cli substrate.
