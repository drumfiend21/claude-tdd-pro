---
name: macOS bash 3.2 portability checklist for substrate writing
description: Reference BEFORE writing any new substrate script. Catches the macOS bash 3.2 + BSD-tool gotchas that I repeatedly re-discover by trial-and-error during eval failures. Save 1-2 spec-fix round trips per CL by checking against this list at write time.
type: feedback
---

**Rule:** Before writing any new bash substrate, run through this list. Don't catch these failures via spec runs — they're well-known and avoidable.

**Why:** Across CL-146..196 I repeatedly hit the same five portability bugs (associative arrays, `wc -l` padding, `printf %`, env-var passing, set -u + empty arrays). Each one costs a debug-test-fix cycle of ~2 minutes. Treating this as a known-defect catalog rather than rediscovering each one saves ~10% per CL.

**How to apply:** Read this once at session start. Reference again before any substrate touching arrays, file counts, format strings, subshell env-vars, or stderr/stdout ordering.

## The seven recurring portability bugs

1. **No associative arrays.** bash 3.2 (macOS default) rejects `declare -A`. Use `node -e '...'` for map/dict operations.

2. **macOS `wc -l < file` pads output with whitespace.** `[ "$(wc -l < file)" = "2" ]` fails because the actual value is `"       2"`. Always pipe through `| tr -d ' '`. Update spec files too — never trust a raw `wc -l` substring comparison.

3. **`printf '...%\n'` is malformed.** `%` starts a format spec; `%\n` is invalid. To emit a literal `%`, use `%%\n`. Caught this in W-9 spec setup with `similarity index 90%\n` — silently produces nothing.

4. **Env-var passing into subshells must come FIRST.** `RESULT=$(VAR=val node -e ...)` works. `VAR=val RESULT=$(node -e ...)` sets VAR in the parent shell but NOT in the node child. This bites every time I write a node-via-bash one-liner.

5. **`set -u` + empty array reference errors.** `set -uo pipefail` + `"${ARR[@]}"` on an empty array → unbound variable error. Use `"${ARR[@]+"${ARR[@]}"}"` or guard with `[[ ${#ARR[@]} -gt 0 ]]` first.

6. **BSD grep `--flag-arg` confusion.** `grep -E "--json..."` is read as a flag. Use `grep -E -- "--json..."` (the `--` ends flag parsing).

7. **Redirect order matters.** `find ... 2>/dev/null >&2` sends find's stdout to /dev/null (because `>&2` is evaluated when fd2 was just redirected). Use `find ... >&2 2>/dev/null` to send stdout to the original stderr, then fd2 to /dev/null.

## One bonus rule

**Help text must go to stderr** when specs do `2>out.txt && grep ...`. Wrap multi-line `echo` in `{ ... } >&2` or change to `echo "..." >&2`. Caught in H-6 with /plan-first --help; lost 4 spec-fix cycles before fixing.
