#!/usr/bin/env bash
# C-1 framework fetcher stub for pci-dss-v4. Operator wires real fetch logic
# (HTTPS GET + freshness write) here. Stub exits 0 with a clear log so
# the registry validator can confirm the fetcher ships.
set -uo pipefail
echo "fetcher: framework=pci-dss-v4 status=stub (operator-wire-required)" >&2
exit 0
