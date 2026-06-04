# tdd-pro-runner — Go reimplementation of the rubric runner

Per ADR-0001 §rollback and the simulated Musk + Fowler joint review:
the bash runner is being migrated to a typed binary.

## Status

**Skeleton** — typed spec parser, parallel runner, content-addressed
cache, bash-compatible output. Tests cover the core contract.

## What's covered

- `internal/spec` — typed JSON spec parsing + validation. Tests:
  - Load valid spec
  - Reject malformed JSON
  - Reject short name (<20 chars)
  - Reject no-assertion spec
  - Accept canonical shape
- `internal/runner` — parallel execution + cache. Tests:
  - Passing spec evaluates correctly
  - Failing spec evaluates correctly
  - 20 concurrent specs all pass (parallelism correctness)
  - Second run hits cache
  - Output format matches bash runner
  - STATS line matches bash runner

## Build and run

```bash
cd runner-go
go test ./...                                         # unit tests
go build -o ../bin/tdd-pro-runner .                   # build
../bin/tdd-pro-runner --specs ../evals/specs --filter "cl414-Q-1"
../bin/tdd-pro-runner --specs ../evals/specs --stats
```

Output is bash-compatible — CI workflows, hooks, and the LSP shell
out to the runner without knowing or caring whether bash or Go is
executing.

## Migration sequence

1. **This CL — skeleton + tests.** Spec parser, parallel runner,
   cache, bash-compatible output, ~600 lines including tests.
2. **Next CL — feature parity.** Add `--md` JSONL emit, `--quiet`
   mode, severity-floor gating, multi-format output (the bash
   runner's full surface).
3. **Next CL — side-by-side gate.** Add a CI gate that runs both
   runners on the same spec corpus and fails on divergence.
4. **After 1 week green side-by-side — flip the default.** Bash
   runner stays as fallback for one MINOR release; removed in
   the following one.

## Why Go (vs. Rust)

Fowler's note: "type system over raw speed for a system this size;
ship the simpler choice."

Musk's note: "fewer lines than Rust; ships sooner."

Both: "if perf becomes an issue at scale, rewrite the cache layer
in Rust later. The spec runner is I/O-bound; Go is plenty."

## What stays in bash

- The orchestrator (`scripts/cl-build.sh`) — coordination glue, not
  hot path.
- The installer (`scripts/install.sh`) — operator-facing shell that
  must work without an additional toolchain install.
- The fitness function detectors (`rubric/detectors/audit-*.sh`) —
  small, inspectable, no migration urgency.
