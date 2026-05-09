#!/usr/bin/env bash
# Emit programs.zen-browser option metadata as JSON (requires Nix + flake).
# Usage: ./tooling/gen-options.sh [output.json]
# Env: FLAKE_ROOT (flake root; set automatically by `nix run .#docs-options`),
#      SYSTEM, VARIANT, INCLUDE_INTERNAL.
set -euo pipefail

root="${FLAKE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
out="${1:-${root}/options.json}"
system="${SYSTEM:-$(nix eval --impure --raw --expr builtins.currentSystem)}"
variant="${VARIANT:-beta}"
include_internal="${INCLUDE_INTERNAL:-0}"
if [[ "${include_internal}" == "1" ]]; then
  inc=true
else
  inc=false
fi

nix eval --impure --json --expr "
  import \"${root}/tooling/export-hm-options.nix\" {
    flakePath = \"${root}\";
    system = \"${system}\";
    variant = \"${variant}\";
    includeInternal = ${inc};
  }
" >"${out}"

if command -v jq >/dev/null 2>&1; then
  count="$(jq -r '.meta.optionCount' "${out}")"
  printf 'wrote %s (%s options, variant=%s, system=%s)\n' "${out}" "${count}" "${variant}" "${system}"
else
  printf 'wrote %s\n' "${out}"
fi
