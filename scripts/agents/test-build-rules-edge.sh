#!/usr/bin/env bash
# Usage: test-build-rules-edge.sh
# Input:  none; runs build-rules.sh on temp fixtures (marker and fence edge cases). No framework.
# Output: "PASS: build-rules edge cases" or FAIL lines plus "FAILED".
# Exit:   0 when every case passes, 1 otherwise.
set -u
here=$(cd "$(dirname "$0")" && pwd)
inliner="$here/build-rules.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
# Helpers from lib/assert.sh: assert_contains, assert_eq, assert_exit.
source "$here/../lib/assert.sh"

mksrc() { mkdir -p "$(dirname "$1")"; printf '## demo\nDemo content line.\n' >"$1"; }

# e) two marker pairs on one line.
mksrc "$tmp/e/src.md"
mkdir -p "$tmp/e"
printf '<!-- shared:demo --><!-- /shared --><!-- shared:demo --><!-- /shared -->\n' >"$tmp/e/target.md"
INLINE_SOURCE="$tmp/e/src.md" INLINE_TEST_FILES="$tmp/e/target.md" "$inliner" >/dev/null 2>"$tmp/e.err"
assert_exit e-write-exit-0 "$?" 0
es_count=$(grep -o "Demo content line." "$tmp/e/target.md" | wc -l)
assert_eq e-both-pairs-inlined "$es_count" "2"

# f) second open marker before first closes -> rejected.
mksrc "$tmp/f/src.md"
mkdir -p "$tmp/f"
printf '<!-- shared:demo --> mid <!-- shared:demo --> tail <!-- /shared -->\n' >"$tmp/f/target.md"
before_f=$(cat "$tmp/f/target.md")
INLINE_SOURCE="$tmp/f/src.md" INLINE_TEST_FILES="$tmp/f/target.md" "$inliner" >/dev/null 2>"$tmp/f.err"
fs=$?
[ "$fs" -eq 0 ] && { echo "FAIL [f-nonzero-exit]: expected nonzero, got 0"; fail=1; }
assert_eq f-no-write "$(cat "$tmp/f/target.md")" "$before_f"

# g) unrecognized flag -> usage error to stderr, exit 1 (no silent fall-through to write mode).
mksrc "$tmp/g/src.md"
mkdir -p "$tmp/g"
printf 'plain file, no markers.\n' >"$tmp/g/target.md"
before_g=$(cat "$tmp/g/target.md")
INLINE_SOURCE="$tmp/g/src.md" INLINE_TEST_FILES="$tmp/g/target.md" "$inliner" --bogus >/dev/null 2>"$tmp/g.err"
assert_exit g-bogus-flag-exit-1 "$?" 1
assert_contains g-usage-on-stderr "$(cat "$tmp/g.err")" "usage:"
assert_eq g-no-write "$(cat "$tmp/g/target.md")" "$before_g"

# h) CRLF line endings don't defeat the frontmatter guard: a marker after a
# CRLF-terminated closing `---` is accepted and inlined, not rejected.
mksrc "$tmp/h/src.md"
mkdir -p "$tmp/h"
printf -- '---\r\nfoo: bar\r\n---\r\nBefore.\r\n<!-- shared:demo -->\r\nold\r\n<!-- /shared -->\r\nAfter.\r\n' >"$tmp/h/target.md"
INLINE_SOURCE="$tmp/h/src.md" INLINE_TEST_FILES="$tmp/h/target.md" "$inliner" >/dev/null 2>"$tmp/h.err"
assert_exit h-crlf-write-exit-0 "$?" 0
assert_contains h-crlf-inlined "$(cat "$tmp/h/target.md")" "Demo content line."

# i) shared block whose content ends in a bare ``` fence line -> the close
# marker must land on its own line (not merge with the fence into one
# ```<!-- /shared --> line), and that fence line must not be mistaken for a
# real markdown fence while still inside the marker span -- so a fresh
# --check right after inlining exits 0 instead of failing with a misleading
# "no matching close marker" error.
mkdir -p "$tmp/i"
printf '## demo\nDemo content line.\n```\n' >"$tmp/i/src.md"
printf 'Before.\n<!-- shared:demo -->\nold\n<!-- /shared -->\nAfter.\n' >"$tmp/i/target.md"
INLINE_SOURCE="$tmp/i/src.md" INLINE_TEST_FILES="$tmp/i/target.md" "$inliner" >/dev/null 2>"$tmp/i.err"
assert_exit i-write-exit-0 "$?" 0
assert_contains i-close-marker-on-own-line "$(cat "$tmp/i/target.md")" $'```\n<!-- /shared -->'
INLINE_SOURCE="$tmp/i/src.md" INLINE_TEST_FILES="$tmp/i/target.md" "$inliner" --check >/dev/null 2>"$tmp/i-check.err"
assert_exit i-check-exit-0 "$?" 0
assert_eq i-check-no-misleading-error "$(cat "$tmp/i-check.err")" ""

[ "$fail" -eq 0 ] && echo "PASS: build-rules edge cases" || echo "FAILED"
exit "$fail"
