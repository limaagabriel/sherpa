#!/usr/bin/env bash
# Usage: test-check-terms.sh
# Input:  none; runs check-terms.sh on temp git fixtures. No framework.
# Output: "PASS: check-terms cases" or FAIL lines plus "FAILED".
# Exit:   0 when every case passes, 1 otherwise.
set -u
here=$(cd "$(dirname "$0")" && pwd)
guard="$here/check-terms.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
# Helpers from lib/assert.sh: assert_contains, assert_exit.
source "$here/../lib/assert.sh"

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

[ "$fail" -eq 0 ] && echo "PASS: check-terms cases" || echo "FAILED"
exit "$fail"
