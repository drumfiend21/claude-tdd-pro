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

## Recruiting a secondary maintainer

The project is actively seeking one trusted reviewer for the role.
Criteria:

- Has read `docs/architecture-v1.9.md` end-to-end at least once.
- Has read `CLAUDE.md` and understands the six drift mechanisms.
- Has shipped at least one CL through the per-CL workflow (Step 0 →
  Step 4) under primary-maintainer pairing.
- Is willing to be on-call for hotfix reviews on a best-effort basis.

Interested? Open a GitHub issue titled "Maintainer interest:
&lt;your-name&gt;" or contact @drumfiend21 directly.

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
