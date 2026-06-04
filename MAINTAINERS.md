# Maintainers and succession

Per the simulated Kua / Böckeler / Fowler review, the project has an
explicit bus-factor problem (one primary maintainer with AI assistance)
and the succession plan must be documented rather than implicit.

## Current maintainers

| Role | Name | Scope |
|---|---|---|
| Primary maintainer | @drumfiend21 | Architecture, runner, installer, releases |
| Secondary maintainer | _(seeking — see below)_ | All; specifically peer-review of CLs touching arch.md |

## Succession plan

### If the primary maintainer is unavailable for < 7 days

Status quo. Open issues and PRs queue; no merges land. Consumers
continue on the current pinned commit; the lockfile model
(`.claude-tdd-pro.lock.json`) means existing installs are unaffected.

### If the primary maintainer is unavailable for 7-30 days

Tier-1 hotfix-only mode. The hotfix-without-AI emergency path
(documented in `docs/HOTFIX_WITHOUT_AI.md`) is the only acceptable
authoring mechanism. Hotfixes must:

- Touch at most one substrate file.
- Pass the four fitness functions (`npm run drift:audit`).
- Pass the full suite (`npm test`).
- Be reviewed by at least one secondary maintainer or trusted reviewer.

If no secondary maintainer exists at this point, the project enters
**maintenance freeze** until one is recruited.

### If the primary maintainer is unavailable for > 30 days

The project is declared in **maintenance freeze**. README is updated
with a banner. Consumers are advised to pin to the last released
commit. Active development is suspended until a maintainer transition
is documented.

## Recruiting maintainers — aggressive policy

Per the simulated Musk-team review (DJ Seo):
> "A codebase with talent density of 1 — even when that 1 is highly
>  capable and AI-augmented — is at infinite bus-factor risk."

The project is **actively seeking** 2-3 secondary maintainers. Until
talent density reaches at least 3, the following invariants apply:

- **No new architecture phases or amendments** ship until the second
  maintainer is recruited. (Maintenance-only mode for the canonical
  architecture document.)
- **All CLs touching `rubric/runner.sh`, `scripts/cl-build.sh`,
  `scripts/install.sh`, or `rubric/detectors/audit-*.sh`** require
  primary-maintainer review **plus** a documented review by at
  least one external reader (can be informal — a GitHub comment
  recording that someone else looked at it).
- **Quarterly hotfix-without-AI rehearsal** must be completed by the
  primary maintainer and the result logged to
  `docs/hotfix-rehearsal-log.md`. Skipping a rehearsal triggers
  maintenance-freeze status.

### Criteria for becoming a secondary maintainer

- Has read `docs/ARCHITECTURE.md` (the 200-line operator-facing
  version) and `docs/FIRST_PRINCIPLES.md`.
- Has read `CLAUDE.md` and can articulate at least 3 of the 6 drift
  mechanisms in their own words.
- Has shipped at least one CL through the per-CL workflow under
  primary-maintainer pairing.
- Is willing to commit to ~4 hours of review work per month.

### Interested?

- **Quickest path:** open a GitHub issue titled "Maintainer interest:
  &lt;your-name&gt;" with a 2-paragraph statement of why you're
  interested.
- **Direct path:** contact @drumfiend21 via the email in commit
  history.
- **Pair-first path:** comment on any open issue or PR with a
  thoughtful technical observation; this demonstrates capability
  better than an introduction letter.

### What we offer

- Genuine architectural input on a project that explicitly values it
  (see `docs/ADR/`, `CONTRIBUTING.md`).
- Citation in `CHANGELOG.md` and (with permission) public
  acknowledgment as a project maintainer.
- A real ownership stake in the system's evolution under
  Apache-2.0.
- A working example of AI-augmented development with explicit
  discipline boundaries — useful for your own work elsewhere.

## Onboarding a new maintainer (shadow + drive)

1. **Shadow three CLs.** Pair with the primary maintainer on three
   consecutive CLs. Read the architecture text for the scope; review
   the spec drafts; co-write the commit body audit findings.
2. **Drive one CL solo.** Pick a backlog item from §20. Execute Step
   0 → Step 4 alone. Primary maintainer reviews only the final commit
   message and runs `npm run drift:audit` independently.
3. **Add to CODEOWNERS.** On successful solo CL, the new maintainer
   is added to `CODEOWNERS` for their primary area of expertise.

## AI-assisted contributions: maintainer policy

Per Birgitta Böckeler's review note:

> "Relying on AI doesn't reduce the bus factor, it shifts it. If the
> maintainer's Claude account is gone tomorrow, who can take over?"

The project's defense is the **hotfix-without-AI emergency path**
(`docs/HOTFIX_WITHOUT_AI.md`). At least one workflow must demonstrably
work using only the architecture text and the per-CL discipline
without AI assistance. The primary maintainer commits to keeping this
path working and rehearsing it at least quarterly.

## Why this matters

Bus-factor-1 with AI assistance is a load-bearing design choice. We
acknowledge it explicitly rather than pretending the AI eliminates
the risk. The discipline documented in CLAUDE.md is what makes the
AI-assisted work auditable; the discipline documented here is what
makes the project resilient to maintainer change.
