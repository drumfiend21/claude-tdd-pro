---
name: doctor
description: Verify claude-tdd-pro is wired up correctly on this machine and against this project. Smoke-tests every hook, runs the rubric runner against a known-bad fixture, runs the eval suite. Reports green / yellow / red per primitive. Read-only — no edits.
disable-model-invocation: true
---

The user wants to confirm the plugin is functioning. This is the
support-flow command: when something seems off, `/doctor` answers
"is the plugin actually working on this machine?" in under 30 seconds.

## What you do

Run all checks below in order. For each, print `✅ green`, `⚠️ yellow`,
or `❌ red` with one line of context. Do NOT modify anything.

### 1. Plugin presence

```bash
ls -la "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" \
       "${CLAUDE_PLUGIN_ROOT}/rubric/RUBRIC.yaml" \
       "${CLAUDE_PLUGIN_ROOT}/rubric/runner.sh" \
       "${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json"
```
- Green: all four exist.
- Red: anything missing — plugin not installed correctly.

### 2. Hook scripts executable

```bash
for f in "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/"*.sh \
         "${CLAUDE_PLUGIN_ROOT}/rubric/detectors/"*.sh \
         "${CLAUDE_PLUGIN_ROOT}/rubric/runner.sh"; do
  [[ -x "$f" ]] && echo "OK $f" || echo "NOT-EXEC $f"
done
```
- Green: all executable.
- Red: any not-executable.

### 3. Hook syntax

```bash
for f in "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/"*.sh \
         "${CLAUDE_PLUGIN_ROOT}/rubric/detectors/"*.sh \
         "${CLAUDE_PLUGIN_ROOT}/rubric/runner.sh"; do
  bash -n "$f" 2>&1 || echo "SYNTAX-ERR $f"
done
```
- Green: clean.
- Red: any syntax error.

### 4. Rubric runner smoke

Run against the plugin repo itself (most rules SKIP because there's
no JS/Python source — that's expected and fine):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/rubric/runner.sh" --full --md | head -10
```
- Green: emits a Markdown table with no parse errors.
- Yellow: many SKIPs (toolchain not installed) — expected on a fresh
  machine; recommend installing tools.
- Red: any "RUBRIC.yaml not found" or stack trace.

### 5. Toolchain matrix

For each tool, report installed/missing:
- `node --version` (required for ESLint, lint hook, tdd-guard)
- `python3 --version` (required for runner JSON parsing)
- `git --version` (required everywhere)
- `gh --version` (required for /pr)
- `ruff --version` (optional; required for full Python rubric)
- `mypy --version` (optional; required for g-py-007)
- `eslint --version` via npx (optional; required for full JS/TS rubric)
- `pyright --version` (optional; LSP integration)
- `typescript-language-server --version` (optional; LSP integration)

Green if required tools are present. Yellow if optional tools are
absent — print a recommended install command.

### 6. Existing eval suite

```bash
bash "${CLAUDE_PLUGIN_ROOT}/evals/runner.sh"
```
- Green: all specs pass.
- Red: any spec fails — print the failing spec name.

### 7. Project wiring (if invoked inside a project)

If `${CLAUDE_PROJECT_DIR}` is a real project (not the plugin repo
itself):
- Is there a `CLAUDE.md`? Y/N
- Is `.claude-tdd-pro/tdd-guard.disabled` present? Y/N (= guard off)
- Is `eslint.config.js` / `.eslintrc.cjs` from the Google adapter
  installed? Y/N (run `/init-guardrails` if N and the project is JS/TS)
- Is `pyproject.toml` configured with the Google ruff baseline? Y/N

## Output contract

Print one summary line at the top: `claude-tdd-pro doctor: GREEN | YELLOW | RED`.
Then the per-check details below. Total output ≤ 50 lines.

If RED, the last line is a single recommended next step (e.g.
`Re-install the plugin: rm -rf ~/.claude/plugins/claude-tdd-pro && bash <installer>`).
