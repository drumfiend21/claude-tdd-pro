---
name: flow-guard
description: PreToolUse soft warning when context thrash detected (rapid back-and-forth tool switching). Per architecture section 16 Q-5.
trigger: PreToolUse
---

# Flow Guard

Emits a soft warning (non-blocking) when the recent tool-use trace
shows context thrash — many rapid tool switches in a short window.
Goal: nudge sustained focus blocks instead of context-thrashing.

When triggered:
- Counts events in `.claude-tdd-pro/flow-guard/recent.jsonl` within
  `--window-min` (default 5).
- Warns when count exceeds `--threshold` (default 5).
- Cooldown via `--cooldown-min` (default 10) prevents double warning.
- Logs warning event to friction-tracker.

Honors space/config.yaml: skips warning when efficiency_and_flow
dimension disabled. Always exits 0 (soft warning, never blocks).
