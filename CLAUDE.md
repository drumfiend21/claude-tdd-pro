# Claude TDD Pro — project instructions for Claude

## PRIMARY RULESET (highest priority — read first, every session)

**[generated-code-quality-standards/_universal/ai-dev-corpus.md](generated-code-quality-standards/_universal/ai-dev-corpus.md)** is the primary, highest-priority ruleset for how to architect, plan, and develop software on this project. Read it before anything else, every session.

It encodes mindset and methodology (English-first programming · Musk's 5-step algorithm · Anthropic's verification + context discipline · Building Effective Agents patterns). It does not replace the per-CL discipline below — it overlays it. When the corpus conflicts with any other guidance in `generated-code-quality-standards/`, the corpus wins; for per-CL workflow steps, see "Workflow loop" below.

## ARCHITECTURE IS LAW

**The canonical v1.9 architecture (plus v1.9.1 §23, v1.10 §24, and v1.9.2 §25 amendments) is at [docs/architecture-v1.9.md](docs/architecture-v1.9.md). It is the source of truth for every feature ID, every §2.X cross-cutting contract, every phase decomposition, and every CL plan.**

**Read it at the start of every prompt.** Before naming any feature, contract, folder, spec, or commit message, extract the literal feature ID and label from this file. Do not infer from memory, ESLint domain knowledge, or "what makes sense for this layer." Do not paraphrase. Do not invent.

If you find yourself reasoning "this should be E-N because…" — STOP. The architecture's E-1..E-17 are listed in §16. Look them up. The same rule applies to every other phase (F, G, S, C, P, R, N, T, Q, H, L, O, X, W) and every cross-cutting contract (§2.1..§2.25).

