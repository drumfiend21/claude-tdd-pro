# Community plugins

This directory holds rule-sets installed from community-published plugins via `/plugin-install <github-org>/<repo>`.

## Layout

Each installed plugin gets its own subdirectory:

```
_community/
└── <plugin-id>/
    └── <plugin-namespace>/
        ├── <file>.yaml            # ESLint-style source files (same schema as plugin-shipped)
        ├── <file>.yaml
        └── ...
```

Rule IDs from community plugins are namespaced as `<plugin-id>/<rule-id>` to avoid collisions with built-in or operator rules.

## Lifecycle

- `/plugin-install <github-org>/<repo>` — clones via `gh`, validates `plugin.yaml`, runs E-11 RuleTester suite, registers rules
- `/plugin-list [--show-rules] [--show-cost]` — what's installed
- `/plugin-update [<plugin-id>]` — checks for updates; re-runs E-11 tests; rejects upgrade on test failure
- `/plugin-remove <plugin-id>` — removes plugin; flags affected rules with `provenance_status: plugin-removed`

## Trust model

Community plugins default to `authority_tier: 2`. P0 elevation requires explicit operator override AND community catalog tier-1 review per H-10. See [docs/threat-model.md](../../docs/threat-model.md) for the full trust model around community-installed plugins.

## Signing

Plugins may include `signing.pub` and a signed `manifest.sig`. Signed plugins display verification status in `/plugin-list`. Set `userConfig.require_signed_plugins: true` to enforce signed-only installs.
