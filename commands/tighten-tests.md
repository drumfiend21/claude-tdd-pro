---
name: tighten-tests
description: Audit a test file against the strict-assertions bar. Replaces queryAllByText permissive checks with getByRole + exact counts + jest-dom matchers. Reports what got tightened.
---

Audit and tighten the tests in: $ARGUMENTS (or, if no path given, ask
the user which file).

Load the `strict-component-tests` skill.

For each test in the file, identify and replace permissive patterns:

| Found | Replace with |
|---|---|
| `queryAllByText(/x/).length > 0` | `getByRole('...', { name: /x/ })` |
| `getByText('x')` (when role is known) | `getByRole('...', { name: 'x' })` |
| `expect(el.textContent).toContain('x')` | `expect(el).toHaveTextContent(/x/)` |
| `expect(el.disabled).toBe(true)` | `expect(el).toBeDisabled()` |
| Manual class/attr inspection | `toHaveClass`, `toHaveAttribute` |
| `fireEvent.click(...)` | `await user.click(...)` (with userEvent.setup()) |
| `expect(fn).toHaveBeenCalled()` | `expect(fn).toHaveBeenCalledTimes(N)` (or `toHaveBeenCalledWith(...)` if arg shape matters) |
| Multiple-element matches via `>= 1` (when uniqueness is expected) | `toHaveLength(N)` |

Run the suite after each change to confirm no regressions.

After the pass, report:
- N assertions tightened
- M tests that now use jest-dom matchers
- Any tests that couldn't be tightened (with reason — usually
  "duplicates are inherent in this view")
- Final test count, all green
