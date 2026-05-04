---
name: strict-component-tests
description: Use when writing or reviewing test files for React/JS/TS/Python components, hooks, modules, or routes. Enforces strict assertions that actually catch regressions, in contrast to permissive tests like `queryAllByText(...).length > 0` that pass against broken UIs. References QUALITY-BAR.md for the canonical strictness rules.
---

# Strict Component Tests

You are writing tests that must catch real regressions. Permissive
assertions are worse than no test — they create false confidence.

## The strictness rules

### Prefer specific queries over text-match

| Avoid | Prefer | Why |
|---|---|---|
| `screen.queryAllByText(/Save/)` | `screen.getByRole('button', { name: /Save/ })` | Finds the button specifically; fails if it's missing or its accessible name changed |
| `screen.getByText('Submit')` | `screen.getByRole('button', { name: 'Submit' })` | Same. Also: works for screen readers. |
| `document.querySelector('.foo')` | `screen.getByLabelText('Foo')` or `screen.getByTestId('foo')` | CSS classes are implementation details; semantic queries are stable |

### Exact counts where uniqueness is expected

| Avoid | Prefer | Why |
|---|---|---|
| `expect(matches.length).toBeGreaterThan(0)` | `expect(matches).toHaveLength(1)` (or N) | Catches accidental duplicates |
| `expect(matches.length).toBeGreaterThanOrEqual(1)` | `toHaveLength(N)` if N is known | Same; only use `>= 1` when duplicates are inherent (e.g., text appears in nav AND content) |

### jest-dom matchers over manual DOM inspection

| Avoid | Prefer |
|---|---|
| `expect(btn.disabled).toBe(true)` | `expect(btn).toBeDisabled()` |
| `expect(el.textContent).toContain('foo')` | `expect(el).toHaveTextContent(/foo/)` |
| `expect(el.classList.contains('x')).toBe(true)` | `expect(el).toHaveClass('x')` |
| `expect(el.getAttribute('aria-label')).toBe('x')` | `expect(el).toHaveAttribute('aria-label', 'x')` |
| `expect(input.value).toBe('x')` | `expect(input).toHaveValue('x')` |
| `expect(document.activeElement === el).toBe(true)` | `expect(el).toHaveFocus()` |
| `el.style.display !== 'none'` etc. | `expect(el).toBeVisible()` |

### `userEvent` over `fireEvent` for interactions

`fireEvent.click` dispatches a single event. `userEvent.click` simulates
the full sequence (mouseover, mousedown, focus, mouseup, click) and
respects `disabled` / `pointer-events: none`. Use `userEvent` unless
you have a specific reason not to.

```js
import userEvent from '@testing-library/user-event';
const user = userEvent.setup();
await user.click(screen.getByRole('button', { name: /Save/ }));
await user.type(screen.getByRole('textbox'), 'hello');
```

### Cleanup discipline (vitest with globals: false)

If `vitest.config.js` has `globals: false`, cleanup does NOT happen
automatically between tests. Renders accumulate in the DOM and
`screen.getBy*` sees duplicates from previous tests, producing
false-positive "found multiple elements" failures across files.

Fix: in `setupFiles` (e.g. `src/__tests__/setup.js`):

```js
import '@testing-library/jest-dom/vitest';
import { afterEach } from 'vitest';
import { cleanup } from '@testing-library/react';

afterEach(() => {
  cleanup();
});
```

If you write a test file and see "found multiple elements" failures
across multiple test files but each passes in isolation — this is the
cause.

### Assert on the exact callback arg shape

| Avoid | Prefer |
|---|---|
| `expect(fn).toHaveBeenCalled()` | `expect(fn).toHaveBeenCalledTimes(N)` |
| `expect(fn).toHaveBeenCalledTimes(1)` | `expect(fn).toHaveBeenCalledWith(expectedArg)` (when arg shape matters) |

But: don't over-constrain. `<button onClick={onSubmit}>` passes the
synthetic event as the first arg, which you may not care about. If the
callback shape is "the parent's concern, not this component's," document
that with a comment instead of asserting on a fragile shape.

### Cover branches, not lines

For each prop / arg / state combination that produces a different
visible behavior, write a test. Examples:

- `<ChatInput sending={false}>` vs `<ChatInput sending={true}>` →
  Send button enabled vs disabled.
- Empty array vs populated array vs null → empty state vs cards vs
  graceful handling.
- Loading vs success vs error states.

Don't write tests that touch every line "for coverage" — write tests
that prove every meaningful branch is correct.

### Mock external dependencies

A unit test must not hit the network. A unit test should not depend on
real timers (use `vi.useFakeTimers()`). A unit test that mounts a
component with a `useEffect` doing `fetch(...)` must mock the fetch.

Standard pattern with vitest:

```js
import { vi } from 'vitest';

vi.mock('../lib/api.js', () => ({
  fetchSomething: vi.fn(async () => ({ ok: true, items: [] })),
}));

import { fetchSomething } from '../lib/api.js';

beforeEach(() => {
  fetchSomething.mockReset();
  fetchSomething.mockImplementation(async () => ({ ok: true, items: [] }));
});
```

### Test names that read as specifications

Pattern: `[subject] [verb] when [condition]`.

Good:
- `Send button is disabled when value is empty`
- `clicking the back arrow navigates to the previous chapter`
- `submits the trimmed value on Enter without Shift`

Bad:
- `it works`
- `test 1`
- `should render`

## What "strict" looks like in practice

Compare these two tests for the same behavior:

```js
// Permissive — passes even if the button is gone, the wrong button
// fires, or the count is wrong.
it('shows save button', async () => {
  await waitFor(() => {
    expect(screen.queryAllByText(/Save/i).length).toBeGreaterThan(0);
  });
});

// Strict — fails if the button is missing, has the wrong name, isn't
// actually a button, or there's more than one.
it('renders exactly one Save Bookmark button', () => {
  expect(screen.getByRole('button', { name: 'Save Bookmark' })).toBeInTheDocument();
});

// Strict — also asserts the click wiring fires onSave with the trimmed
// value.
it('clicking Save Bookmark calls onSave with trimmed input value', async () => {
  const user = userEvent.setup();
  const onSave = vi.fn();
  render(<BookmarkNoteModal onSave={onSave} onClose={() => {}} />);
  await user.type(screen.getByPlaceholderText(/Add a note/i), '  trimmed  ');
  await user.click(screen.getByRole('button', { name: 'Save Bookmark' }));
  expect(onSave).toHaveBeenCalledTimes(1);
  expect(onSave).toHaveBeenCalledWith('trimmed');
});
```

When a user / agent suggests the permissive form, push back: "That test
will pass even if the button is gone — let's tighten it." Show the
strict version.
