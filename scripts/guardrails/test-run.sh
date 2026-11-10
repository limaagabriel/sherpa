#!/usr/bin/env bash
# Usage: test-run.sh
# Input:  none; runs run.sh against temp fixtures. No framework.
# Output: "PASS: all run cases" or FAIL lines plus "FAILED".
# Exit:   0 when every case passes, 1 otherwise (0 with SKIP when yq is missing).
set -u
here=$(cd "$(dirname "$0")" && pwd)
command -v yq >/dev/null 2>&1 || { echo "SKIP: yq not installed"; exit 0; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
# Helpers from lib/assert.sh: assert_contains, assert_not_contains, assert_eq, assert_exit.
source "$here/../lib/assert.sh"

run() { out=$(bash "$here/run.sh" "$@" 2>/dev/null); rc=$?; }
mk() { mkdir -p "$tmp/$1"; printf '%s\n' "$2" >"$tmp/$1/guardrails.yaml"; }

mk pass 'guardrails:
  - {name: a, run: "true", when: step}
  - {name: sk, skill: review, when: step}
  - {name: z, run: "false", when: end}'
run "$tmp/pass/project.yaml" step
assert_eq pass-output "$out" "GUARDRAIL a: pass"
assert_exit pass-0 "$rc" 0

mk fail 'guardrails:
  - {name: ok, run: "true"}
  - {name: bad, run: "echo boom; exit 3"}'
run "$tmp/fail/project.yaml" end
assert_contains fail-line "$out" "GUARDRAIL bad: fail"
assert_contains fail-tail "$out" "boom"
assert_contains later-ones-run "$out" "GUARDRAIL ok: pass"
assert_exit fail-1 "$rc" 1

mk long 'guardrails: [{name: l, run: "seq 1 30; exit 1"}]'
run "$tmp/long/project.yaml" step
assert_not_contains tail-20-only "$out" $'\n10\n'
assert_contains tail-20-has-last "$out" "30"

run "$tmp/none/project.yaml" step; assert_exit missing-file-0 "$rc" 0
run none step; assert_exit none-0 "$rc" 0
run "$tmp/pass/project.yaml" later; assert_exit unknown-phase-2 "$rc" 2
run "$tmp/pass/project.yaml"; assert_exit usage-2 "$rc" 2
mk bad 'guardrails: [oops'; run "$tmp/bad/project.yaml" step; assert_exit malformed-2 "$rc" 2
mk both 'guardrails: [{name: x, run: a, skill: b}]'; run "$tmp/both/project.yaml" step; assert_exit both-2 "$rc" 2
mk neither 'guardrails: [{name: x}]'; run "$tmp/neither/project.yaml" step; assert_exit neither-2 "$rc" 2
mk multi 'guardrails:
  - name: m
    run: |
      echo first
      false'
run "$tmp/multi/project.yaml" step; assert_exit multiline-2 "$rc" 2
assert_not_contains multiline-no-line "$out" "GUARDRAIL"

nb="$tmp/nobin"; mkdir -p "$nb"
for t in bash dirname; do ln -s "$(command -v $t)" "$nb/$t"; done
PATH="$nb" bash "$here/run.sh" "$tmp/pass/project.yaml" step >/dev/null 2>&1; assert_exit no-yq-2 $? 2

[ "$fail" -eq 0 ] && echo "PASS: all run cases" || echo "FAILED"
exit "$fail"
