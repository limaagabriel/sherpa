#!/usr/bin/env bash
# Self-check for inline-shared-rules.sh and check-retired-terms.sh. Runs the
# real scripts against temp fixtures and asserts their output. No framework.
set -u

here=$(cd "$(dirname "$0")" && pwd)
inliner="$here/inline-shared-rules.sh"
guard="$here/check-retired-terms.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0

assert_contains() { case "$2" in *"$3"*) ;; *) echo "FAIL [$1]: expected contains: $3 -- got: $2"; fail=1 ;; esac; }
assert_eq() { [ "$2" = "$3" ] || { echo "FAIL [$1]: expected: $3 -- got: $2"; fail=1; }; }
assert_exit() { [ "$2" -eq "$3" ] || { echo "FAIL [$1]: expected exit $3, got $2"; fail=1; }; }

# --- inline-shared-rules.sh ---

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

# --- check-retired-terms.sh ---

# dirty fixture (contains "appetite") -> exit 1.
mkdir -p "$tmp/rt-dirty/skills"
(cd "$tmp/rt-dirty" && git init -q && printf 'This plan has appetite for scope.\n' >skills/dirty.md && git add -A)
printf '\\bappetite\\b\n' >"$tmp/terms.txt"
REPO_ROOT="$tmp/rt-dirty" TERMS_FILE="$tmp/terms.txt" SCAN_PATHS="skills" "$guard" >"$tmp/rt-dirty.out" 2>&1
assert_exit rt-dirty-exit-1 "$?" 1
assert_contains rt-dirty-reports-hit "$(cat "$tmp/rt-dirty.out")" "appetite"

# clean fixture -> exit 0.
mkdir -p "$tmp/rt-clean/skills"
(cd "$tmp/rt-clean" && git init -q && printf 'Nothing retired in here.\n' >skills/clean.md && git add -A)
REPO_ROOT="$tmp/rt-clean" TERMS_FILE="$tmp/terms.txt" SCAN_PATHS="skills" "$guard" >"$tmp/rt-clean.out" 2>&1
assert_exit rt-clean-exit-0 "$?" 0

[ "$fail" -eq 0 ] && echo "PASS: all inline-shared-rules / check-retired-terms cases" || echo "FAILED"
exit "$fail"
