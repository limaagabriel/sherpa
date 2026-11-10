#!/usr/bin/env bash
# Usage: test-load-layer-shared.sh
# Input:  none; runs load-layer.sh against temp shared and project fixtures. No framework.
# Output: "PASS: all shared cases" or FAIL lines plus "FAILED".
# Exit:   0 when every case passes, 1 otherwise.
set -u
unset SHERPA_CONFIG_DIR
here=$(cd "$(dirname "$0")" && pwd)
loader="$here/load-layer.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export XDG_CONFIG_HOME="$tmp/xdg"  # shared dir = $XDG_CONFIG_HOME/sherpa/shared
fail=0
# Helpers from lib/assert.sh: assert_eq (exact output), assert_exit (exit code).
source "$here/../lib/assert.sh"

sh="$tmp/xdg/sherpa/shared"
rule='PROJECT RULES (override shared rules above on conflict):'
mkdir -p "$tmp/p/shape" "$sh/shape"
echo -n "PROOT" >"$tmp/p/context.md"
echo -n "PLAYER" >"$tmp/p/shape/context.md"

# no shared files -> project output exactly as before.
assert_eq no-shared "$("$loader" "$tmp/p/project.yaml" shape)" "$(printf 'PROOT\n\nPLAYER')"

# shared + project -> shared first, then the precedence line, then project.
echo -n "SROOT" >"$sh/context.md"
echo -n "SLAYER" >"$sh/shape/context.md"
assert_eq shared-then-project "$("$loader" "$tmp/p/project.yaml" shape)" \
  "$(printf 'SROOT\n\nSLAYER\n\n%s\nPROOT\n\nPLAYER' "$rule")"

# shared only (no project files) -> no precedence line.
assert_eq shared-only "$("$loader" "$tmp/none/project.yaml" shape)" "$(printf 'SROOT\n\nSLAYER')"

# `none` -> shared only, no project lookup.
assert_eq none-shared-only "$("$loader" none shape)" "$(printf 'SROOT\n\nSLAYER')"
"$loader" none shape >/dev/null; assert_exit none-exit-0 $? 0

# `none` and no shared files -> empty, exit 0.
rm -rf "$sh"
assert_eq none-no-shared "$("$loader" none shape)" ""

[ "$fail" -eq 0 ] && echo "PASS: all shared cases" || echo "FAILED"
exit "$fail"