This rule exists because prior CLs (CL-08, CL-09, CL-10) deviated by inventing decompositions: Phase E's rule registry / AST walker / parallel runner / source code analyzer / suggestion API / performance budget were all invented (the architecture has none of those as features); Phase H's adversarial yaml / path traversal / sandbox / secret leak / privilege boundary were all invented (the architecture's H is operator polish: token-cost transparency, SECURITY.md, /doctor --watch, etc.); cross-cutting contract labels §2.7..§2.22 were assigned plausibly-sounding-but-wrong topics. ~297 specs were deleted in CL-11 to remove the deviation.

## PROJECT MEMORY — read alongside architecture every prompt

The repo carries a project-memory tree at [docs/memory/](docs/memory/) that supplements the architecture text. **Read all of these at the start of every prompt**, alongside `docs/architecture-v1.9.md` AND the PRIMARY RULESET above:

- [generated-code-quality-standards/_universal/ai-dev-corpus.md](generated-code-quality-standards/_universal/ai-dev-corpus.md) — **PRIMARY RULESET, highest priority.** Karpathy English-first + Musk 5-step + Anthropic verification + Building Effective Agents + Amodei vision. Lives in the ESLint-style standards tree as the universal cross-cutting ruleset. Read first.
- [docs/memory/MEMORY.md](docs/memory/MEMORY.md) — index of persisted memory files (1-line hooks per entry)
- [docs/memory/project-v19-architecture-canonical.md](docs/memory/project-v19-architecture-canonical.md) — feature-ID summary + drift-mechanism catalog (CL-08/09/10 lessons); cite by exact ID
- [docs/memory/feedback-self-gap-check-before-commit.md](docs/memory/feedback-self-gap-check-before-commit.md) — the gap-check workflow loop (overlaps with the "Workflow loop for every CL" section below; both must stay in sync)
- [docs/memory/feedback-implementation-workflow-checklist.md](docs/memory/feedback-implementation-workflow-checklist.md) — 12-item per-CL substrate-writing + process-discipline checklist (reference BEFORE any new Write/Edit)
- [docs/memory/feedback-implementation-optimization-plan.md](docs/memory/feedback-implementation-optimization-plan.md) — 4 lazy-build scripts + tiered active suite during iteration (reference at the START of every implementation-phase CL)
- [docs/memory/feedback-bash32-portability-checklist.md](docs/memory/feedback-bash32-portability-checklist.md) — **read BEFORE every new substrate Write/Edit**: 7 recurring macOS bash 3.2 / BSD-tool gotchas (no associative arrays, `wc -l` padding, `printf %`, env-var-passing-first, set -u + empty arrays, BSD grep `--`, redirect order) + help-text-to-stderr bonus. Validated on CL-197: full H-8 promotion passed 10/10 first-run after applying this checklist (vs ~4 spec-fix cycles per CL without it).
- [docs/memory/feedback-batch-cl-convention.md](docs/memory/feedback-batch-cl-convention.md) — **reference when planning the next CL boundary**: features extending the same substrate file ship as ONE commit (range CL-N..M) with per-feature audit sections in the body. Preserves every CLAUDE.md drift guard; amortizes full-suite wait. Validated on CL-146..161 (L-7..L-23 16-feature batch, audited 2026-05-19 with zero drift).
- [docs/memory/feedback-pending-spec-content-fidelity.md](docs/memory/feedback-pending-spec-content-fidelity.md) — **read BEFORE promoting any pending feature** (via `probe-feature` or `promote-pending`): the §2.25 / §25 (v1.9.2) gate that catches pending specs whose folder name correctly maps to an architecture feature but whose spec body asserts invented vocabulary. Discovered in CL-273 (8/10 `CC/2-6-standards-source/` specs used invented `publisher` / `license` / `last_verified` / `archive_url` / `etag` / `derivative_rules` for arch-named §2.6). Automated by `rubric/detectors/audit-pending-spec-fidelity.sh`; integrated as Step 0.5 below and drift mechanism #6.
- [docs/memory/architecture-backlog-conditional-gets.md](docs/memory/architecture-backlog-conditional-gets.md) — v1.8 candidate (conditional GETs prerequisite for in-use polling)
- [docs/memory/architecture-backlog-in-use-polling.md](docs/memory/architecture-backlog-in-use-polling.md) — v1.8 candidate (millisecond in-use polling for registries)
- [docs/memory/project-v19-architecture-text.md](docs/memory/project-v19-architecture-text.md) — pointer to `docs/architecture-v1.9.md` (canonical text not duplicated)

**The repo memory at `docs/memory/` is the canonical source.** The auto-memory tree at `~/.claude/projects/-Users-siddharthjoshi-projects-claude-tdd-pro/memory/` is a per-machine, per-user mirror that should track the repo. When they diverge, the repo wins; refresh the auto-memory mirror to match.

**Adding new memory** that should persist across sessions and machines: write to `docs/memory/` first (will be committed), then refresh the `~/.claude/.../memory/` mirror via copy. Don't write project memory only to `~/.claude/` — it's machine-local and will be lost on new clones.

## Workflow loop for every CL (the process)

This is THE process. Every CL on this project follows it exactly. No deviation.
The user's job is to approve commits, not to prompt the audit.

### Step 0 — Pre-flight architecture extraction (NON-NEGOTIABLE)

Read [docs/architecture-v1.9.md](docs/architecture-v1.9.md) for the scope you're about to work in. **Quote the literal feature decomposition** before writing any spec. If you can't quote it, you're not ready to write specs.

- About to write Phase E specs → Read §16, list E-1..E-17 verbatim.
- About to write a §2.X contract spec → Read §2, copy the literal heading.
- About to define a Phase H feature → Read §11 and use the literal H-1..H-11 list.
- Asked about phase ordering → Read §20.
- Asked about definition of done → Read §21.

Never proceed from memory. The architecture file is in the repo precisely so memory loss across sessions cannot cause drift.

### Step 0.5 — Pending-spec content fidelity check (NON-NEGOTIABLE for promotion-only CLs; v1.9.2 §25)

If this CL promotes pre-existing pending specs (via `probe-feature` or `promote-pending`) rather than writing fresh ones in Step 1, you MUST run the §2.25 fidelity gate before any substrate work:

```bash
bash rubric/detectors/audit-pending-spec-fidelity.sh \
  --pending evals/pending/<phase>/<feature-id>-<label>/ \
  --arch docs/architecture-v1.9.md \
  --section "<§X>"
```

Exit 0 → proceed. Exit 1 → triage each `unknown_vocab=<token> spec=<file>` line via one of the three §25.3 resolution paths: **(1) Spec rewrite** to arch-spec'd vocabulary (most common), **(2) Architecture amendment** as a separate governance CL, or **(3) Misfiled relocation** to `evals/pending/_misfiled/<feature-id>/`. Disclose every chosen path in the commit body under "Spec patches in this CL (architecture-fidelity corrections):". This step exists because folder-name fidelity is necessary but not sufficient — see drift mechanism #6 below and `docs/memory/feedback-pending-spec-content-fidelity.md`.

### Step 1 — Write the unit tests

Use ONLY the literal architecture feature names and §2.X labels extracted in Step 0. Pending specs go in `evals/pending/<phase>/<feature-id>-<descriptive-label>/`. Active (regression baseline) specs go in `evals/specs/`.

Spec contents must satisfy:

- **Hermetic:** runner provides a clean tmpdir; setup arrays create all needed fixtures.
- **State-asserting:** `expect.exit_code` is explicit; `expect.stderr_contains` checks meaningful output.
- **Behavior-named:** name describes what the SUT does, not its mechanics. Minimum 20 characters.
- **No opaque IDs in names:** never `F-1`, `E-7`, `(§2.X)`, `(C-9)`. Use descriptive phrases.
- **Google testing best practices:** no sleep in test body (except when testing time-elapsed mechanisms), no external network, public-API only, stubs-not-mocks at process boundary, `&&` (not `;`) between SUT and assertion when SUT must succeed.

### Step 2 — Self-audit (BEFORE asking for commit approval)

Verify all of:

- **Architecture fidelity:** every folder name maps to an exact feature ID + descriptive label that appears verbatim in `docs/architecture-v1.9.md`. If a folder doesn't, it's mislabeled or invented and must be deleted/moved before commit.
- **10 specs per architecture feature** (active + pending combined).
- **Non-shallow:** each feature's specs touch distinct functionality slices, not pattern-cloned variations. Shape-only specs (`test -f <file>`) are acceptable only when the architecture text literally says "ships at install time" for that file; otherwise specs must exercise behavior.
- **CLI-flag-invention disclosure:** see "CLI-flag invention discipline" section below. Flags not in the architecture text are test-affordances and must be listed in the commit body.
- **Spec count:** confirm new spec count and total pending spec count.

### Step 3 — Verify

Run `bash evals/runner.sh` and confirm 58/58 active suite stays clean. If flake on a known-flaky spec (e.g. the 500ms perf test), retry once and note.

### Step 4 — Propose commit

Write the commit message. Include in the body:

- Per-feature spec counts.
- All audit findings from Step 2 (architecture fidelity, 10-per-feature, non-shallow check, public-API only, etc.) — show the audit was run, don't just claim it.
- Architecture sections quoted in pre-flight.
- Any test-affordance flags invented in this CL.
- Numbers: total pending count before/after.
- Next-CL scope per §20 execution order.

Ask "Approve?" — no other questions. The user approves or sends back specific edits.

## CLI-flag invention discipline

The architecture text defines feature *behaviors* (what something does, what files it writes, what gate it enforces) but rarely defines *invocation surface* (which flag is `--root` vs `--source-dir`, which env var name, etc.). Pending specs invent test-affordance flag names so the specs are concrete and runnable.

**This is a known, controlled deviation** documented here:

- **Acceptable:** inventing `--root`, `--tree`, `--in`, `--paths`, `--now`, `--emit`, `--upstream-stub`, `--rule-file`, `--emit-resolved`, `--cache-location`, `--commit-sha`, etc. — these are test-time affordances that let specs assert behavior.
- **Required disclosure:** every commit body that introduces a new flag must list it in a "Test-affordance flags invented" section.
- **Required reconciliation:** at implementation time (when the actual script gets built), pending specs MUST be updated to match the real CLI surface. This is a one-time mass-rename, not a per-CL concern.
- **Hard line:** invented *features* (folders that don't trace to an architecture feature ID) are NEVER acceptable — those are the deviation we banned in CL-11. Invented *flag names within a real feature* are acceptable with disclosure.

When in doubt: name the behavior, not the invocation. A spec named `"aggregator: handles 200 rules across 40 files in <500ms"` (behavioral) is durable regardless of whether the implementation uses `--root` or `--source-dir`.

## Project state

- Active suite: 58 specs (regression baseline — must stay clean across every CL).
- Pending specs: in `evals/pending/<phase>/<feature-id>-<descriptive-label>/` — invisible to the active runner; promoted to `evals/specs/` when implementation lands.
- Substrate already implemented: aggregator (G-5), source-file validator (§2.21 partial), rubric-rule schema validator (§2.1).
- Canonical CL execution order: see §20 of `docs/architecture-v1.9.md`.

## Drift mechanisms (catalog of what caused prior deviations)

These are the failure modes that have actually happened on this project. Watch for them.

1. **Compaction loss + inferred decomposition.** Conversation gets compacted; architecture text falls out of context; brain fills the gap with plausible-feeling synthesis (ESLint domain knowledge for E, "hardening = security" for H). Result: CL-08/09/10 invented ~297 specs of wrong features. **Defense:** Step 0 pre-flight, every CL.

2. **Self-audit checks process, not scope.** Tests can be hermetic, behavior-named, exit-coded, AND test the wrong feature. The audit must verify "does this folder name appear in the architecture text" — not just "do the specs look clean." **Defense:** architecture-fidelity is the first audit check, not the last.

3. **Flagging-as-bypass.** Putting "this is my interpretation" in a commit body becomes a discharge of duty rather than a STOP signal. **Defense:** flagging must be a STOP-and-extract-from-text, not a footnote. The only acceptable "this is invented" disclosure is test-affordance flag names (see CLI-flag invention discipline section above).

4. **Approval feedback loop.** Each "approved" reinforces the previous behavior. The user trusts the commit message; the commit message trusts the audit; the audit trusts the work. **Defense:** the audit results in the commit body must be specific (counts, mappings, fidelity findings) — not "all checks pass."

5. **Pattern-cloned coverage.** Hitting "10 per feature" by writing 10 variants of the same shape test instead of 10 distinct behaviors. **Defense:** verb-diversity check in audit; shape-only specs must justify themselves against architecture text.

6. **Pending-spec invented vocabulary.** Specs that pre-existed in `evals/pending/<phase>/<feature-id>-<label>/` may assert behavior using field names, YAML/JSON shapes, or output keys not in `docs/architecture-v1.9.md` for that feature. The folder name passes every existing fidelity check; the drift hides inside spec bodies. Caught in CL-273 where 8/10 `CC/2-6-standards-source/` specs used invented `publisher` / `license` / `last_verified` / `archive_url` / `etag` / `derivative_rules` for arch-named §2.6 (which actually specifies `id` / `name` / `url` / `tier` / `applies_to` / `fetch_frequency`). **Defense:** Step 0.5 fidelity gate via `rubric/detectors/audit-pending-spec-fidelity.sh`; §2.25 contract; `docs/memory/feedback-pending-spec-content-fidelity.md`. The whole audit machinery before §25 assumed specs and substrate are produced together — pending specs that arrived via a different session were never re-audited at promotion. Step 0.5 closes that gap.

## How to recognize you are about to drift

- You're reasoning "this should be E-N because…" without having quoted the architecture this turn.
- You're writing a spec for a feature whose folder name isn't in `docs/architecture-v1.9.md` if you search for the exact ID.
- You're inventing a new CLI flag and haven't listed it in a "test-affordance" disclosure section.
- The audit results in your commit body are vague ("all checks pass") rather than specific (per-folder mapping table).
- You're about to probe or promote pre-existing pending specs without running `audit-pending-spec-fidelity.sh` against them first.

If any of these is true: STOP. Re-read the relevant architecture section. Restart the CL from Step 0.
