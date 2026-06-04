# Fitness functions defended

This project applies the four detector scripts under
`rubric/detectors/audit-*.sh` as **architectural fitness functions**
per Parsons & Ford, *Building Evolutionary Architectures, 2nd ed*. They
are not generic linters; each defends a specific architectural
invariant against a specific named failure mode (drift mechanism).

## Taxonomy

We classify each fitness function on two axes:

|              | **Triggered** (run on commit / probe) | **Temporal** (run on schedule) |
|---|---|---|
| **Atomic**   | one invariant at a single point in time | one invariant trended over time |
| **Holistic** | multiple invariants spanning phase boundaries | multiple invariants trended over time |

## Current suite

| # | Fitness function | Classification | Defends drift mechanism | Threshold |
|---|---|---|---|---|
| 1 | `audit-pending-spec-fidelity.sh` | atomic / triggered | **#6** pending-spec invented vocabulary | 0 unknown_vocab tokens |
| 2 | `audit-substrate-completeness.sh` | atomic / triggered | **#1** compaction loss + inferred decomposition (substrate dimension) | every arch-named feature has ≥1 referenced substrate path that resolves |
| 3 | `audit-cli-surface-fidelity.sh` | atomic / triggered | **#1** compaction loss (CLI surface dimension) | every §23/§24/§2.14-documented flag is honored by the substrate |
| 4 | `audit-spec-depth.sh` | atomic / triggered | **#5** pattern-cloned coverage | every executable feature ≥1 behavior spec (target: ≥3) |
| 5 | `fitness-trend.sh` | holistic / temporal | **#5 + #2** trended over weeks | spec-depth ratio non-decreasing; flag P95 latency |

## Why fitness functions, not "drift gates"

Per Parsons & Ford, fitness functions are how evolutionary architecture
makes architectural invariants enforceable continuously. The CLAUDE.md
drift-mechanism catalog names *what we defend against*. The fitness-function
suite names *how we defend*. Both phrasings refer to the same scripts;
the fitness-function vocabulary is the documented preferred name going
forward.

## Adding a fitness function

1. Identify the drift mechanism it defends (one of #1-#6 in CLAUDE.md;
   propose a new one if none fits).
2. Decide its classification on the 2×2 taxonomy above.
3. Set an explicit threshold (numeric where possible).
4. Add it to the suite under `rubric/detectors/audit-<name>.sh`.
5. Wire it into the npm `drift:audit` script in `package.json`.
6. Document it in this file's "Current suite" table.
7. Add behavior specs for the fitness function itself under
   `evals/specs/cl<N>-FF-<name>-*.json`.

## Roadmap

- **#5 verb-diversity** (atomic / triggered) — per-feature, no two specs
  should use the same assertion verb chain. Defends drift mechanism #5
  (pattern-cloned coverage) more precisely than `audit-spec-depth.sh`.
- **#6 architectural-text drift** (atomic / triggered) — diff arch.md
  against the prior accepted commit; require downstream re-audit when
  any §X heading or feature ID changes.
- **#7 temporal cache-hit-rate** (atomic / temporal) — weekly trend of
  E-12 cache hit rate; flag when below 80%.
- **#8 temporal suite-latency** (atomic / temporal) — weekly trend of
  full-suite wall-clock; flag when P95 grows >20% over 4 weeks.

Each can be shipped as a single `.sh` script per the pattern above.
Total: ~4 hours of engineering.
