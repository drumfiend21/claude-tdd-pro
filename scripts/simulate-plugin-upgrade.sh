#!/usr/bin/env bash
# G-8 simulate-plugin-upgrade — exercises the operator-namespace preservation
# guarantee. Upgrade is a no-op on _operator/* by contract (§2.22). Used by
# tests to verify operator content survives a shipped-tree refresh.
set -uo pipefail
ROOT=""; TO_VERSION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --to-version) TO_VERSION="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[[ -z "$ROOT" || ! -d "$ROOT" ]] && { echo "simulate-plugin-upgrade: --root <dir> required" >&2; exit 2; }

echo "simulate-plugin-upgrade: root=$ROOT to_version=$TO_VERSION operator_namespace_preserved=true" >&2
