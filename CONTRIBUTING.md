# Contributing

Thank you for your interest in claude-tdd-pro. The project ships under
Apache-2.0 (see [LICENSE](LICENSE)) and welcomes contributions that
follow the architectural and process discipline below.

## Authoritative documents

Read these before submitting any PR. They are not optional reading;
the §25 fidelity gate and the per-CL audit machinery rely on them.

- **[docs/architecture-v1.9.md](docs/architecture-v1.9.md)** — canonical
  architecture. Every feature ID, contract label, phase definition.
- **[CLAUDE.md](CLAUDE.md)** — per-CL workflow discipline + the catalog
  of drift mechanisms that have actually caused regressions on this
  project. The 6 drift mechanisms are not academic; each one corresponds
  to a CL that had to be rolled back.
- **[docs/SLO.md](docs/SLO.md)** — operational service-level objectives.
- **[docs/adr/](docs/adr/)** — architecture decision records (MADR
  format per §2.16).

## The per-CL workflow (mandatory)

Every CL on this project follows the workflow loop documented in
CLAUDE.md. Summary:

1. **Step 0 — Pre-flight architecture extraction.** Read the relevant
   §X / §2.Y of architecture-v1.9.md. Quote the literal feature
   decomposition before writing any spec. Do not infer from memory.
2. **Step 0.5 — Pending-spec content fidelity check** (when promoting
   pending specs). Run `bash rubric/detectors/audit-pending-spec-fidelity.sh`.
3. **Step 1 — Write the tests.** Use literal architecture feature names.
   Place under `evals/pending/<phase>/<feature-id>-<descriptive-label>/`.
4. **Step 2 — Self-audit.** Verify architecture fidelity, 10-per-feature,
   non-shallow coverage, public-API only, flag-invention disclosure.
5. **Step 3 — Verify.** Run `bash evals/runner.sh`; confirm the full
   suite stays clean.
6. **Step 4 — Propose commit.** Commit body includes the per-feature
   spec counts and the audit findings from Step 2 (not a claim — the
   actual findings).

The orchestrator `scripts/cl-build.sh` drives Steps 0.5 through 3 for
batch CLs.

## Drift mechanisms to watch for

These have happened. They are not hypothetical.

1. **Compaction loss + inferred decomposition** — brain fills the gap
   between context and architecture text with plausible-sounding-but-wrong
   synthesis. Defense: Step 0 pre-flight, every CL.
2. **Self-audit checks process, not scope** — specs can be hermetic,
   behavior-named, exit-coded, AND test the wrong feature. Defense:
   architecture-fidelity is the first audit check.
3. **Flagging-as-bypass** — putting "this is my interpretation" in a
   commit body becomes a discharge of duty. Defense: flagging must
   STOP-and-extract-from-text, not be a footnote.
4. **Approval feedback loop** — each approval reinforces previous
   behavior. Defense: audit results in commit bodies must be specific.
5. **Pattern-cloned coverage** — hitting 10 specs per feature with 10
   variants of the same shape. Defense: verb-diversity audit.
6. **Pending-spec invented vocabulary** — folder name matches arch,
   but spec bodies assert invented field names. Defense: §25 fidelity
   gate.

If you find yourself reasoning "this should be E-N because…" without
having quoted the architecture *this turn* — **STOP. Re-read the
relevant section.**

## Commit message format

```
<type>: <CL-N> -- <short summary> (+N specs, AAAA→BBBB)

Per CLAUDE.md Step 0 architecture extraction: §X (Feature-N) defines
<one-line>. Batch-CL per feedback-batch-cl-convention.md (where
applicable).

Step 0.5 §25 fidelity gate: <CLEAN | findings>.

Per-feature spec counts (this CL):
  Feature-N <label>:                 N specs
  ...

Audit (Step 2):
  Architecture fidelity:    PASS — every feature ID quoted from §X
  N specs per feature:      PASS
  Non-shallow:              PASS — <one-line evidence>
  Public-API only:          PASS
  Test-affordance flags:    <none | listed inventions>

Spec patches in this CL (if any):
  - <feature>: <patch description + rationale>

https://claude.ai/code/session_<id>
```

Types: `feat`, `fix`, `docs`, `refactor`, `polish`, `merge`.

## Spec quality

Per CLAUDE.md §21 definition-of-done:

- **Hermetic** — runner provides a clean tmpdir; setup arrays create
  needed fixtures.
- **State-asserting** — `expect.exit_code` is explicit;
  `expect.stderr_contains` checks meaningful output.
- **Behavior-named** — name describes what the SUT does, not its
  mechanics. Minimum 20 characters.
- **No opaque IDs in names** — never `F-1`, `E-7`, `(§2.X)`. Use
  descriptive phrases.
- **Google testing best practices** — no sleep in test body (except
  when testing time-elapsed mechanisms), no external network,
  public-API only, stubs not mocks at process boundary.
- **Shape vs behavior** — every executable substrate must have at
  least one behavior spec (invokes the substrate end-to-end, not just
  greps for terms in source).

## Project hygiene

- All shell scripts pass `shellcheck` (best effort; bash-3.2 portability
  per `docs/memory/feedback-bash32-portability-checklist.md`).
- All JSON parses cleanly. Run
  `node -e 'JSON.parse(require("fs").readFileSync("<spec>","utf8"))'`
  on suspicious files.
- All MD files use the same heading conventions (`# Title`, `## Section`).
- No commits to `main` without a green `bash evals/runner.sh`.

## Pre-commit local check

```bash
bash scripts/cl-build.sh <cl-num> <phase> <feature-id> [<feature-id>...]
# or for solo edits:
bash evals/runner.sh
```

## Code of conduct

Be kind. Cite sources. Quote the architecture verbatim. Acknowledge
when you don't know.

## Disclosing AI-assisted contributions

A substantial portion of this project's commit history was authored
with Claude Code assistance (see commit `Co-authored-by:` trailers
and `https://claude.ai/code/session_*` links in commit bodies). This
is acknowledged transparently; AI assistance does not exempt
contributions from the workflow loop above. Every AI-assisted CL
goes through the same Step 0 → Step 4 audit a human contributor's
would.

## Questions

Open an issue or start a discussion on the GitHub repository.
