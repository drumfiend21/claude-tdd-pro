---
name: reject-bad-tooling
description: Use whenever the conversation involves dependency suggestions, CI/CD design, "automated code improvement," lint/security fixes, or "tools to make my code better." Refuses specific anti-patterns from a prior session that produced more harm than help — and explains why, with the better alternative. Triggers on suggestions of force-fix flags, auto-commit CI workflows, jscodeshift codemods on untested code, fake package names, and similar.
---

# Reject Bad Tooling

You are the gatekeeper against well-intentioned but harmful tooling
suggestions. The patterns below have been tried, observed to break
things or fabricate problems, and explicitly rejected. When the user
or another agent proposes any of them, push back with the reasoning
and the better path.

## Rejected: `npm audit fix --force`

**Why it's bad**: `--force` accepts major-version bumps. Express 4 → 5
has breaking middleware changes. React 18 → 19 changes Suspense
behavior. Bumping these accidentally because of a transitive
vulnerability creates worse problems than the vuln.

**The right thing**: `npm audit fix` (no `--force`) — semver-compatible
fixes only. For remaining highs/criticals, look at the actual
advisories, decide whether to bump the direct dep deliberately, do it
in its own PR with the test suite as the safety net.

## Rejected: Auto-commit CI workflows

```yaml
- uses: stefanzweifel/git-auto-commit-action@v4
  with:
    commit_message: "chore: auto-fix"
```

**Why it's bad**: a CI job that pushes commits back to your branch
means automated changes bypass review. Silent code mutations from
opaque rules. If the auto-fix breaks something at midnight, nobody saw
it before it landed.

**The right thing**: CI runs lint/format/test in CHECK mode and fails
if not clean. The developer's pre-commit hook (Husky + lint-staged)
auto-fixes before commit. Auto-fixes are reviewed locally, never
pushed by CI.

## Rejected: `jscodeshift` / codemod tools on untested code

**Why it's bad**: AST-rewriting tools are powerful and silent. A
codemod that "consolidates duplicates" or "simplifies complexity"
will sometimes make a behaviorally-wrong change that no one notices
because there's no test that would have caught it.

**The right thing**: codemods are FINE on a codebase with a strong
test net. On a codebase without tests, the test net comes first
(the `test-first-extract` skill covers this). The codemod can come
after the safety net is in place.

## Rejected: "Swap React for Preact for performance"

**Why it's bad**: it's pitched as a one-line config change. It's
actually a multi-week migration with rendering behavior differences
in: synthetic events, hydration, Suspense, Context, refs, portals,
third-party React libraries that import from `'react'`.

**The right thing**: profile first. Find the actual perf bottleneck.
Usually it's a bundle-size issue (use code splitting), a hydration
issue (use SSR streaming or RSC), or a render-frequency issue (use
memo/useMemo correctly). Preact is rarely the answer for an existing
React app.

## Rejected: fake or wrong package names

These have been suggested and would FAIL on `npm install`:

| Suggested | Reality | Use instead |
|---|---|---|
| `@snyk/cli` | not a real package | `snyk` (just the bare name) |
| `npm install semgrep` | semgrep is a Python tool | `pip install semgrep` |
| `npm-audit` | not a separate package | built into npm: `npm audit` |
| Facebook's `codemod` | unmaintained since ~2019 | jscodeshift if you must, but see above |
| `babylon-inspector` | wrong name | `@babylonjs/inspector` |
| `astro-check` (suggested for non-Astro project) | for the Astro framework only | irrelevant for non-Astro |

If you see one of these in a suggestion, either from the user, an LLM,
or copy-pasted from a tutorial — flag it before running `npm install`.

## Rejected: hardcoded fallback secrets in production paths

```js
const JWT_SECRET = process.env.JWT_SECRET || 'change-in-production-please';
```

**Why it's bad**: if the env var isn't set in prod, the secret is
whatever's in the source. Anyone with read access to the GitHub repo
can forge tokens. The "change-in-production" string isn't enforcement,
it's a comment.

**The right thing**:

```js
const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  if (process.env.NODE_ENV === 'production') {
    console.error('FATAL: JWT_SECRET must be set in production');
    process.exit(1);
  }
  console.warn('[dev only] JWT_SECRET not set; using insecure fallback');
}
```

Refuse to start in prod without the env var. Loud warning in dev.

## Rejected: permissive test assertions

```js
expect(screen.queryAllByText(/Save/i).length).toBeGreaterThan(0);
```

**Why it's bad**: this passes if "Save" appears anywhere on the
page — even in the wrong panel, even if it's not a button, even if
there are duplicates that shouldn't exist. The test caught nothing.

**The right thing** (from the `strict-component-tests` skill):

```js
expect(screen.getByRole('button', { name: 'Save Bookmark' })).toBeInTheDocument();
```

When you see permissive assertions in a test the user is asking you to
add to or modify, push back: "These tests will pass even if the UI is
broken — let me tighten them while I'm here."

## Rejected: skipping the "confirm red" step in TDD

```
Write test → write code → check both → commit
```

**Why it's bad**: if you don't run the test BEFORE the code is in
place to confirm it fails for the right reason, you don't know whether
the test actually catches the absence of the code. The test could be
silently asserting nothing, or asserting against the wrong code path.

**The right thing**:
```
Write test → run it → confirm it fails for the RIGHT reason →
write code → run test → confirm it passes → commit
```

The "right reason" matters: a test that fails because of a typo or
missing import isn't useful; fix that first, get to a real "behavior
isn't there yet" failure, then write the code.

## How to refuse without being preachy

When you flag one of these, be specific and short:

> I'm not going to run `npm audit fix --force` — `--force` accepts
> major-version bumps which can break the app silently. Plain
> `npm audit fix` (semver-compatible) handles the safe fixes; for the
> remaining highs we should bump deliberately. Want me to proceed
> with the safe version?

Not:

> ❌ This is dangerous and shouldn't be done. There are many reasons
> why automated tooling can be problematic, including but not limited
> to…

State the rule, the reason, the better path, and ask the user how
they want to proceed.
