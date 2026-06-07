# PROJECT_CONTEXT_FOR_PLANNER

Static architectural and process knowledge that the outer-loop
planner (Grok in `grok-claude-tdd-pro`) must respect when
decomposing work for the inner-loop executor (Claude in
`claude-tdd-pro`).

**This file is the single source of truth** for the durable
knowledge an external planner needs. It is injected once at session
start by `grok-claude-tdd-pro/scripts/sync-plugin.sh --ensure` and
read as static context — there is **no per-feature consultation
round-trip** (see `docs/adr/0006-static-context-injection-for-external-planners.md`
for the decision and rejected alternative).

## Core principles

### Test-shape discipline
- Tests must be hermetic (runner provides a clean tmpdir; setup
  arrays create all needed fixtures).
- Names describe what the SUT does, not its mechanics. Minimum 20
  characters.
- No opaque IDs in names — never `F-1`, `E-7`, `(§2.X)`, `(C-9)`.
  Use descriptive phrases.
- Behavior specs assert on output / exit code / side effects.
  Shape specs (grep against substrate) are acceptable only for
  documentation features.
- Public-API only; stubs not mocks at the process boundary.

### One ticket = one R-G-R cycle
- Each ticket must be small enough to complete Red → Green →
  Refactor in one session.
- If a green path requires an intermediate refactor to enable,
  split the refactor into a prior ticket.
- Never mix feature work with structural cleanup in the same ticket
  unless the refactor is a pure extraction with no behavior change.

### Refactoring sequencing
- The refactor that *enables* a feature ships before the feature
  itself.
- The refactor that *follows* a feature (cleanup of duplication
  surfaced by the green path) ships after, as a separate ticket.

### Architecture-fidelity invariants

- **Every feature ID, contract label, folder name, spec name** must
  be quoted verbatim from `docs/architecture-v1.9.md` for the
  scope being planned. Do not invent feature IDs from memory.
- Test-affordance CLI flag invention is acceptable with disclosure;
  invented feature folders are not. See `CLAUDE.md` "CLI-flag
  invention discipline" section.
- Cross-cutting `§2.X` contracts have tiered priority per
  `docs/CONTRACT_PRIORITIES.md`. When planning conflicts arise,
  lower tier wins.

### ADR triggers
Any of the following must be backed by an ADR (per
`docs/adr/INDEX.md` and `CLAUDE.md`):
- Change to module boundaries or public contracts.
- New major dependency, new programming language, new platform.
- Change to the enforcement contract (LSP / hook / CI exit codes).
- Decision that crosses two phases of `docs/architecture-v1.9.md`.
- Departure from any §2.X Tier-1 contract.

### Drift mechanisms to defend against (from `CLAUDE.md`)

These are AI failure modes that have caused real regressions on this
project. The planner must produce tickets that defend against them:

1. **Compaction loss + inferred decomposition.** Conversation
   context falls out; the planner fills the gap with plausible-
   sounding synthesis. CL-08/09/10 invented ~297 wrong specs this
   way. **Defense:** every ticket explicitly quotes the architecture
   text it derives from.

2. **Self-audit checks process, not scope.** Tickets can be
   hermetic, behavior-named, exit-coded — AND target the wrong
   feature. **Defense:** the first audit check on any ticket must
   be "does this feature ID appear in `docs/architecture-v1.9.md`?"

3. **Flagging-as-bypass.** Writing "this is my interpretation" in
   a ticket body becomes a discharge of duty rather than a STOP
   signal. **Defense:** flagging must STOP-and-extract, not be a
   footnote.

4. **Approval feedback loop.** Each "approved" ticket reinforces
   the previous behavior. **Defense:** every ticket's success
   criteria must be specific (counts, mappings, fidelity findings)
   rather than "all checks pass."

5. **Pattern-cloned coverage.** Hitting "N tests per feature" by
   writing N variants of the same shape test instead of N distinct
   behaviors. **Defense:** verb-diversity check in audit; shape-
   only tests must justify themselves against architecture text.

6. **Pending-spec invented vocabulary.** Specs that pre-existed in
   pending dirs may assert behavior using vocabulary not in
   `docs/architecture-v1.9.md`. The folder name passes fidelity
   checks; the drift hides inside spec bodies. **Defense:** Step
   0.5 fidelity gate via
   `rubric/detectors/audit-pending-spec-fidelity.sh`.

### Bash 3.2 portability (substrate writing)

When a ticket touches `.sh` files in this repo, the planner must
respect the seven recurring portability bugs documented in
`docs/memory/feedback-bash32-portability-checklist.md`:

1. **No associative arrays.** bash 3.2 (macOS default) rejects
   `declare -A`. Use `node -e '...'` for map/dict operations.
2. **`wc -l < file` pads output with whitespace on macOS.** Always
   pipe through `| tr -d ' '`.
3. **`printf '...%\n'` is malformed.** Use `%%\n` for literal `%`.
4. **Env-var-passing-first.** For external commands, env vars must
   precede the command: `FOO=bar cmd args`, not `cmd args FOO=bar`.
   This is the bug class that caused CL-420.
5. **`set -u` + empty array dereference crashes** in bash 3.2.
   Guard array expansions with `${arr[@]:-}`.
6. **BSD grep needs `--`** before pattern arguments that start with
   `-`. macOS grep is BSD.
7. **Redirect order matters.** `2>&1 >file` puts stderr on the
   terminal; `>file 2>&1` puts both in the file. The second is
   almost always what's wanted.

`[[ ]]` and `(( ))` are fully supported in bash 3.2; do not
recommend avoiding them.

## How the planner should use this file

When decomposing a feature brief + research bundle:

1. **Respect the constraints above** when proposing ticket
   boundaries, `depends_on`, `file_scope`, acceptance criteria.
2. **Surface any tension** with these rules explicitly in the
   decomposition output — do not silently ignore.
3. **Prefer smaller, more atomic tickets** when in doubt; the
   R-G-R cycle constraint is the hard limit.
4. **Reference architecture sections by literal name** (e.g.,
   `§16 E-9 ESLint formatters`) — never paraphrase.
5. **If a feature-specific architectural concern emerges that
   isn't captured here**, surface it in the research bundle for
   that feature — do not propose adding it to this file unless it
   is durable, project-wide knowledge.

## What's NOT in this file (by design)

- Feature-specific architectural decisions — those belong in the
  research bundle for the feature.
- Dynamic state (current spec counts, fitness-gate status, telemetry
  data) — those are observable at planning time via the live
  rubric runner.
- The full `docs/architecture-v1.9.md` text — the planner should
  quote it directly from the file, not from a summary.

## Cross-references

- `CLAUDE.md` — full per-CL workflow + drift mechanism catalog
- `docs/architecture-v1.9.md` — canonical architecture text
- `docs/ARCHITECTURE.md` — 200-line operator-facing summary
- `docs/CONTRACT_PRIORITIES.md` — §2.X tier ranking
- `docs/memory/feedback-bash32-portability-checklist.md` — full
  portability checklist
- `docs/adr/0006-static-context-injection-for-external-planners.md`
  — decision record for this approach
