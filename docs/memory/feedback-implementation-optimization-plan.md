---
name: Implementation optimization plan (per-CL)
description: User-validated optimization plan for the architecture-v1.9 implementation phase. Reference BEFORE starting any new substrate CL on this project. Specifies four small scripts and one process change that automate already-repeated mechanical patterns without altering architecture, runner, or audit discipline. Distinct from feedback-implementation-workflow-checklist.md which encodes substrate-writing rules; this file specifies AUTOMATION substrate that should be built and used to apply those rules.
type: feedback
---

**Reference this plan at the start of every implementation-phase CL on Claude TDD Pro, alongside `feedback-implementation-workflow-checklist.md`.**

**Why:** validated by user 2026-05-15 after a 19-CL autonomous session (CL-91 through CL-109) that landed R+N+T phases (180 features, active suite 78 → 766). Process audit identified ~2-3 hours of avoidable iteration in that session, all from mechanical patterns I re-typed each CL: spec bug-fix patches, naming-collision rediscovery, detector boilerplate, macOS bash 3.2 portability rediscovery, and full-suite reruns on every iteration. The plan codifies those into 4 small scripts plus 1 process change. Architecture, runner, audit discipline, and 1-feature-per-CL rule remain unchanged.

**How to apply:** at the start of every CL — after pre-flight architecture quote (CLAUDE.md Step 0) and the 11-item workflow checklist read (`feedback-implementation-workflow-checklist.md`) — check this plan for whether the upcoming CL fits a pattern that one of the four scripts already automates. If a script exists, use it. If a CL would benefit from a new automation pattern, propose it (don't build inline; surface as a follow-up).

## What this plan does NOT change (preserved invariants)

- `docs/architecture-v1.9.md` is law (never modified).
- `evals/runner.sh` is the regression baseline (never modified).
- Step 0 architecture quote is required per CLAUDE.md; never skipped.
- Per-folder fidelity mapping is required in commit body for new-path CLs; never shortened.
- Active suite must be green at every commit; gate is non-negotiable.
- 1 feature per CL; no batching multiple architecture features into one commit.
- Spec patches still disclosed in commit body (the script emits the diff for the body).

## The four scripts (build in this order; each is small)

### 1. `scripts/patch-pending-specs.sh <phase>/<feature>` (highest ROI)

Idempotent preprocessor that applies the known spec bug-fix patterns to every `evals/pending/<phase>/<feature>/*.json`. Emits a diff to stdout before writing so the user (and the commit body) can see exactly what changed.

Patterns to apply:
- `--format json 2>out.json && node` → `--format json >out.json 2>err.txt && node` (aggregator stdout convention; spec authors keep mistaking it for stderr)
- Drop literal `"generated-code-quality-standards/"` prefix from `source_file` string assertions (aggregator emits paths relative to `--root`)
- `""$CLAUDE_PLUGIN_ROOT` → `"$CLAUDE_PLUGIN_ROOT` (extra-double-quote bug)
- `g-<phase>-*.json` glob in spec command → `g-<phase>-[0-9][0-9][0-9].json` (over-permission catches runner-spec siblings)
- `grep -E "--json...."` → `grep -E -- "--json...."` (BSD grep flag-parse on macOS)
- `2>file` immediately followed by `grep file` AND a separate `1>&2` line (stdout/stderr trap)

Effort: ~25 min. Payback: ~3-5 min on every "rules" / "fixtures" / "profile-with-options" CL = ~6 CLs payback.

### 2. `scripts/promote-and-rename.sh <phase>/<feature>`

Detects naming collisions BEFORE `git mv` (instead of after the fatal error), applies the standard collision-prefix (`react-`, `node-`, `ts-`, etc.) when the destination basename already exists in `evals/specs/`, and removes the empty parent folder. Reports per-file decisions.

Effort: ~15 min. Payback: saves the collision rediscovery dance (~2-3 min × every promotion CL).

### 3. `rubric/detectors/lib/glob.sh` (shared library; build before #4)

Extract the portable glob expander + find-depth helper to a single sourceable file. New detectors do `source "$SCRIPT_DIR/lib/glob.sh"` instead of duplicating ~30 lines of case-statement glob parsing. Captures the macOS-bash-3.2 lessons in one place.

Function exports: `expand_paths_to_files <glob>` (echoes one file path per line); `set_find_depth <recursive_flag>` (sets `$FIND_DEPTH` to `""` or `-maxdepth 1`).

Effort: ~10 min (extract from existing detectors; behavior-preserving). Payback: correctness — fix once, applies everywhere; eliminates the "rediscovered globstar limitation" pattern.

### 4. `scripts/scaffold-detector.sh <name>`

Generates a new detector script at `rubric/detectors/<name>.sh` with all the §2.2 contract boilerplate already filled in:
- Arg parser (`--json --paths --dry-run --help`).
- `source "$SCRIPT_DIR/lib/glob.sh"`.
- `--dry-run` early-return.
- `--help` to stdout.
- Single-pass `find + xargs grep -l <PRE_FILTER>` performance pre-filter (with a `# TODO: PRE_FILTER` placeholder).
- A `# TODO: replace with detection logic` comment at the body.
- `set -uo pipefail` and the standard exit codes (0 = clean, 1 = violation, 2 = tooling error).

Effort: ~20 min. Payback: ~5-8 min × every new detector × ~10 detectors remaining in §16 = 1-2 hours.

## Process change (zero effort, immediate savings)

**Tiered active suite during iteration.** During iteration on a CL, run `bash evals/runner.sh -v cl<N>` (the staged 10 specs only) for the fast loop. Reserve the full `bash evals/runner.sh` (~750+ specs) for the **final pre-commit verify** only.

CLAUDE.md requires active-suite-green AT COMMIT TIME, not on every iteration. Saves ~2 min × ~5 iterations per CL = ~10 min per CL.

## What is NOT in this plan (deliberately rejected)

- **Auto-generation of substrate from architecture text.** Would invite drift; the discipline is "human reads architecture, writes substrate, audits in commit body" — automation only handles the mechanical glue (spec patching, file renaming, scaffolding boilerplate).
- **Batching multiple features per CL.** CLAUDE.md is explicit: 1 feature per CL.
- **Skipping the per-folder fidelity mapping in commit bodies.** The audit IS the value.
- **Skipping the architecture quote pre-flight.** Drift catastrophe prevention.
- **Modifying `evals/runner.sh` to add a "fast" mode.** The runner is the regression baseline — never modify.

## Build-order policy

When the next implementation CL would benefit from script (1)/(2)/(3)/(4), pause one CL to build that script first (cost: 10-25 min), then resume. Do NOT build all four upfront — wait for an actual CL where each pays back immediately, so the user sees the value land in real work, not in a separate refactor.

Cumulative payback estimate: with ~80 features still in §20, savings of ~5-10 min per CL × ~50 substrate CLs = **4-8 hours** over the remainder of the implementation phase.

## Cross-reference

- `feedback-implementation-workflow-checklist.md` — 12 substrate-writing rules. This plan AUTOMATES those rules where mechanical. Both are loaded together.
- `project-v19-architecture-canonical.md` — feature-ID and §2.X contract reference.
- `docs/architecture-v1.9.md` — source of truth (never modified).
