---
name: google-style-py
description: Auto-attaches when Python files are touched. Injects the Google Python Style rules — naming, formatting, imports, type hints, docstrings, exception handling — so generated and edited code is born-compliant. Cites RUBRIC.yaml IDs and pyguide section anchors. Use this whenever writing or modifying .py code.
paths: ["**/*.py", "**/*.pyi"]
---

# Google Python style — applied rules

You are editing Python code. Every line you write must satisfy the
[Google Python Style Guide](https://google.github.io/styleguide/pyguide.html).
The full extract is in `docs/standards/google-python-style.md`. The
machine-checkable subset is in `rubric/RUBRIC.yaml` (rules `g-py-*`).

## Required patterns (must do)

- **Type hints on every public function/method** (parameter and return types). ([g-py-006](../../rubric/RUBRIC.yaml), [pyguide#21931](https://google.github.io/styleguide/pyguide.html#21931-type-annotations))
- **Pass `mypy --strict`** with the project's `mypy.google.ini`. ([g-py-007](../../rubric/RUBRIC.yaml))
- **Docstrings on every public module / class / function / method**, in Google docstring style (Args, Returns, Raises sections). ([g-py-005](../../rubric/RUBRIC.yaml))
- **Imports grouped**: stdlib → third-party → local. One import per line. Absolute imports preferred. ([g-py-004](../../rubric/RUBRIC.yaml))
- **`if x is None:`** for None checks, never `if not x:` when None vs falsy matters. ([g-py-008](../../rubric/RUBRIC.yaml))
- **Specific exceptions** in `except` clauses; chain via `raise X from e` to preserve the cause. ([g-py-003](../../rubric/RUBRIC.yaml))
- **Context managers (`with`)** for resource lifecycles (files, locks, connections).
- **`logging`** for diagnostic output, not `print()`. ([g-py-009](../../rubric/RUBRIC.yaml))
- **f-strings** for string formatting; avoid `%` and `.format` for new code.

## Forbidden patterns (must not do)

- **Mutable default arguments**: `def f(x=[])` — use `def f(x=None): x = x or []`. ([g-py-002](../../rubric/RUBRIC.yaml), B006)
- **Bare `except:`** or `except Exception:` without re-raise. ([g-py-003](../../rubric/RUBRIC.yaml))
- **`from foo import *`** in production code.
- **`global`** for state mutation across functions; encapsulate in a class or pass explicitly.
- **`eval` / `exec`** on untrusted input.
- **Catching and silently dropping exceptions** without logging.

## Naming (g-py-001)

| Kind | Style | Example |
|---|---|---|
| Module / package | `lowercase_with_underscores` | `my_module.py` |
| Class | `CapWords` | `class HttpRequest:` |
| Function / method / variable | `snake_case` | `def fetch_user(user_id):` |
| Module-level constant | `UPPER_SNAKE_CASE` | `MAX_OVERFLOW = 100` |
| Type variable | `CapWords` ending in `T` (or single uppercase) | `UserT`, `T` |
| "Private" by convention | leading `_` | `def _internal_helper():` |

Acronyms: `HttpRequest`, `XmlParser`, not `HTTPRequest` or `XMLParser`.

## Formatting (g-py-010, delegated to pyink/black with Google config)

- 4-space indent, 80-col wrap (per Google pyguide §3.2 — note this is stricter than the 79 of PEP 8 in some places and 100 elsewhere; we use 80 as the canonical Google bar).
- Two blank lines between top-level definitions; one blank line between methods.
- Double quotes for strings; triple double quotes for docstrings.
- Trailing comma in multi-line collections.

## Docstrings (Google style)

```python
def fetch_user(user_id: int, *, force_refresh: bool = False) -> User:
    """Look up a user by ID, optionally bypassing the cache.

    Args:
      user_id: Stable numeric identifier of the user.
      force_refresh: If True, skip cache and re-read from the source.

    Returns:
      The User domain object.

    Raises:
      UserNotFoundError: When no user matches user_id.
    """
```

## Type hints

- Annotate every parameter and return type on public APIs.
- Use `Optional[T]` (or `T | None` on 3.10+) for nullable values.
- Use `Sequence[T]`, `Mapping[K, V]`, `Iterable[T]` for read-only inputs; `list`, `dict`, `set` only when mutation is intended and exposed.
- `TypedDict` for structured dicts; `Protocol` for structural typing; `dataclass` for value objects.
- `from __future__ import annotations` at the top of every module to keep annotations lazy.

## Tests

- Test files: `test_*.py` or `*_test.py` under `tests/`.
- Use `pytest`. Tests must run with `pytest -q` from project root.
- Each test asserts a single behavior. Test names: `test_<subject>_<verb>_<condition>`.
- Mock external I/O (`pytest.monkeypatch` or `unittest.mock`); never hit the network in unit tests.

## When you write or edit code

1. **Cite rule IDs** in commit message bodies on non-trivial style choices.
2. **If you must violate** a rule, add a `# noqa: <code>  # reason: …` comment on the offending line.
3. **Run `bash rubric/runner.sh --diff --md`** before declaring done.
4. **Never bundle** a reformat with a logic change — split into pure-format CL first.
