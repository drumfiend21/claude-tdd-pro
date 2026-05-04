"""Reference conftest.py for pytest projects.

Mirrors the JS test-setup discipline:
  - Strict assertion helpers via plain pytest (no jest-dom equivalent
    needed; pytest's built-in assert rewriting is rich)
  - Cleanup is automatic in pytest (each test function gets a fresh
    fixture scope by default)
  - Autouse fixtures for common setup (e.g., resetting global
    state, providing a tmp directory)

Drop in the project root (or `tests/` directory).
"""

from __future__ import annotations

import os
from pathlib import Path

import pytest


@pytest.fixture(autouse=True)
def _isolate_environment(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """Run each test in an isolated environment.

    Isolates:
      - Working directory (each test gets its own tmp_path).
      - Environment variables (monkeypatch reverts on teardown).
      - Any global module state your project might leak.
    """
    monkeypatch.chdir(tmp_path)
    # Add project-specific resets here.


@pytest.fixture
def fixtures_dir() -> Path:
    """Return the tests/fixtures directory."""
    return Path(__file__).parent / "fixtures"
