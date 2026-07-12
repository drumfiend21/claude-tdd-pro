# CTP cloud-session handoff — continue plugin development in a fresh session

**Written:** 2026-07-11 · **From:** the local Claude Code session that built §31.
**Purpose:** everything a NEW cloud Claude Code session (GitHub + shell + git) needs to continue developing the
CTP plugin (`drumfiend21/claude-tdd-pro`) without dropping this repo's discipline.

## 0. First actions in the new session (do these before touching anything)

1. `git fetch origin && git status` — confirm you are current.
2. **Read these, every session, before writing anything** (they are LAW here):
   - `CLAUDE.md` (root) — the ruleset that overrides default behavior.
   - `generated-code-quality-standards/_universal/ai-dev-corpus.md` — PRIMARY RULESET.
   - `docs/architecture-v1.9.md` — the constitution. Extract feature IDs / §-labels **verbatim**; never infer.
   - `docs/memory/` (all of it) — persisted lessons + drift catalog.
3. `bash evals/runner.sh` — confirm the suite is green before you start (currently **5031 passing, 0 failed**).

## 1. Current state (durable facts)

| | |
|---|---|
| Repo | `drumfiend21/claude-tdd-pro` |
| Dev branch (work here) | `claude/eo-security-governance-uhqflp` |
| `main` HEAD | **`724fc4c`** (`724fc4ce211295e0618c0e2873511dec96614f7a`) |
| Active eval suite | **5031 / 0** (`bash evals/runner.sh`) |
| Latest feature | **§31 — universal technology resolution + per-project rule acquisition** (COMPLETE, Phases 1–3) |

Working tree is clean; everything is committed and pushed. The remote is the ONLY durable store (see §4).

## 2. What §31 is (the current feature, fully built)

Recognize any technology named in a vision/stack → apply its family's existing rules → acquire tech-specific
rules from that technology's own trusted sources into a per-project overlay → enforce them scoped to that
project → promote to the official ruleset only via a reviewed PR. Architecture: `docs/architecture-v1.9.md`
**§31 / §31.1–§31.9**; design detail: `docs/design/v1.22`, `v1.23`, `v1.24`.

**Shipped commands + files:**
- `commands/resolve-technology.sh` (S-58) — name → 4-axis coordinate + umbrella + `present|needs_source|unresolved`.
- `standards/technology-umbrella-registry.yaml` (S-59) — umbrellas → existing namespaces; technologies → coordinate/umbrella/fitness.
- `commands/acquire-technology-rules.sh` (S-60) — extract cited rules from source content → `_project/<id>/<tech>/` (4-axis tagged, provenance). Flags: `--only-mentioning`, `--max-rules`, `--explain`.
- `commands/acquire-technology-live.sh` (S-60 wrapper) — resolve → select umbrella + canonical sources → read fetch-cache → acquire; whole-source for canonical, mention-filtered for general; emits `rule_count=<n> sufficiency=ok|below-threshold-<N>` (P-18 ≥30 floor, `--threshold`).
- `standards/technology-source-registry.yaml` — technology → its canonical docs (whole-source acquisition).
- `commands/promote-project-rule.sh` (S-64) — `--plan|--apply|--release`; MOVE working→official (PR-gated, §31.2).
- `commands/recommend-technology.sh` (S-61) — grounded best-fit per umbrella (e.g. Angular over React).
- `rubric/aggregator.sh` — `--project <id>` walks `_project/<id>/` only (`origin: project`); default = official byte-identical.
- `rubric/enforce-file.sh` — `--project <id>` loads the project overlay first-class, scoped.
- `commands/full-surface-intake.sh` — the consult; emits `families_active`, `project_id`, `project_overlay_namespaces`; `--stack-add` accepts a technology name (G-3 bridge).

**Non-negotiable invariants (do not break):**
- Official `active.json` is byte-identical without `--project` (acquisition writes ONLY to `_project/`, gitignored).
- The official ruleset changes ONLY via a reviewed promotion PR (§31.2). Automation never writes an official namespace.
- Cross-project scoping is fail-loud: a `--project A` run never sees `_project/B/`.
- Rules are never fabricated — every acquired rule cites a real source + carries a 4-axis tag.

## 3. The per-CL workflow (follow it exactly — it is the process)

For any change, run this loop (full detail in `CLAUDE.md` "Workflow loop"):
0. **Extract from the architecture first.** Quote the literal feature IDs / §-labels for the scope. Never invent a decomposition.
1. **Write specs** in `evals/specs/` (behavior-named ≥20 chars, hermetic, `expect.exit_code` + `stderr_contains`). Generators live in the scratchpad; the committed spec JSONs are the tests.
2. **Self-audit** — architecture fidelity (every folder/ID maps verbatim), ≥10 specs/feature, non-shallow, public-API only.
3. **Verify** — `bash evals/runner.sh` stays fully green. Filter one family with `bash evals/runner.sh <prefix>`.
4. **Commit** with a body containing the audit findings, then **push immediately**.

