# SPACE: solo-scale self-observation

This is a **solo-scale self-observation** dashboard. It is **not productivity science**. It is **not benchmarking**. It is **not a performance review**.

## Scope

The SPACE dimensions (Satisfaction, Performance, Activity, Collaboration,
Efficiency-and-Flow) per the original SPACE framework are intended for
RESEARCH and TEAM-LEVEL aggregate inquiry. This implementation is
deliberately **single-developer, local-only, retention-bounded,
opt-in-by-default** for sensitive dimensions.

## Limitations

- **No causality**: a metric moving up or down has many causes;
  this dashboard does not infer them.
- **No benchmarking**: comparing your numbers to anyone else's is
  meaningless at this scale.
- **No performance review**: these metrics are NOT for managers,
  NOT for promotion packets, NOT for ranking.
- **No multi-user aggregation**: the substrate refuses team-rollup
  modes (you will see it explicitly reject `--aggregate-users` and
  multi-user bundle imports).

## Privacy posture

- Local-only by default (`share: never`).
- PII guard runs before any export (emails, phone numbers, user,
  hostname redacted).
- Retention sweep prunes entries older than `retention_days` (default 90).
- The `space/` runtime directory is gitignored.
