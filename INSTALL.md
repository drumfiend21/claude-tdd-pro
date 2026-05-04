# Installing claude-tdd-pro

## On a fresh machine

### 1. Clone into Claude Code's plugin directory

```bash
mkdir -p ~/.claude/plugins
git clone https://github.com/YOUR_USER/claude-tdd-pro ~/.claude/plugins/claude-tdd-pro
```

(If you haven't pushed this to GitHub yet, see the bottom of this
file for the publish-and-pull workflow.)

### 2. Restart Claude Code

The plugin loader reads `~/.claude/plugins/*/.claude-plugin/plugin.json`
on startup. Restart any Claude Code session that was already running.

### 3. Verify

In any project, type `/feature` (or any of the commands) — you should
see the slash command listed. If it's not showing up, see
"Troubleshooting" below.

## Updating

```bash
cd ~/.claude/plugins/claude-tdd-pro
git pull
```

Restart Claude Code for the changes to take effect.

## Verification checklist

After installation, verify each component is reachable:

| Component | Verification |
|---|---|
| Manifest | `cat ~/.claude/plugins/claude-tdd-pro/.claude-plugin/plugin.json` shows the `name` field |
| Skills | Listed in any session's `/skills` output (or auto-trigger when described) |
| Commands | `/feature`, `/extract-component`, `/fix-bug`, `/tighten-tests`, `/init-guardrails`, `/snapshot`, `/pr` all autocomplete |
| Agents | `/agents` lists `strict-test-writer`, `pr-self-reviewer`, `tdd-driver` |
| Hooks | After editing a `.js` file, lint should run automatically (any error surfaces in the next agent turn) |

## Troubleshooting

### Slash commands don't appear

- Check `~/.claude/plugins/claude-tdd-pro/.claude-plugin/plugin.json`
  exists.
- Check the `name` field is `"claude-tdd-pro"` (no typos).
- Restart Claude Code.

### Skills don't auto-trigger

The model decides when to invoke a skill based on its `description`
field. If a skill isn't firing when you expect it to:

- Open the skill's `SKILL.md` and read the description.
- Either rephrase your prompt to match the description's vocabulary,
  or update the description to be more permissive.
- Manually invoke via `/<skill-name>` in some Claude Code versions.

### Lint hook doesn't run

Check:
- `~/.claude/plugins/claude-tdd-pro/hooks/scripts/lint-on-save.sh` is
  executable (`chmod +x`).
- Your project has `node_modules/eslint` and an `eslint.config.js` /
  `.eslintrc.*` (the hook skips silently if not).
- `jq` is installed (the script uses it to parse the hook input). On
  macOS: `brew install jq`. On Ubuntu: `apt install jq`.

## Customizing for your team

The plugin is opinionated. To adapt:

1. **Rules**: edit `QUALITY-BAR.md`. Every skill references it.
2. **Templates**: edit `templates/PR_BODY.md`,
   `templates/COMMIT_MESSAGE.md`, etc.
3. **Lint config**: edit `templates/eslint.config.flat.{js,react.js}`
   to match your team's preferences.
4. **Skill descriptions**: edit each `SKILL.md`'s frontmatter to
   change when it auto-triggers.

After customizing, commit + push to your fork, then `git pull` on
each machine.

## Publishing to GitHub (first time)

If this directory was created locally and not yet pushed:

```bash
cd ~/projects/claude-tdd-pro
git init
git add -A
git commit -m "Initial commit: claude-tdd-pro plugin scaffold"

# Create the repo on GitHub (CLI):
gh repo create claude-tdd-pro --public --source=. --remote=origin
git push -u origin main
```

Then on each new machine, follow the "On a fresh machine" steps
above.

## Uninstalling

```bash
rm -rf ~/.claude/plugins/claude-tdd-pro
```

Restart Claude Code.
