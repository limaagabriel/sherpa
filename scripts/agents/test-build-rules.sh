#!/usr/bin/env bash
# Usage: test-build-rules.sh
# Input:  none; runs build-rules.sh on temp fixtures (write, --check, errors). No framework.
# Output: "PASS: build-rules write and check cases" or FAIL lines plus "FAILED".
# Exit:   0 when every case passes, 1 otherwise.
set -u
here=$(cd "$(dirname "$0")" && pwd)
inliner="$here/build-rules.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
# Helpers from lib/assert.sh: assert_contains, assert_eq, assert_exit.
source "$here/../lib/assert.sh"

# --- build-rules.sh ---

mksrc() { mkdir -p "$(dirname "$1")"; printf '## demo\nDemo content line.\n' >"$1"; }

# a) marker + shared-rules-shaped source with a ## demo block -> inliner
# writes new text, --check exits 0 afterwards.
mksrc "$tmp/a/src.md"
mkdir -p "$tmp/a"
printf 'Before text.\n<!-- shared:demo -->\nold stuff\n<!-- /shared -->\nAfter text.\n' >"$tmp/a/target.md"
INLINE_SOURCE="$tmp/a/src.md" INLINE_TEST_FILES="$tmp/a/target.md" "$inliner" >/dev/null 2>"$tmp/a.err"
as=$?
assert_exit a-write-exit-0 "$as" 0
assert_contains a-content-updated "$(cat "$tmp/a/target.md")" "Demo content line."
INLINE_SOURCE="$tmp/a/src.md" INLINE_TEST_FILES="$tmp/a/target.md" "$inliner" --check >/dev/null 2>"$tmp/a-check.err"
assert_exit a-check-exit-0 "$?" 0

# b) hand-edited inlined block then --check exits 1.
sed -i 's/Demo content line./Hand-edited content./' "$tmp/a/target.md"
INLINE_SOURCE="$tmp/a/src.md" INLINE_TEST_FILES="$tmp/a/target.md" "$inliner" --check >/dev/null 2>"$tmp/b.err"
assert_exit b-check-exit-1 "$?" 1

# c) open marker with no close marker -> inliner exits nonzero, does not write.
mksrc "$tmp/c/src.md"
mkdir -p "$tmp/c"
printf 'Before.\n<!-- shared:demo -->\nno close here.\n' >"$tmp/c/target.md"
before_c=$(cat "$tmp/c/target.md")
INLINE_SOURCE="$tmp/c/src.md" INLINE_TEST_FILES="$tmp/c/target.md" "$inliner" >/dev/null 2>"$tmp/c.err"
cs=$?
[ "$cs" -eq 0 ] && { echo "FAIL [c-nonzero-exit]: expected nonzero, got 0"; fail=1; }
assert_eq c-no-write "$(cat "$tmp/c/target.md")" "$before_c"
assert_contains c-stderr-mentions-close "$(cat "$tmp/c.err")" "no matching close marker"

# d) same-line marker pair -> content still inlines, but the close marker is
# always forced onto its own line (never merged against whatever the block
# content ends with), so " suffix" trails the close marker on the next line.
mksrc "$tmp/d/src.md"
mkdir -p "$tmp/d"
printf 'prefix <!-- shared:demo --><!-- /shared --> suffix\n' >"$tmp/d/target.md"
INLINE_SOURCE="$tmp/d/src.md" INLINE_TEST_FILES="$tmp/d/target.md" "$inliner" >/dev/null 2>"$tmp/d.err"
assert_exit d-write-exit-0 "$?" 0
assert_contains d-inlined-same-line "$(cat "$tmp/d/target.md")" $'prefix <!-- shared:demo -->Demo content line.\n<!-- /shared --> suffix'

[ "$fail" -eq 0 ] && echo "PASS: build-rules write and check cases" || echo "FAILED"
exit "$fail"
