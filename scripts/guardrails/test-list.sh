#!/usr/bin/env bash
# Usage: test-list.sh
# Input:  none; runs list.sh against temp fixtures. No framework.
# Output: "PASS: all list cases" or FAIL lines plus "FAILED".
# Exit:   0 when every case passes, 1 otherwise (0 with SKIP when yq is missing).
set -u
here=$(cd "$(dirname "$0")" && pwd)
command -v yq >/dev/null 2>&1 || { echo "SKIP: yq not installed"; exit 0; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
# Helpers from lib/assert.sh: assert_eq, assert_exit, assert_contains.
source "$here/../lib/assert.sh"

T=$'\t'
list() { bash "$here/list.sh" "$@" 2>/dev/null; }
mk() { mkdir -p "$tmp/$1"; printf '%s\n' "$2" >"$tmp/$1/guardrails.yaml"; }
cfg() { echo "$tmp/$1/project.yaml"; }

mk ok 'guardrails:
  - {name: s, run: "echo s", when: step}
  - {name: e, run: "echo e", when: end}
  - {name: b, skill: review, args: "--fast", when: both}
  - {name: d, run: "echo d"}'
assert_eq step-only "$(list "$(cfg ok)" step run)" "s${T}run${T}echo s
d${T}run${T}echo d"
assert_eq end-only "$(list "$(cfg ok)" end run)" "e${T}run${T}echo e
d${T}run${T}echo d"
assert_eq both-and-default "$(list "$(cfg ok)" step | cut -f1 | tr '\n' ' ')" "s b d "
assert_eq skill-filter "$(list "$(cfg ok)" end skill)" "b${T}skill${T}review --fast"

list "$(cfg missing)" step; assert_exit missing-file-0 $? 0
list none step; assert_exit none-0 $? 0
list "$(cfg ok)" later; assert_exit unknown-phase-2 $? 2
list; assert_exit usage-2 $? 2
mk bad 'guardrails: [oops'; list "$(cfg bad)" step; assert_exit malformed-2 $? 2
mk both 'guardrails: [{name: x, run: a, skill: b}]'; list "$(cfg both)" step; assert_exit both-2 $? 2
mk neither 'guardrails: [{name: x}]'; list "$(cfg neither)" step; assert_exit neither-2 $? 2
mk noname 'guardrails: [{run: a}]'; list "$(cfg noname)" step; assert_exit noname-2 $? 2
mk multi 'guardrails:
  - name: m
    run: |
      echo first
      false'
out=$(bash "$here/list.sh" "$(cfg multi)" step 2>&1); assert_exit multiline-2 $? 2
assert_contains multiline-msg "$out" "values must be a single line"
mk badwhen 'guardrails: [{name: x, run: a, when: never}]'; list "$(cfg badwhen)" step; assert_exit badwhen-2 $? 2

nb="$tmp/nobin"; mkdir -p "$nb"
for t in bash dirname; do ln -s "$(command -v $t)" "$nb/$t"; done
PATH="$nb" bash "$here/list.sh" "$(cfg ok)" step >/dev/null 2>&1; assert_exit no-yq-2 $? 2

[ "$fail" -eq 0 ] && echo "PASS: all list cases" || echo "FAILED"
exit "$fail"
