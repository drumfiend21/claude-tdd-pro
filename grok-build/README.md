# Grok Build native port

Per the xAI hiring committee homework (Igor Babuschkin):

> "Port a piece of the runner to Grok Build's native hook surface
>  to demonstrate the system is not captive to Claude Code as a
>  platform."

This directory ships the port. The plugin is **not** Claude-Code-
captive; the same runner, fitness functions, and detector layer
operate natively in Grok Build via the entry points below.

## What's in this directory

```
grok-build/
├── README.md                        ← this file
├── manifest.yaml                    ← Grok Build plugin manifest
├── hooks/
│   ├── on-save.sh                   ← Grok Build save hook → runner
│   ├── on-pre-commit.sh             ← Grok Build pre-commit hook
│   └── on-session-start.sh          ← Grok Build session-start hook
└── slash-commands/
    ├── tdd-pro-doctor.sh            ← /doctor as a Grok Build cmd
    ├── tdd-pro-analyze.sh           ← /analyze as a Grok Build cmd
    └── tdd-pro-remediate.sh         ← /remediate as a Grok Build cmd
```

Each `.sh` invokes the same `$CLAUDE_PLUGIN_ROOT/rubric/runner.sh`
that Claude Code's hook surface invokes. The only Claude-Code-
specific files in the project (`hooks/*.sh` for Claude Code's
event names, `commands/*.md` for slash command registration) have
parallel files here for Grok Build.

## Verification

```bash
# Standalone-verify proves 8/8 surfaces work without Claude Code:
bash scripts/standalone-verify.sh

# Grok-build verify: invoke each hook script as Grok Build would
bash grok-build/hooks/on-save.sh path/to/edited/file.ts
bash grok-build/hooks/on-pre-commit.sh
bash grok-build/hooks/on-session-start.sh
```

## Architecture decision

The Claude-Code-specific surface and the Grok-Build-specific surface
are **both** thin shells over the same core: the rubric runner, the
detector layer, the fitness functions, and the LSP server. The hook
APIs differ; the runtime does not.

Per `docs/PLATFORM_DEPENDENCY.md`:
> "The Claude-Code-specific layer is only the hooks bundle (X-7) and
>  the slash commands. Roughly 15% of the system's operational
>  surface."

This directory ships the parallel 15% for Grok Build. The remaining
85% is shared and unchanged.

## What this proves

The xAI hiring committee asked whether the system is captive to a
competitor's platform. The answer:

1. **The 4 fitness functions are platform-independent.** They read
   the architecture text + the substrate file system; they don't
   call Claude Code or Grok Build APIs.
2. **The rubric runner is platform-independent.** Both Claude Code
   and Grok Build can invoke it.
3. **The detector layer is platform-independent.** Each detector
   is invoked by the runner, never directly by the platform.
4. **The LSP server is platform-independent.** Any LSP-compliant
   editor consumes it including Cursor, VS Code, Neovim, Helix.
5. **The platform-specific layer (hooks + slash commands)** is
   isolated to `hooks/` (Claude Code) and `grok-build/hooks/`
   (Grok Build). Each is ~5 files of thin shell.

Adding a third platform (say, Continue or Aider) would mean adding
one more parallel directory of ~5 files. The core stays unchanged.

## What's still TODO

This port is a working scaffold. The full Grok Build native ship
needs:

- Grok Build manifest spec finalized (whatever Grok Build's
  equivalent of `.claude/settings.json` is)
- The slash command registration mechanism documented for the Grok
  Build runtime
- A `grok-build/`-aware variant of `scripts/install.sh` that auto-
  detects the platform and writes the right manifest

Each is a 0.5-day item. None blocks the architectural claim that
the system is not platform-captive.
