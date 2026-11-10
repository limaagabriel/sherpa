#!/usr/bin/env bash
# Usage: test-load-layer.sh
# Input:  none; runs load-layer.sh against temp fixtures. No framework.
# Output: "PASS: all resolution cases" or FAIL lines plus "FAILED".
# Exit:   0 when every case passes, 1 otherwise (0 with SKIP when yq is missing).
set -u
here=$(cd "$(dirname "$0")" && pwd)
value_script="$here/load-layer.sh"

command -v yq >/dev/null 2>&1 || { echo "SKIP: yq not installed"; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
# Helpers from lib/assert.sh: assert_eq (exact output), assert_exit (exit code),
# assert_contains (stderr text).
source "$here/../lib/assert.sh"

# --- load-layer.sh ---
# u) root only.
mkdir -p "$tmp/vu"
echo -n "ROOT" >"$tmp/vu/context.md"
assert_eq u-root-only "$("$value_script" "$tmp/vu/project.yaml")" "ROOT"
# v) root + layer, exactly one blank line between.
mkdir -p "$tmp/vv/shape"
echo -n "ROOT" >"$tmp/vv/context.md"
echo -n "LAYER" >"$tmp/vv/shape/context.md"
assert_eq v-root-plus-layer "$("$value_script" "$tmp/vv/project.yaml" shape)" "$(printf 'ROOT\n\nLAYER')"

# v-analyze) root + layer with analyze, exactly one blank line between.
mkdir -p "$tmp/vv-analyze/analyze"
echo -n "ROOT" >"$tmp/vv-analyze/context.md"
echo -n "LAYER" >"$tmp/vv-analyze/analyze/context.md"
assert_eq v-analyze-root-plus-layer "$("$value_script" "$tmp/vv-analyze/project.yaml" analyze)" "$(printf 'ROOT\n\nLAYER')"

# w) layer present, root absent -> prints layer only, no stderr.
mkdir -p "$tmp/vw/implement"
echo -n "LAYER-ONLY" >"$tmp/vw/implement/context.md"
ow=$("$value_script" "$tmp/vw/project.yaml" implement 2>"$tmp/vw.err")
assert_eq w-layer-only "$ow" "LAYER-ONLY"
assert_eq w-no-stderr "$(cat "$tmp/vw.err")" ""
# x) root present, layer absent -> prints root only, no stderr.
mkdir -p "$tmp/vx"
echo -n "ROOT-ONLY" >"$tmp/vx/context.md"
ox=$("$value_script" "$tmp/vx/project.yaml" frame 2>"$tmp/vx.err")
assert_eq x-root-only "$ox" "ROOT-ONLY"
assert_eq x-no-stderr "$(cat "$tmp/vx.err")" ""
# y) neither present -> empty stdout/stderr, exit 0.
mkdir -p "$tmp/vy"
oy=$("$value_script" "$tmp/vy/project.yaml" frame 2>"$tmp/vy.err"); ys=$?
assert_eq y-empty-stdout "$oy" ""
assert_eq y-empty-stderr "$(cat "$tmp/vy.err")" ""
assert_exit y-exit-0 "$ys" 0
# z) unknown layer -> exit 1 with stderr.
mkdir -p "$tmp/vz"
"$value_script" "$tmp/vz/project.yaml" bogus >/dev/null 2>"$tmp/vz.err"; zs=$?
assert_exit z-exit-1 "$zs" 1
assert_contains z-stderr-names-it "$(cat "$tmp/vz.err")" "bogus"
# aa) no configPath -> exit 1.
"$value_script" >/dev/null 2>"$tmp/vaa.err"; aas=$?
assert_exit aa-no-configpath-exit-1 "$aas" 1
[ "$fail" -eq 0 ] && echo "PASS: all resolution cases" || echo "FAILED"
exit "$fail"
