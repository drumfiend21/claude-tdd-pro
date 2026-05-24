---
name: tdd-pro-bash32-portability
description: macOS bash 3.2 + BSD-tool portability checklist for substrate writing in claude-tdd-pro. Reference BEFORE any new Write/Edit of a .sh file. Catches the 9 recurring portability gotchas (associative arrays, wc -l padding, printf %, env-var-passing-first, set -u + empty arrays, BSD grep --, redirect order, help-to-stderr, node -e top-level return, CLAUDE_PLUGIN_ROOT vs cwd).
---

# macOS Bash 3.2 + BSD-Tool Portability Checklist

**Rule:** Before writing or editing any new bash substrate, walk through this list. Don't catch these failures via spec runs — they're well-known and avoidable.

**Why:** Across CL-146..196 the same five portability bugs were repeatedly hit (associative arrays, `wc -l` padding, `printf %`, env-var passing, `set -u` + empty arrays). Each costs a debug-test-fix cycle of ~2 minutes. Treating this as a known-defect catalog saves ~10% per CL. Validated on CL-197: full H-8 promotion passed 10/10 first-run after applying this checklist (vs. ~4 spec-fix cycles per CL without it).

The canonical source-of-truth is [docs/memory/feedback-bash32-portability-checklist.md](../../../docs/memory/feedback-bash32-portability-checklist.md).

## The nine recurring portability bugs

### 1. No associative arrays

bash 3.2 (macOS default) rejects `declare -A`. Use `node -e '...'` for map/dict operations:

```bash
# WRONG — fails on macOS
declare -A counts
counts[apple]=3

# RIGHT — node handles maps
COUNT_JSON=$(KEY=apple VAL=3 node -e '
  const out = { [process.env.KEY]: Number(process.env.VAL) };
  process.stdout.write(JSON.stringify(out));
')
```

### 2. `wc -l < file` pads output with whitespace on macOS

```bash
# WRONG — actual value is "       2", not "2"
[ "$(wc -l < file)" = "2" ]

# RIGHT — strip whitespace
[ "$(wc -l < file | tr -d ' ')" = "2" ]
```

**Also patch spec files** — never trust a raw `wc -l` substring comparison.

### 3. `printf '...%\n'` is malformed

`%` starts a format spec; `%\n` is invalid. To emit a literal `%`, use `%%\n`:

```bash
# WRONG — silently produces nothing
printf 'similarity index 90%\n'

# RIGHT
printf 'similarity index 90%%\n'
```

Caught in W-9 spec setup with `similarity index 90%\n`.

### 4. Env-var passing into subshells must come FIRST

```bash
# WRONG — sets VAR in parent shell but NOT in node child
VAR=val RESULT=$(node -e 'console.log(process.env.VAR)')

# RIGHT — env-var goes inside the subshell, before the command
RESULT=$(VAR=val node -e 'console.log(process.env.VAR)')
```

Bites every node-via-bash one-liner.

### 5. `set -u` + empty array reference errors

`set -uo pipefail` + `"${ARR[@]}"` on an empty array → unbound variable error:

```bash
# WRONG — errors when ARR is empty
set -uo pipefail
ARR=()
for x in "${ARR[@]}"; do echo "$x"; done

# RIGHT — guard or use the empty-safe expansion
[[ ${#ARR[@]} -gt 0 ]] && for x in "${ARR[@]}"; do echo "$x"; done
# OR
for x in "${ARR[@]+"${ARR[@]}"}"; do echo "$x"; done
```

### 6. BSD `grep --flag-arg` confusion

`grep -E "--json..."` is read as a flag. Use `--` to end flag parsing:

```bash
# WRONG — BSD grep tries to parse --json as a flag
grep -E "--json-input" file

# RIGHT
grep -E -- "--json-input" file
```

### 7. Redirect order matters

`find ... 2>/dev/null >&2` sends find's stdout to /dev/null because `>&2` is evaluated when fd2 was just redirected:

```bash
# WRONG — stdout goes to /dev/null, not to original stderr
find . -type f 2>/dev/null >&2

# RIGHT — stdout to original stderr, then fd2 to /dev/null
find . -type f >&2 2>/dev/null
```

### 8. `node -e` does not allow top-level `return`

Code passed via `-e` runs at the top of a module, not inside a function:

```bash
# WRONG — SyntaxError: Illegal return statement
node -e '
  const x = check();
  if (!x) { return; }
  doMore(x);
'

# RIGHT — invert the condition
node -e '
  const x = check();
  if (x) { doMore(x); }
'

# OR — wrap in an IIFE
node -e '(() => {
  const x = check();
  if (!x) return;
  doMore(x);
})();'
```

Cost one spec-fix on S-9 conformance-report coverage matrix.

### 9. `CLAUDE_PLUGIN_ROOT` may not be cwd

Spec tests `mkdir -p repo` and `cd` to a tmpdir, but substrate that looks up registries or rule trees with `$PWD/...` will miss them:

```bash
# WRONG — assumes cwd is plugin root
SOURCES="$PWD/standards/sources.yaml"

# RIGHT — use CLAUDE_PLUGIN_ROOT for in-repo lookups, --root <dir> for the repo-under-test
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
SOURCES="$PLUGIN_ROOT/standards/sources.yaml"
```

## Bonus rule — help text must go to stderr

When specs do `2>out.txt && grep ...`, the help output needs to be on stderr:

```bash
# WRONG — help goes to stdout, spec misses it
-h|--help) echo "Usage: foo --bar"; exit 0 ;;

# RIGHT — wrap in { ... } >&2 or use echo >&2
-h|--help) echo "Usage: foo --bar" >&2; exit 0 ;;

# OR for multi-line help
-h|--help) { cat <<EOF
Usage: foo --bar <name>
  --bar    set the bar
EOF
} >&2; exit 0 ;;
```

Caught in H-6 with `/plan-first --help`; lost 4 spec-fix cycles before fixing.

## When to invoke this skill

- BEFORE writing or editing any `.sh` file.
- When debugging a spec that worked locally but fails in CI/cloud (cloud is usually Linux with bash 5+ and GNU tools — `wc -l` and `printf` differ).
- When porting a script tested on Linux to macOS.

## Related skills

- [`tdd-pro-cl-workflow`](../tdd-pro-cl-workflow/SKILL.md) — the broader per-CL discipline.
- [`tdd-pro-batch-cl`](../tdd-pro-batch-cl/SKILL.md) — when to ship multiple substrate writes together.
