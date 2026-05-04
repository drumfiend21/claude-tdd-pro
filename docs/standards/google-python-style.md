# Google Python Style Guide — Actionable Rules

Source: https://google.github.io/styleguide/pyguide.html

This is the condensed, enforceable subset of the Google Python Style Guide
that the `claude-tdd-pro` skills reference. The original is the canonical
authority — this document only restates rules in a format the model can
apply directly.

## Naming

- Modules, functions, methods, variables: `lower_with_under` (#s3.16.2). e.g. `parse_token()`.
- Classes & exceptions: `CapWords`; exception names end in `Error` (#s3.16.2, s2.4). e.g. `class TokenError(Exception):`.
- Constants (module/class level): `CAPS_WITH_UNDER` (#s3.16.4). e.g. `MAX_RETRIES = 3`.
- Internal: single leading underscore `_helper`; avoid dunders `__name` outside protocol use (#s3.16.2).
- Allowed single-letter names: `i, j, k` (loops), `e` (exception), `f` (file). Otherwise no (#s3.16.1).
- Module files: `lower_with_under.py`; dashes forbidden (#s3.16.3).
- Don't encode type in name (`id_to_name_dict`) (#s3.16.1).

## Formatting

- Line length: max **80 chars** (#s3.2). Exceptions: long imports, URLs, long literals.
- Indent: **4 spaces, never tabs** (#s3.4). Continuation: aligned or 4-space hanging.
- Quotes: pick `'` or `"` per file and stay consistent; docstrings/multi-line use `"""` (#s3.10).
- Blank lines: **2** between top-level defs, **1** between methods, none right after `def` (#s3.5).
- Trailing comma only when closing bracket is on its own line (#s3.4.1).
- No unnecessary parens (`return foo`, not `return (foo)`) (#s3.3).
- Whitespace: no spaces inside `()[]{}`, no space before `,;:`, space after; no spaces around `=` for kwargs *unless* annotated (#s3.6, s3.19.4).
- One statement per line; never `if/else` or `try/except` on one line (#s3.14).
- No semicolons (#s3.1). No backslash continuation; use implicit paren continuation (#s3.2).
- Shebang on executables: `#!/usr/bin/env python3` (#s3.7).

## Imports

- `import x` for packages/modules; `from pkg import module` for modules within packages (#s2.2.4).
- Always **absolute** imports (#s2.2.4).
- **No wildcard imports** (`from x import *`) (#s2.2).
- Aliases only for standard abbreviations (`numpy as np`) or name conflicts (#s2.2.4).
- Group order, lex-sorted within group (#s3.13):
  1. `from __future__ ...`
  2. stdlib
  3. third-party
  4. local
- `typing` / `collections.abc` may use `from typing import Any, Optional, cast` on one line (#s3.19.12).

## Type Hints

- Required for public APIs and any error-prone or hard-to-read code (#s2.21.4, s3.19.1).
- Annotate args and return types; skip `self`, `cls`, and `__init__ -> None` (#s3.19.1).
- Use lowercase built-in generics: `list[int]`, `dict[str, int]`, `tuple[str, ...]` (#s3.19.12).
- Prefer abstract types (`Sequence`, `Mapping`) for inputs (#s3.19.12).
- Unions: `str | None` (3.10+) or `Optional[str]`; never implicit `x: str = None` (#s3.19.5).
- Always parameterize generics — no bare `Sequence` (#s3.19.15).
- Type aliases: CapWords; `_` prefix if private (#s3.19.6). e.g. `Vector: TypeAlias = list[float]`.
- Long signatures: one param per line + trailing comma; return type on last line or its own line (#s3.19.2).
- Forward refs: `from __future__ import annotations` or string literal `'ClassName'` (#s3.19.3).
- Space around `=` when annotated: `def f(x: int = 0):` (#s3.19.4).

## Docstrings (Google style)

- Triple double-quotes `"""`; one-line summary ending with `.`/`?`/`!`, blank line, then body (#s3.8.1).
- **Modules** (#s3.8.2): required; include `Typical usage example:` block.
- **Classes** (#s3.8.4): required; `Attributes:` section for public attrs.
- **Functions/methods** (#s3.8.3): required if public, nontrivial, or non-obvious.
- Section names, in order, omit if N/A (#s3.8.3):
  - `Args:` — `name: description` (with type if not annotated)
  - `Returns:` (or `Yields:` for generators) — type + description
  - `Raises:` — exceptions that are part of the interface
- 2- or 4-space hanging indent for multi-line entries (#s3.8.3).
- `@override` methods may omit docstring unless behavior diverges (#s3.8.3.1).
- Test modules: docstring only if extra context is needed (#s3.8.2.1).

## Required patterns

- `if x is None:` / `is not None:` for None checks (#s2.14.4).
- Implicit truthiness for sequences/strings: `if seq:` not `if len(seq):` (#s2.14.4).
- Use `with` for files, locks, sockets; `contextlib.closing` if no native support (#s3.11).
- Format strings via f-strings, `%`, or `.format()` — but logging uses `%`-style literals: `log.info('x=%s', x)` (#s3.10, s3.10.1).
- Build large strings via list + `''.join()`, not `+=` in a loop (#s3.10).
- Catch the narrowest exception class possible (#s2.4.4).
- Guard entry points: `if __name__ == '__main__':` (#s3.17).
- Lint with `pylint`; suppress narrowly: `# pylint: disable=msg-id` (#s2.1.4).
- Comprehensions: single `for`, optional single filter; otherwise use a loop (#s2.7.4).

## Forbidden patterns

- `from x import *` (#s2.2).
- Relative imports (#s2.2.4).
- Mutable default args: `def f(a=[])`, `def f(a={})`, `def f(a=time.time())` (#s2.12.4).
- Bare `except:` or unrestricted `except Exception:` without re-raise (#s2.4.4).
- `assert` for production/runtime validation — use exceptions (#s2.4.4).
- Mutable module-level globals (#s2.5.4).
- Power features: custom metaclasses, bytecode hacks, dynamic inheritance, `__del__` reliance, `sys.modules` mutation (#s2.19.4).
- `@staticmethod` — use a module-level function (#s2.17.4).
- `if x == False:` / `== True` (#s2.14.4).
- Backslash line continuation (#s3.2).
- Nested `for` clauses inside a comprehension (#s2.7.4).
- Vertical alignment of `=`, `:`, `#` across lines (#s3.6).

## Testing

- Test files: `lower_with_under.py`, typically `*_test.py` (#s3.16.3).
- Test functions: `test_<unit>_<state>`, e.g. `test_parse_token_rejects_empty` (#s3.16.2).
- `assert` is expected/required in tests; pytest-style asserts fine (#s2.4.4).
- Tests may access `_protected` members of the module under test (#s3.16.2).