**Amend the architecture append-only:** write detail into a NEW `docs/design/<version>-<slug>.md`, then APPEND a reference block (`### §N …`) to `docs/architecture-v1.9.md` carrying the feature IDs (standard-form `- **S-N**` bullets), §2.X contracts, §25 vocab, anti-drift folder map, §20 note inline. Verify `git diff --numstat docs/architecture-v1.9.md` shows **0 in the deletions column** before committing.

## 4. WORK PRESERVATION (this environment re-clones between turns)

Commit+push is ONE inseparable step. The local tree can silently reset to the last-pushed remote commit between turns. So: push every commit immediately; `git fetch` + ff-merge at the start of every turn; never end a turn with uncommitted non-trivial work. Merge finished work to `main` (the pattern used all session: commit on the dev branch → push → `git checkout main && git merge --ff-only origin/main && git merge --no-ff <dev-branch>` → push main).

## 5. Gotchas learned this session (will bite you)

- **Apostrophe inside a `ruby -e '…'` block** closes the bash single-quote and breaks the script. Never put `'` (e.g. "technology's", "founder's") inside the Ruby portion — reword, or use double-quoted Ruby strings. Hit this 3× this session.
- **bash 3.2 / macOS portability** — see `docs/memory/feedback-bash32-portability-checklist.md` before any new `.sh`. Env vars for `ruby -e` must be set BEFORE the command, not passed as argv (an argv `VAR=x` is NOT `ENV["VAR"]` — this caused a real bug in the live wrapper).
- **`vendor/canonical-vocabulary/provenance.json`** gets touched by test runs — `git checkout --` it before every commit.
- **Test cleanup** — specs that write under `generated-code-quality-standards/` (e.g. promote-apply into `vue/`) must `rm -rf` the whole dir, not just the file; an empty leftover namespace dir makes `valid_ns` include it and breaks `--stack-add <tech>`.
- **Suite cost** — changing `commands/full-surface-intake.sh` / `commands/architect-session.sh` / the aggregator invalidates the e2e dependency cache → a cold full run (~2–9 min). Filter-run the affected family first.

## 6. Cross-repo boundary (CTP ↔ GCTP)

CTP does not edit GCTP; GCTP (`grok-…`) does not edit CTP. The only cross-repo action is a reviewed PR into CTP core. GCTP consumes CTP by pinning a SHA and re-pins via its own ADR process. GCTP's repo is NOT reachable from a CTP session — when a GCTP artifact (acceptance test, handoff) is needed, the operator pastes it. The established pattern: GCTP files a proposal (P-N), CTP owns its own decomposition and builds additively, then hands back the exact shipped shape + a re-pin SHA.

## 7. Open items (where to pick up)

- **G-1 (needs operator input):** on the SoftArchCert kata vision, classifier probes dropped 6→3 between pins `11126a8` and `16e9623`. Cannot diagnose without the **exact vision string** — get it, run `full-surface-intake.sh --workload "<vision>" --classify` at both pins, report regression vs precision-tightening.
- **GCTP-side (not CTP):** the URL→cache fetch orchestrator (harness owns the network download that populates `<cache>/<source-id>.txt`); the `audit-acquisition-sufficiency.sh` gate; `kata.sh` P-15 awareness; P-14 adoption.
- **Standing / decision-gated (not started):** profile-honoring UX; CL-J co-design consumer story; a real end-to-end kata run measured against the O'Reilly finalists (aspirational, never done — flag honestly).

## 8. How to run things

- Full suite: `bash evals/runner.sh` (filter: `bash evals/runner.sh cl562`).
- Aggregate the surface: `bash rubric/aggregator.sh --format json` (or `--project <id>` for a project overlay).
- Enforce one file: `bash rubric/enforce-file.sh --file <f> [--include-app-code] [--project <id>]`.
- Resolve/acquire/recommend: the §2 commands above; add `--explain` for operator-readable output.
- Pending-spec fidelity gate (promotion CLs): `bash rubric/detectors/audit-pending-spec-fidelity.sh …` (see `CLAUDE.md` Step 0.5).
- CL choreography helper: `scripts/cl-build.sh` (see `docs/memory/feedback-cl-build-orchestrator.md`).

## 9. One-paragraph orientation

The plugin scrapes coding-standard rules from trusted URLs, tags each rule on a 4-axis registry (Linguist /
PURL / K8s-GVK / IaC), aggregates them into a rule surface, and applies them at consult, architectural design,
and code-generation (write-time, byte-identically). §31 (just completed) makes that open-ended: any technology
named by the operator gets its family's existing rules immediately, and its own tech-specific rules acquired
from its canonical sources into a per-project overlay — first-class for that project, but official only after a
reviewed PR. Everything is additive, cited, tested, and PR-gated. Continue in that spirit: extract from the
architecture, spec it, verify green, commit+push, amend the architecture append-only.
