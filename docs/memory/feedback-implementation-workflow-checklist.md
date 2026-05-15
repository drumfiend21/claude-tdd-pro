---
name: Implementation workflow checklist (per-CL)
description: User-validated workflow optimizations to apply on every CL during the architecture-v1.9 implementation phase. Reference BEFORE writing any new substrate function or code edit. No artifact changes; pure behavioral discipline that preserves all CLAUDE.md audit guardrails.
type: feedback
---

**Reference this list before any new substrate Write/Edit during architecture implementation.**

**Why:** User-directed in 2026-05-15 session after observing repeated iteration cycles caused by the same gotchas across CL-66 through CL-90. Every item here is a friction this implementer hit 2+ times in one session. Adoption cost is zero — these are behavioral commitments, not artifact changes. Preserves all CLAUDE.md audit discipline (Step 0 architecture quote, self-audit, active-suite-green, flag disclosure, verbatim path tracing, 1 feature per CL).

**How to apply:** at the start of every CL, do pre-flight (architecture quote + spec survey) THEN scan this list. Before any substrate `Write` or `Edit`, mentally check items 1, 9, 10. Before iterating against staged specs, check items 2, 5. When committing, apply item 4. When discovering drift, apply item 6.

## Tier 1 — Substrate-writing patterns

**1. Substrate-writing checklist (apply before every Write/Edit of a substrate file):**
- No apostrophes inside `ruby -e '...'` or `node -e '...'` blocks ("isn't" → "is not"; "those orgs'" → "each named org"). Bash single-quote heredoc breaks.
- No em-dashes / smart quotes / non-ASCII inside heredoc bodies.
- `node -e '...' -- "$@"` — the `--` is mandatory or node claims user flags as its own.
- JSON output that specs grep with `"key":"value"` patterns must be COMPACT (no `, null, 2`). Pretty-print breaks `"signature":"sha256:..."` style assertions.
- macOS portability: use `pwd` not `pwd -P` when paths must align with `find` output (macOS `/tmp → /private/tmp` symlink); use `perl` not gawk's 3-arg `match($0, regex, array)`; use `perl alarm` or Ruby `Timeout` not `gtimeout` (macOS lacks it).
- When parsing source-folder YAML, EXPECT Psych to fail on flow-style maps containing bare URLs or colon-bearing scalars → write the regex fallback in the SAME pass, not as a CL-N+1 fix. Pattern: `begin; YAML.load_file(p); rescue Psych::SyntaxError; <regex extract>; end`.
- For `--dry-run` flag: check it BEFORE the required-args validation (otherwise dry-run can't be tested without satisfying args).
- For `--help` flag: emit Usage to **stdout** (specs pipe `bash cmd --help 2>/dev/null | grep`).
- When extending an existing multi-feature substrate file (`commands/doctor.sh`, `profiles/active.sh`, `commands/audit-pack.sh`), `Read` the section being extended FIRST. NEVER `Write` an existing substrate file unless replacing wholesale and all dependent specs are accounted for.

**9. Regex fallback in first pass.** Any substrate that parses YAML from spec setups MUST handle Psych failures from day one. The pending spec format is what it is; assume the worst.

**10. Read-before-Edit on existing files.** Adoption of #10 is non-negotiable: when extending an existing substrate file, Read the relevant section first to avoid wholesale-rewrite-by-accident.

## Tier 2 — Process discipline

**2. Spec sanity-trace before substrate.** For each new feature, after pre-flight read of all 10 specs: mentally trace each assertion's stdout/stderr flow. Catch `2>file && grep file`-style traps and `grep -q ... 1>&2` (quiet grep produces no output to redirect) BEFORE building substrate. If a spec assertion is internally unsatisfiable, decide: (a) make substrate emit the substring on the OTHER stream so assertion still passes, or (b) document the unsatisfiable assertion in commit body. Don't modify the spec to "fix" what works as-is.

**4. Commit body templating — terse vs. full audit:**
- **Full audit body** (when CL creates a NEW architecture-named path or revives a parked feature): architecture quote + per-folder fidelity mapping + non-shallow check + test-affordance flag disclosure + counts + § progress.
- **Terse body** (when CL only EXTENDS an existing path or adds stubs): architecture quote + counts + § progress + co-author. ~6 lines.
- Audit's purpose is to surface drift; if no new path is invented, no drift to audit.

**5. Pre-flight survey is non-negotiable first action of every CL.** Three actions in one response:
1. Quote `§16 <feature-id>` line from architecture (1 grep)
2. List the 10 spec filenames (1 ls)
3. Read all 10 specs in parallel via batched Read calls
If pre-flight reveals invented script paths, wrong-domain syntax (ESLint vs rubric), or missing dependencies → triage immediately; don't write substrate first.

**6. Drift-triage decision tree (3 outcomes, classify immediately):**
- **Park**: specs assume a runtime/dependency we don't have (e.g., E-11 needed eslint), or test wrong-domain topic (e.g., F-4 was wrongly named). → `git mv` to `evals/pending/_misfiled/<feature>-<reason>/`, write README, commit as chore CL.
- **Path-rewrite only**: spec topic correct but invokes invented path (`rule-engine/cli.sh`, `rubric/aggregator.sh`, `profiles/resolve.sh`). → small node script does mass-rename to architecture-named path, then build substrate as normal.
- **Path + content fix**: rare — only when invocation fundamentally wrong AND content needs adjustment for substrate to be testable.

## Tier 3 — Tool-call habits

**3. Multi-Edit batching.** When a file needs N edits, send all N `Edit` calls in a SINGLE response. The harness preserves Read state within a response. Sequential Edits across responses force re-Read each time.

**7. Cache bash one-liners.** Stick to a small set of memorized invocations:
- Stage + run: `for f in evals/pending/.../*.json; do cp "$f" "evals/specs/cl<NN>-$(basename $f)"; done && bash evals/runner.sh > /tmp/runner-out.txt 2>&1; until grep -q Results /tmp/runner-out.txt; do sleep 1; done; grep -E '^Results|^  - ' /tmp/runner-out.txt`
- Verbose-one: `bash evals/runner.sh -v cl<NN>-<spec-prefix>`
- Promote: `rm evals/specs/cl<NN>-*.json && for f in evals/pending/.../*.json; do git mv "$f" "evals/specs/$(basename "$f")"; done && rmdir evals/pending/.../<feature>`
- Pre-flight survey: `for f in evals/pending/<phase>/<feature>/*.json; do echo "==$(basename $f)=="; node -e "const j=JSON.parse(require('fs').readFileSync('$f','utf8'));console.log(j.command);console.log(JSON.stringify(j.expect));"; done`

**8. Background runner: do other work while waiting.** When `bash evals/runner.sh` auto-backgrounds, don't sit and poll. Read the next spec, write the next substrate edit, draft the commit body. Task-notification arrives when ready.

## Tier 4 — One-shot

**11. Run existing hygiene preprocessor in pre-flight.** As part of pre-flight (item 5), if any spec under `evals/pending/` has been touched since last `node scripts/lint-pending-specs.js` invocation, run it. Idempotent. Already committed in CL-83. Catches printf-leading-dash and em-dash patterns.

**12. Commit spec patches in the SAME CL that introduces them.** When you patch an `evals/pending/...json` spec to fix a stream-redirect, hardcoded path, or content bug — and then `git mv` the patched file into `evals/specs/` — make sure the patched form is what gets committed. The active suite will pass on the working tree even when HEAD's blob is unpatched (because subsequent runs use the patched WT). To verify before commit: `git stash push <patched file> && bash evals/runner.sh -v <spec-name>`; if HEAD's form fails the same spec that WT's form passes, the patch is unstaged and must be `git add`'d. **Why:** discovered in CL-100 self-audit — CL-93 + CL-94 + CL-97 each shipped 10/1/2 spec patches that were applied to WT but never committed; HEAD's form would have failed for any fresh checkout. **How to apply:** before every `git commit`, scan `git status` for `M evals/specs/*.json` entries that were not in your add list and stage them.

## What this preserves (do NOT relax these)

- Step 0 pre-flight read of `docs/architecture-v1.9.md` per CL
- Self-audit findings in commit body (per-folder mapping when applicable)
- Active suite must be green at promotion
- Test-affordance flag disclosure
- Every substrate path traces verbatim to architecture text
- 1 feature per CL discipline
- Never modify `docs/architecture-v1.9.md` or `evals/runner.sh` without user direction
- Modifications to `evals/pending/` spec contents only when spec is unsatisfiable as written, and disclosed in commit body
