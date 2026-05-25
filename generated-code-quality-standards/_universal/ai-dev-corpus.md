# AI Software Development Best Practices Corpus

**Status:** PRIMARY RULESET — highest priority. Supersedes any conflicting guidance elsewhere in `generated-code-quality-standards/` for *how* to architect, plan, and develop software on this project. Code-quality rules in sibling namespaces (google, react, node, owasp, etc.) define *what* the final code must look like; this corpus defines *how the work is done*.

**Read this first**, every session, before any code or spec is written.

**Source attribution.** Compiled from:
- Andrej Karpathy on the LLM coding revolution (X posts, public talks)
- Elon Musk's 5-step algorithm (Tim Dodd / Everyday Astronaut interview; Corporate Rebels analysis)
- Anthropic, *Claude Code best practices* (docs.claude.com)
- Anthropic, *Building effective agents* (anthropic.com/engineering)
- Dario Amodei, *Machines of Loving Grace* (darioamodei.com)
- Cross-referenced Medium article, X posts, official docs

Apply ruthlessly and iterate. Prune like CLAUDE.md.

---

## Overarching principles

- **Musk's algorithm + Karpathy's English shift + Anthropic's verification/context discipline = unbeatable combo.**
- **Human + AI symbiosis:** agent stamina + human creativity / review.
- **Continuous adaptation:** model capabilities improve fast — experiment weekly.
- **Simplicity first. Transparency always. Verification mandatory.**

---

## 1. Mindset & Workflow Revolution (Karpathy + Broader AI Shift)

- **English-First Programming.** Move from ~80% manual code to ~80% natural-language "code actions" / prompts once LLMs cross the "threshold of coherence." Describe high-level goals, architectures, features, or fixes in plain English; let agents implement, test, and iterate.
- **Human Role.** High-level direction, creativity, final review, and oversight. LLMs eat drudgery (repetitive tasks, knowledge gaps, prototyping "not worth it" ideas).
- **Practical Setup.** Multiple Claude / Grok / agent sessions in terminal tabs (left) + IDE (right) for hawk-eyed reviews.
- **Productivity Reality.** Not just speed — scope explosion. More prototypes, faster PR merges (60%+), ~3.6 hrs/week saved, more fun. Global stats: 29% of new U.S. code is generative AI (up from 5% in 2022); 91% of orgs use AI tools.
- **Agent Personalities.** Claude-like = senior dev (thorough, educational, high-quality); Codex-like = fast scripting intern (efficient tokens). Choose based on task.
- **Review Discipline.** AI code has ~1.7× more defects without review. Always IDE-babysit; "no IDE" or pure swarms ignores production reality. Perception gap exists (devs feel 20% faster but may take 19% longer initially).
- **Risk Awareness.** Skill atrophy (weaker manual coding/writing; reading holds), "Slopacolypse" (GitHub AI junk flood), uneven adoption. Maintain human judgment.

**Actionable tip:** Treat every coding session as "mostly programming in English now." Start prompts with high-level intent + verification criteria.

---

## 2. Musk's 5-Step Algorithm

**Apply ruthlessly to code, prompts, pipelines, requirements.** Follow in exact order — never skip or reverse. Adapt to dev processes, feature specs, codebases, build pipelines, or even your own prompts.

1. **Question Every Requirement.** Attach a specific person's name (never "legal dept" or "best practice"). Question even smart people's (or your own) requirements. Make them less dumb.
2. **Delete Any Part / Process You Can.** Ruthlessly subtract. Delete more than feels comfortable. If you don't add back ≥10%, you didn't delete enough. (Code bloat, unused abstractions, redundant steps.)
3. **Simplify & Optimize.** Only after deletion. Never optimize something that shouldn't exist.
4. **Accelerate Cycle Time.** Speed up what remains — only now.
5. **Automate Last.** Automate after steps 1–4 and bug-shaking. Early automation of bad processes is the biggest factory (and dev) mistake.

**Dev applications.** Apply to requirements docs, ML pipelines, legacy code, CI/CD, PR processes, even agent instructions ("delete unnecessary steps from this plan"). Managers: technical leads must code 20%+ of time. Solve problems via skip-level talks (talk directly to engineers, not just managers).

---

## 3. Core Claude / Grok / LLM Interaction Practices

### Context is the #1 constraint

- Performance degrades fast as context fills (messages + files + outputs). Track continuously.
- **Aggressive management.** `/clear` between unrelated tasks; `/compact`; Esc+Esc or `/rewind` for checkpoints / summaries; `/btw` for quick non-persistent questions. Use subagents for research to keep main context clean. Auto-compaction preserves key decisions / code. Customize in CLAUDE.md.

### Verification = highest leverage

- Always give tests, screenshots, expected outputs, error logs, success criteria so the LLM can self-verify and iterate.
- **Examples.** Paste screenshot + "implement this design, screenshot result, compare & fix differences." Or "write `validateEmail` + run these exact test cases + fix until they pass."
- **UI changes.** Use browser testing or visual comparison. Never ship unverified code.

### Prompting excellence

- **Be specific.** Scope (files / scenarios / tests), reference `@files`, existing patterns, git history, symptoms + "fixed" definition.
- **Rich context.** `@file`, paste images / logs, pipe data (`cat error.log | claude`), URLs (allowlist with `/permissions`).
- **Vague can be useful for exploration**; otherwise, precision reduces corrections.

### Structured workflow (Explore → Plan → Implement → Commit)

