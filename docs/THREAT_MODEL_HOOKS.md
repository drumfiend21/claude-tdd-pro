# Threat model — hook attack surface

Per the Musk Engineering Leadership review:
> "Hooks that run on tool use + secret scanning = attack surface.
>  Audit for command injection, etc."

This document is the formal threat-model walkthrough for the hook
surface. Complements `docs/threat-model.md` (broader scope) with
specific attack-class analysis the review requested.

## Hook attack surface inventory

The plugin installs hooks at four Claude Code lifecycle points (per
`commands/install-hooks.sh`):

| Hook | Fires on | Substrate location |
|---|---|---|
| `SessionStart` | session begin | `hooks/scripts/session-start.sh` |
| `PreToolUse` | before each tool invocation | `hooks/scripts/pre-tool-use.sh` |
| `PostToolUse` | after each tool invocation | `hooks/scripts/post-tool-use*.sh` |
| `Stop` | session end | `hooks/scripts/stop-hook.sh` |

Plus pre-commit hook via `hooks/pre-commit` (git lifecycle, not Claude).

## Attack class 1 — Command injection via tool input

**Threat:** An attacker controls content that flows into a hook's
shell context (e.g., file content that PreToolUse reads, MCP tool
output PostToolUse processes). If the hook passes that content
unquoted to `eval`, `bash -c "..."`, or string concatenation into
a command, the attacker controls arbitrary execution.

**Surface specifics:**
- `hooks/scripts/pre-tool-use.sh` reads JSON from stdin containing
  `tool_name`, `tool_input`. Both are attacker-influenced in
  adversarial sessions (e.g., compromised MCP server returning
  attacker-crafted JSON).
- Detector scripts under `rubric/detectors/` receive file paths
  via `--paths` and content via the spec command. File paths come
  from the operator's checkout; content comes from the file system.

**Existing mitigations:**
- All hook scripts set `set -uo pipefail` (catches unset-variable
  injection vectors).
- Variables are quoted as `"$VAR"` in command position (verified
  by `.shellcheckrc` SC2086 policy for the load-bearing scripts).
- The §25 fidelity gate refuses pending specs whose `command`
  field contains shell metacharacters not from a known-safe set.

**Residual risk:** Medium. Operator-supplied profile configs
(`.claude-tdd-pro/userConfig.yaml`) are parsed by `yaml.load` in
the Ruby detector path; YAML deserialization is a known attack
vector if the version doesn't restrict tag resolution.

**Mitigation roadmap (1 hour):**
1. Audit every `eval` and `bash -c` call site in `hooks/scripts/`.
   Replace with arg-array form (`bash script.sh "$arg1" "$arg2"`).
2. Add `audit-no-eval.sh` fitness function that fails CI if `eval`
   or `bash -c "$VAR"` appears in any `hooks/scripts/*.sh`.
3. Ruby YAML calls already use `YAML.safe_load` per
   `.ruby-version` 3.3.x + Psych 4 default-safe behavior; confirm
   by grep + add as a documented invariant.

## Attack class 2 — Secret-scanning false negatives

**Threat:** The plugin's secret-scanning hooks (pre-commit and any
runtime stop-hook scanners) miss a credential, allowing it to be
committed or sent to telemetry / a model.

**Surface specifics:**
- `space/telemetry-emit.sh` accepts arbitrary `--field key=value`
  pairs. If an operator's instrumentation captures a secret in a
  field (e.g., `--field token=$API_KEY`), it lands in
  `~/.claude-tdd-pro/telemetry.jsonl`.
- The Q-6 privacy posture (`share: never` default) means the
  telemetry log stays local, but the local log itself can contain
  the secret.

**Existing mitigations:**
- Q-6 privacy posture defaults to `share: never`; no upload path
  fires unless operator explicitly sets `share: <endpoint>`.
- `hooks/scripts/pii-egress-guard.sh` exists for runtime PII
  redaction.
- The pre-commit hook delegates to `gitleaks` / `trufflehog` if
  installed (operator-managed dependency, not bundled).

**Residual risk:** High for the telemetry path; Medium for commits.

**Mitigation roadmap (2 hours):**
1. Add `space/telemetry-redact.sh` that runs against
   `telemetry.jsonl` before any export, refusing entries whose
   fields match a known secret-format regex set
   (`(?i)(api[_-]?key|secret|token|password|bearer)=`).
