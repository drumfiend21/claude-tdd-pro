# Meta Engineering Practices — Public Sources Only

Meta does NOT publish a comprehensive style guide equivalent to Google's.
Most internal coding standards are team-specific and enforced via
internal linters/tools. The rules below come from publicly available
sources only — Meta engineering blog posts, open-source projects
authored by Meta, and Phabricator/Sapling docs.

> **Caveat**: This document distinguishes documented (citable) practices
> from folklore-level claims (widely repeated by ex-Meta engineers but
> not in any official doc). Folklore-level items should be framed as
> "industry best practices inspired by the stacked-diff workflow"
> rather than "Meta requires X" in any tooling.

## Stacked diffs (documented)

- **Sapling SCM** (open-sourced Nov 2022) is Meta's source-control client. Source: [sapling-scm.com](https://sapling-scm.com/) and Meta's engineering blog post "Sapling: Source control that's user-friendly and scalable."
- **One commit = one diff = one PR.** `sl pr submit` (GitHub) or `arc diff` (Phabricator) pushes each commit in a stack as its own reviewable unit.
- Sapling tracks commits by **stable commit identity across rebases**, so reviewers see "version 2 of the same diff" rather than a new PR. Source: Sapling docs, "ReviewStack" section.
- **ReviewStack** ([reviewstack.dev](https://reviewstack.dev)) is Meta's open-source reviewer UI for stacked GitHub PRs.
- Author tooling: `sl commit`, `sl amend`, `sl absorb` (auto-distributes uncommitted changes back into the right commits in the stack), `sl restack` (rebase on updated parent). Source: Sapling docs, "Commands" reference.

**Sizing — folklore-level**: ex-Meta engineers in conference talks and blog posts describe a "good" diff as reviewable in 15–30 minutes; stacks of 5–15 diffs are common. Not in any official doc — frame as "stacked-diffs best practice," not "Meta requires."

## Test plans (documented)

- Phabricator's diff form has a **required Test Plan field** by default. Cannot submit a diff without populating it. Source: Phabricator docs (`secure.phabricator.com/book/phabricator/article/differential/`, archived; community fork at [phorge.it](https://phorge.it)).
- The Test Plan answers "How did you verify this change works?"
- **Acceptable contents:**
  - Commands run + observed output (`buck test //foo:bar`, paste of green output)
  - New unit/integration tests added (link/list)
  - Manual UI verification with screenshots / screen recording
  - Load-test or benchmark numbers, before/after
  - Pure refactor: "Existing tests pass; no behavior change intended" (acceptable but minimal)
- **Bad test plans (commonly cited)**:
  - "Tested." (no detail)
  - "It works on my machine."
  - "Will test in prod." (acceptable only with explicit feature-flag / rollout plan)

## Code review culture (documented + folklore)

- **"Move Fast With Stable Infra"** (revised from "Move Fast and Break Things" around 2014). Source: F8 2014 keynote, transcripts available.
- **Time in Review (TIR)** as a tracked metric. Source: engineering.fb.com posts on developer infrastructure.
- **Bootcamp** (6-week onboarding): new engineers land diffs in week 1. Source: many public posts, recruiting materials.
- **OWNERS-style code ownership** in the monorepo, with required reviewers. Source: Buck/Buck2 docs and various engineering blog posts.
- **Gatekeeper** (feature flag system): "ship to 1% of users, measure, expand" is the default workflow. Source: engineering.fb.com posts on Gatekeeper and Configerator.

**Folklore (don't enforce as hard rules)**:
- "Reviewers should respond within 24 hours" — repeated in ex-Meta blogs, not an official published SLA.
- "Two-reviewer rule for production code" — varies by team; not a global policy in any public doc.

## Linter / autoformat (documented)

- **Buck2** (build system): integrates linters as build targets. [github.com/facebook/buck2](https://github.com/facebook/buck2)
- **Pyre** (Python type checker): used internally on Instagram's Python codebase. [github.com/facebook/pyre-check](https://github.com/facebook/pyre-check)
- **Pyfmt** is publicly referenced as Meta's internal Python formatter, wrapping **Black** + **usort** (open at [github.com/facebook/usort](https://github.com/facebook/usort)).
- **Flow** (JS type checker): [flow.org](https://flow.org). Originally default for Meta JS; gradually being supplemented by TypeScript on some surfaces per public posts.
- **Prettier**: created by then-Meta engineer James Long; widely used at Meta but not Meta-exclusive.
- **`eslint-config-fbjs`** + **`eslint-plugin-react-hooks`** (Meta-authored): [github.com/facebook/eslint-plugin-react-hooks](https://github.com/facebook/eslint-plugin-react-hooks)
- **Hack** (PHP fork) ships with **`hh_client`** type checker and **`hackfmt`** formatter. [hacklang.org](https://hacklang.org)
- **Enforcement model**: pre-commit hooks + CI lint jobs. A diff with lint errors typically can't land. Source: Phabricator's Harbormaster docs.

## Genuinely public Meta-authored conventions

- **React documentation** ([react.dev](https://react.dev)): includes "Rules of React," "Rules of Hooks," "You Might Not Need an Effect." Enforceable via `eslint-plugin-react-hooks`.
- **Hack language reference** ([docs.hhvm.com/hack/](https://docs.hhvm.com/hack/)): official language docs including style conventions.
- **Flow documentation** ([flow.org/en/docs/](https://flow.org/en/docs/)): type system conventions.
- **Jest** ([jestjs.io](https://jestjs.io)): testing conventions, originally Meta-authored (now under OpenJS Foundation as of 2022).
- **Relay** ([relay.dev](https://relay.dev)): GraphQL client conventions including the colocated-fragment pattern.
- **Sapling** ([sapling-scm.com](https://sapling-scm.com)): workflow conventions for stacked changes.
- **Buck2** ([buck2.build](https://buck2.build)): build target conventions.
- **Pyre** ([pyre-check.org](https://pyre-check.org)): Python typing conventions Meta uses internally.

## NOT publicly available — do not invent rules from these

- The internal "Coding Standards" wiki.
- Internal Hack style guide beyond what hacklang.org publishes.
- Internal review checklists.
- Internal diff-size or stack-depth limits.

## Defensibly enforceable in a plugin

1. Require non-empty Test Plan section in PR description (Phabricator convention, citable).
2. Warn (not block) on PRs > ~400 LOC of non-generated diff (folklore-supported — frame as "stacked-diffs best practice").
3. Enforce `eslint-plugin-react-hooks` rules (Meta-authored, public).
4. Enforce Prettier + Black/usort formatting (publicly used by Meta, also industry-standard).
5. Suggest feature-flag wrapping for risky changes (Gatekeeper pattern, citable but generic).
6. Pyre/Flow/TypeScript strictness defaults matching their open-source recommended configs.

## Verifying URLs before shiping

URLs in this doc were assembled from training data; before publishing the
plugin, verify each link still resolves. The Meta engineering blog has
moved domains a few times (engineering.fb.com → about.fb.com / various).
Phabricator's canonical docs at secure.phabricator.com may now be
archive-only — check phorge.it for the active community fork.
