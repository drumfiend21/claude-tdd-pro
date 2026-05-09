# Operator namespace

This directory is **yours**. Plugin upgrades never touch any file under `_operator/`.

## Two patterns

### 1. New rules unique to your org

Drop a file under `_operator/<my-org>/`:

```
_operator/
└── acme-corp/
    └── conventions.yaml          # your team's rules
```

Each file follows the same source-file schema as plugin-shipped files (`schemas/source-file.schema.json`). Rule IDs use a prefix matching your namespace: `acme-corp-001`, `acme-corp-002`, etc.

Scaffold automatically:

```bash
/operator-namespace-init acme-corp
```

### 2. Extensions/overrides of plugin-shipped sources

If you want to add or override rules attributed to an existing plugin source folder (e.g., add a tighter Google TypeScript rule for your org), drop an extension file under `_operator/<source-namespace>/`:

```
_operator/
├── google/
│   └── tsguide-extensions.yaml   # extends or overrides google/tsguide.yaml
└── us-government/
    └── nist-ssdf-extensions.yaml
```

When the aggregator merges files (G-5), `_operator/` is processed LAST, so operator extensions override plugin defaults for matching rule IDs (per the cascade contract in §2.5).

Scaffold automatically:

```bash
/operator-extension-init google tsguide
```

## Privacy

Files under `_operator/` are part of your project repo by default. If you want machine-local-only experiments, add specific files to `.gitignore` per your preference. Plugin sync (O-4) preserves `_operator/` across machines via the `tdd-pro-sync` branch.