1. **Explore** (plan mode). Read / understand without changes.
2. **Plan.** Ask for detailed implementation plan; edit in editor (Ctrl+G).
3. **Implement.** Code + tests + fixes against plan.
4. **Commit / PR.** Descriptive message + open PR. Skip planning for tiny / clear changes (typo, rename, log line).

### Persistent knowledge (CLAUDE.md & extensions)

- Run `/init` for starter based on project. Keep concise / human-readable.
- **Include.** Code style diffs, testing prefs, Bash commands LLM can't guess, env quirks, gotchas, repo etiquette, architectural decisions.
- **Exclude.** Self-evident, inferable-from-code, long tutorials, frequently changing info. Prune regularly ("Would removing this cause mistakes?").
- **Imports.** `@path/to/other.md`. Locations: `~/.claude/CLAUDE.md` (global), `./CLAUDE.md` (shared), `./CLAUDE.local.md` (personal).
- **Extensions.** Skills (`SKILL.md`), hooks (deterministic scripts), subagents (isolated context), MCP servers, plugins, auto mode / sandbox / allowlists for fewer interruptions.

### Scaling & parallelism

- Multiple sessions: writer / reviewer pattern, parallel experiments, fan-out migrations.
- Non-interactive: `claude -p "prompt"` for CI / scripts; `--output-format json` or `stream-json`.
- Subagents, skills, and agent teams for complex / coordinated work.

---

## 4. Building Effective Agents & Workflows (Anthropic Engineering Guide)

**Start simple.** Add complexity only when it measurably improves outcomes. Single augmented LLM calls + retrieval / in-context examples suffice for most tasks.

**Augmented LLM (foundational building block).** LLM + retrieval + tools + memory. Tailor interface; use MCP for third-party integration.

### Workflow patterns (predictable, code-orchestrated)

- **Prompt Chaining.** Sequential LLM calls + gates / checks. E.g., outline → validate → write.
- **Routing.** Classify input → specialized prompt / model / path. E.g., easy vs hard queries → different models.
- **Parallelization.** Sectioning (independent subtasks in parallel) or Voting (multiple runs + aggregate).
- **Orchestrator-Workers.** Central LLM dynamically delegates / synthesizes (great for unpredictable multi-file changes).
- **Evaluator-Optimizer.** Generator + critic in loop for refinement (e.g., translation, complex search).

### Agents (dynamic, LLM-directed)

LLM plans / executes autonomously with tools + environmental feedback (ground truth at each step). Pause for human input at checkpoints or blockers. Use for open-ended tasks (SWE-bench style coding, computer use).

- **Risks.** Higher cost, error compounding → sandbox testing + guardrails + stopping conditions.
- **Examples.** Coding agents (test-driven iteration), customer support (conversation + actions).

### Tool engineering (critical ACI — Agent-Computer Interface)

Treat tool definitions like excellent docstrings.

- Choose formats LLM writes easily (markdown diffs > complex JSON escaping).
- **Poka-yoke** (make mistakes hard, e.g., absolute paths).
- Include examples, edge cases, clear boundaries. Test extensively; iterate based on model mistakes.

**Evaluation.** Measure performance; iterate. Human review remains essential for alignment / broader context.

---

## 5. Risks, Mitigations & Vision

- **Atrophy & slop.** Review rigorously; maintain manual skills where needed; prune AI junk.
- **Perception gap & trust.** Only ~33% fully trust generated code. Use verification + metrics.
- **Adoption.** 90% Fortune 100 use AI; juniors / full-stack lead usage. No monopoly (Cursor / ChatGPT / Claude top tools).
- **Positive vision (Amodei).** Powerful AI as "virtual colleague" for autonomous engineering, biology / health, mental health, economic development, governance, and work / meaning. AI enables country-scale genius in a datacenter. Focus on high-return intelligence tasks; design for parallelism and human meaning beyond economics. Shift role to direction, values, and oversight.

---

## How this corpus applies to claude-tdd-pro CL work

This corpus does not replace any per-CL discipline already encoded in `CLAUDE.md` (Step 0 architecture extraction, Step 0.5 fidelity gate, Step 2 audit, Step 3 verify, Step 4 commit). It overlays them with mindset and methodology:

- **§1 English-First.** Spec names and commit bodies describe behavior in plain language; ID-only spec names are banned (already encoded in Step 1 "no opaque IDs").
- **§2 Musk's algorithm.** Before adding any new feature, contract, or substrate script: question the requirement, attempt to delete an existing one, simplify what survives, then build. Applied: CL-274's §25 amendment introduced new substrate (the auditor) only after the §2.6 drift case proved discipline-alone insufficient — and the discipline (Step 0.5) was kept lightweight per "delete more than feels comfortable."
- **§3 Verification = highest leverage.** Already encoded as `bash evals/runner.sh` Step 3 gate. The architecture's "always 100% green active suite" invariant IS the verification practice this corpus codifies.
- **§4 Workflow patterns.** Prompt chaining = the per-CL Step 0 → 4 loop. Orchestrator-workers = `tdd-pro-cl-workflow` skill dispatching subchecks. Evaluator-optimizer = the audit + fix loop.
- **§5 Risks & mitigations.** "Pending-spec invented vocabulary" (CLAUDE.md drift mechanism #6) is the project-specific instance of "slop" risk; §25 §2.25 fidelity gate is the project-specific mitigation.

When new architecture work emerges and any rule below conflicts with another guideline in this directory, this corpus wins. Other directories define what code should look like; this one defines how the work is done.

---

*This corpus is living — prune, test, and evolve it like CLAUDE.md. Use it to bootstrap projects, train teams, or prompt agents directly. The revolution is here: program in English, verify relentlessly, delete ruthlessly, and let agents grind.*
