# Commit message template

The format every commit produced by this plugin follows. Combines
Conventional Commits (subject) with structured body sections from
Google's eng-practices ("what" + "why" + tests + numbers).

## Format

```
type(scope): imperative summary under 70 chars

Body in present tense, third person. Explains WHAT changed and WHY.
Links to issue/CL/decision if any. Notes acknowledged trade-offs.

Behavior: <user-visible behavior change, or "no behavior change —
pure relocation" for refactors>

Tests: <count of tests added/changed; e.g. "+15 strict unit + 3
regression. Suite: 138 → 156 (+18). All green.">

Numbers (refactors only): <god-file lines before/after, lint
warnings before/after, etc.>

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Type vocabulary

| Type | Use for |
|---|---|
| `feat` | A new user-visible feature |
| `fix` | A bug fix (with the test that would have caught it, per `bug-fix-discipline`) |
| `refactor` | Code change with no behavior change (extraction, rename, restructure) |
| `tidy` | Kent Beck's "tidy first" — structural change with NO behavior change AND NO new tests (separate from refactor: tidy is smaller, lighter-weight) |
| `test` | Adding/modifying tests without production code change |
| `chore` | Tooling, deps, config — no production logic change |
| `docs` | Documentation only |
| `perf` | Performance improvement |
| `security` | Security fix or hardening |
| `build` | Build system or external dep change |
| `ci` | CI configuration |

### TDD-cycle prefixes (when running tdd-driver or strict TDD)

For mechanically-verifiable TDD compliance (pattern from `chanwit/tdg`),
prefix the type with the cycle phase:

| Prefix | Meaning |
|---|---|
| `red:` | This commit ADDS a failing test. No production code change yet. |
| `green:` | This commit makes the previously-red test pass with the minimum code. No refactoring. |
| `refactor:` | This commit restructures (with tests staying green). Same as `tidy` but explicitly post-green. |

Example commit log on a TDD feature branch:
```
red:    add failing test for User.bookmark()
green:  add minimum bookmark logic to User
refactor: extract bookmark validation into helper
```

This ladder is mechanically verifiable: a `green` commit not preceded
by a `red` on the same scenario is a process violation. The
`pr-self-reviewer` agent flags this.

## Subject-line rules (Google eng-practices)

- **Imperative**: "Add", not "Adds" or "Adding". The subject reads as
  an order: "this commit will _____".
- **Complete sentence**, ending without a period.
- **Under 70 characters total** (including type/scope).
- **No issue numbers** in the subject — put `Fixes: #123` in the body.
- **No tag pile-up**: avoid `[area1][area2][area3]: do thing`. One
  scope is enough.

## Examples

### feat (new behavior)

```
feat(saved-translations): add favorite toggle on each saved card

Add a star icon to the saved translation card. Click toggles the
favorite state, persists to localStorage, and re-orders the list to
show favorites first.

Behavior: users can now mark saved translations as favorites; favorites
appear at the top of the list; state persists across reloads.

Tests: +6 strict unit tests in SavedList.test.jsx covering toggle,
persistence, and re-ordering. Suite: 156 → 162 (+6). All green.

Co-Authored-By: Claude <noreply@anthropic.com>
```

### fix (with bug-as-test)

```
fix(auth): re-validate user existence in JWT middleware

A token issued before the user was deleted previously passed
jwt.verify and downstream writes either succeeded against a
non-existent FK target or failed opaquely as 500. Middleware now
checks the users table after jwt.verify and returns a clean 401
"User no longer exists" if the row is gone.

Root cause: the middleware trusted the token's `id` claim without
checking it still corresponds to a real row.

Test: tests/api.test.js > "deleted user gets a clean 401". The test
deletes the user mid-session, replays the token, and asserts 401.

Tests: +1 regression test. Suite: 75 → 76 (+1). All green.

Co-Authored-By: Claude <noreply@anthropic.com>
```

### refactor (extraction)

```
refactor(phase4-w7b): extract VerseTextPanel component

Process: tests-first. 15 strict unit tests in VerseTextPanel.test.jsx
covering testament-label flip, greek_text/greek/greekText fallback
chain, RTL/LTR direction styling, person-tag rendering branches,
click wiring with versePersons-vs-personsMeta resolution priority,
and edge cases (empty/undefined persons). Confirmed file-not-found
failure first. Added 3 regression tests in the parent suite. All
pass against the live god-file. Then extracted; isolated 15/15;
replaced ~107 lines of inline JSX with <VerseTextPanel ... />.

Behavior: no behavior change — pure relocation.

Numbers: god-file 9237 → 9144 lines (-93). Cumulative Phase 4: 9786
→ 9144 (-642). Tests: 138 → 155 (+17). Build clean.

Co-Authored-By: Claude <noreply@anthropic.com>
```

### chore (tooling)

```
chore(phase1): apply prettier formatting pass

Apply project-wide Prettier formatting per the new config from the
preceding commit. No behavior change. Subsequent commits are content
changes only.

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Anti-patterns

- `Fix bug` (no info, useless in `git log`).
- `Updates` (gerund + no info).
- `WIP` (commit later when it's not WIP).
- `Several improvements` (split into separate commits).
- `feat: refactored auth and added new login page and fixed a bug`
  (three separate commits, please).