2. Document in `docs/SECURITY.md` that operators must not pass
   secrets via `--field`; add a runtime warning in
   `space/telemetry-emit.sh` when a key matches the regex set.
3. Add `audit-telemetry-secrets.sh` fitness function that scans
   `~/.claude-tdd-pro/telemetry.jsonl` and fails if any entry
   matches.

## Attack class 3 — PreToolUse boundary bypass

**Threat:** The PreToolUse hook is the **last enforcement point**
before a tool runs. An attacker who can make the hook exit 0 (or
crash silently) bypasses every downstream guard.

**Surface specifics:**
- `hooks/scripts/pre-tool-use.sh` reads JSON, runs guards (TDD,
  file-fence, budget-impact), exits 0 to allow / 2 to block.
- Silent crash (e.g., `set -e` triggered by an unguarded command)
  may exit non-zero without emitting a blocking decision, which
  Claude Code may interpret as "no decision" → allow.

**Existing mitigations:**
- `set -uo pipefail` catches the most common silent-failure
  vectors.
- The Stop hook emits a `pre-tool-use.exit_code` event to
  telemetry per CL-after-this, allowing post-hoc audit of
  bypass-by-crash incidents.

**Residual risk:** Medium. Bypass-by-crash is detectable
post-hoc but not preventable in-flight.

**Mitigation roadmap (3 hours):**
1. Wrap every hook script in an explicit `trap` that emits a
   `hook.crash` telemetry event with the failing line number
   before exiting non-zero.
2. Add `audit-hook-trap.sh` fitness function that verifies every
   `hooks/scripts/*.sh` declares a trap on EXIT / ERR.
3. Add CI assertion that a deliberately-crashed hook is logged
   to telemetry within 100ms.

## Attack class 4 — Symlink / cache state drift

**Threat:** The plugin's caching layer (`~/.cache/claude-tdd-pro/`
+ symlinks under `~/.claude-tdd-pro/`) can be attacker-controlled
on a multi-user host. Cache poisoning makes a failed spec appear
to pass.

**Surface specifics:**
- `lib/runner-cache.js` writes content-addressed markers keyed on
  `sha256(spec.command + tree_sha + expect)`.
- The cache marker is a single byte (`ok`); the runner trusts the
  file's existence as proof of prior-pass.

**Existing mitigations:**
- The tree-sha component ties cache entries to the substrate
  state; modifying any file in the substrate invalidates the key.
- Multi-user hosts that share `$HOME` are out of the supported
  scope.

**Residual risk:** Low on single-user hosts; Medium on shared
hosts.

**Mitigation roadmap (1 hour):**
1. Sign cache markers with HMAC keyed on a per-install random
   token stored in `$HOME/.claude-tdd-pro/.cache-key`.
2. Add `audit-cache-integrity.sh` fitness function that walks the
   cache, verifies HMAC, rebuilds on mismatch.

## Attack class 5 — Hook escape via the new `escape-hatch` command

**Threat:** The escape hatch (added per Musk recommendation) lets
senior engineers bypass guards in production fires. The bypass
itself becomes the attack vector if an attacker can invoke it.

**Surface specifics:**
- `commands/escape-hatch.sh` requires `--justification "<text>"`
  and emits a mandatory `/remember` log entry.
- The justification text is operator-supplied and trusted at
  log time (not at action time).

**Existing mitigations:**
- The escape hatch logs to an audit-chain (`audit/escape-hatch-log.jsonl`)
  that is append-only and signed with HMAC.
- The hatch refuses to operate without an operator-typed
  confirmation (cannot be invoked from a script alone).

**Residual risk:** Low. The escape-hatch surface is intentionally
narrow.

## Audit cadence

Per `docs/SLO.md`: this threat model is re-reviewed quarterly.
Findings from real production incidents (when they happen)
supersede the proactive analysis above.

## Cross-references

- `docs/threat-model.md` — broader system threat model
- `SECURITY.md` — operator-facing security summary
- `commands/escape-hatch.sh` — controlled bypass with audit
- `docs/FITNESS_FUNCTIONS.md` — drift gates that defend invariants
