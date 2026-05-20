---
name: local-llm
description: Local-LLM fallback for cheap-operation routing — Ollama, llama.cpp, LM Studio. Targets 30–50% baseline daily token-cost reduction by routing triage, affiliation parsing, and issue-label filtering to a local backend.
trigger: cheap-operation
---

# Local-LLM Skill

Per architecture §16 X-4: routes "cheap" operations — L-3 triage,
L-6 affiliation parsing, L-16 issue-label filtering — to a local
inference backend (Ollama / llama.cpp / LM Studio) when available,
falling back to the remote API when not. Reports a daily token-cost
reduction estimate.

## Supported backends

- `ollama` — http://localhost:11434
- `llama.cpp` — llama-server on a configurable port
- `lm-studio` — local OpenAI-compatible server

## Routed operations

- `triage` (L-3) — coarse pattern filter on PR title/body
- `affiliation-parsing` (L-6) — extract org from reviewer email/handle
- `issue-label-filtering` (L-16) — drop issues missing security label

Everything else continues to use the remote API.

## Cost report

`cost-report.sh` reads `.claude-tdd-pro/local-llm/stats.json` and
emits `reduction_pct=<n> target_band=30-50 tokens_avoided=<n>`. The
target band is the architecture-defined 30–50% reduction goal for
the routed operations.
