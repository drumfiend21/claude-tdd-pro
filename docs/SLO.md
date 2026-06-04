# Service-Level Objectives — claude-tdd-pro

Operator-facing SLOs for the plugin's enforcement surfaces. Measured
on a reference workstation (Apple Silicon M3 / 24 GB / SSD) with a
warm cache unless noted.

## Installer

| Operation | Target | Current |
|---|---|---|
| `install.sh init --yes` cold (no prior cache, normal network) | < 60 s | ~2-15 s |
| `install.sh init --yes` warm (lockfile current) | < 1 s | ~0.15 s |
| `install.sh upgrade --yes` when current | < 1 s | ~0.5 s |
| `install.sh upgrade --yes --force` (re-fetch + regenerate) | < 5 s | ~3 s |
| `install.sh doctor` | < 1 s | ~0.5 s |
| Preflight toolchain check | < 100 ms | ~50 ms |
| Conflict detection scan | < 50 ms | ~10 ms |

## Rubric runner

| Operation | Target | Current |
|---|---|---|
| Full suite warm (`bash evals/runner.sh`) | < 30 s | ~3-5 s |
| Full suite cold (cache miss every spec) | < 5 min | ~3-4 min |
| Filter-run by feature (10 specs) | < 1 s | ~0.2 s |
| Spec timeout (per spec) | 10 s hard limit | enforced |

## Drift gates

| Gate | Target | Current |
|---|---|---|
| §25 fidelity audit per pending dir (10 specs) | < 200 ms | ~150 ms |
| Substrate-completeness audit (193 features) | < 500 ms | (target) |
| CLI-surface fidelity audit | < 500 ms | (target) |

## Per-CL workflow loop

| Operation | Target |
|---|---|
| `scripts/cl-build.sh` end-to-end for single-feature CL | < 30 s warm |
| `scripts/cl-build.sh` end-to-end for batch CL (9 features) | < 60 s warm |

## Error budgets

- **Installer init**: 99% of cold installs ≤ 60 s; if breached, investigate
  network or upstream GitHub latency.
- **Suite green**: 100% of pushes to `main` must show `Results: N passed, 0 failed`.
  Any regression blocks merge. No error budget — drift mechanism #4.
- **Fidelity gates**: 100% of promotion CLs must pass §25 + future
  substrate-completeness + CLI-surface gates. Failed gate = rollback.

## Capacity

- **Spec corpus**: tested up to 4,000 active specs; runner uses 4 worker
  processes by default; scales linearly with worker count up to the
  number of cores.
- **Architecture features**: tested at 193; per-feature ≥10 specs;
  no upper bound observed.
- **Profile count**: 9 ships in the box; no upper bound.

## Observability

- Suite output emits `Results: N passed, M failed` (parseable by
  installer doctor + CI).
- Stats block (`--stats` flag) emits `workers=N parallel_specs=N
  serial_specs=N cache=1 cache_hits=N cache_misses=N tree_sha=XYZ`.
- Installer logs every step with elapsed seconds prefix
  (`[init +Xs] message`).
- `~/.claude-tdd-pro-install.log` holds the background suite output.

## Operational runbook (light)

- **Installer reports preflight fail** → install missing toolchain; rerun.
- **Suite reports failures** → run with `-v` for verbose; check for cache
  staleness via `rm -rf ~/.cache/claude-tdd-pro` then rerun.
- **§25 fidelity gate dirty** → triage each `unknown_vocab=...` line per
  §25.3 (spec rewrite | architecture amendment | misfiled relocation).
- **Lockfile commit drifted from remote** → `install.sh upgrade --yes`
  to fetch latest; commit the updated lockfile.

## Future SLOs (post-A− tier)

- Mean-time-to-detect drift band (substrate / CLI / behavior / vocab): ≤ 1 CL
- Mean-time-to-close drift band once detected: ≤ 1 hour
- Installer cold path on typical home connection: ≤ 30 s p95
- Spec-depth (behavior specs per executable feature): ≥ 3 p50, ≥ 1 p99
