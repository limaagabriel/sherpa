#!/usr/bin/env bash
# Usage: test-guard-bash.sh
# Input:  none; runs guard-bash.sh against fixture agents in a temp plugin root. No framework.
# Output: "PASS: all guard cases" or FAIL lines plus "FAILED".
# Exit:   0 when every case passes, 1 otherwise (including when jq is missing — never a skip).
set -u
here=$(cd "$(dirname "$0")" && pwd)
guard="$here/guard-bash.sh"
if ! command -v jq >/dev/null 2>&1; then echo "FAIL: jq is required to run this test"; exit 1; fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
source "$here/../lib/assert.sh"

mkdir -p "$tmp/root/agents" "$tmp/nojq"
printf -- '---\nname: ro\ncodexSandbox: read-only\n---\n' >"$tmp/root/agents/ro.md"
printf -- '---\nname: rw\ncodexSandbox: workspace-write\n---\n' >"$tmp/root/agents/rw.md"
for t in bash cat grep; do ln -s "$(command -v "$t")" "$tmp/nojq/$t"; done

payload() {  # <agent_type|-> <command>
  if [ "$1" = "-" ]; then jq -cn --arg c "$2" '{tool_input:{command:$c}}'
  else jq -cn --arg a "$1" --arg c "$2" '{agent_type:$a,tool_input:{command:$c}}'; fi
}
run() { payload "$1" "$2" | CLAUDE_PLUGIN_ROOT="$tmp/root" bash "$guard"; }

deny() {  # <command>
  local out; out=$(run sherpa:ro "$1"); assert_exit "exit [$1]" $? 0
  assert_contains "deny [$1]" "$out" '"permissionDecision":"deny"'
  assert_contains "reason [$1]" "$out" "sherpa: ro is read-only; blocked: "
  assert_not_contains "no-updatedInput [$1]" "$out" updatedInput
}
allow() {  # <command>
  local out; out=$(run sherpa:ro "$1"); assert_exit "exit [$1]" $? 0
  assert_eq "allow [$1]" "$out" ""
}
untouched() {  # <agent_type|-> <command>
  local out; out=$(run "$1" "$2"); assert_exit "exit [$1 $2]" $? 0
  assert_eq "untouched [$1 $2]" "$out" ""
}

deny 'git checkout 8ea1490'
deny 'git -C /x checkout y'
deny 'git -c a=b checkout x'
deny 'rtk git checkout x'
deny 'env git checkout x'
deny 'bash -c "git switch -c p"'
deny 'git branch -D x'
deny 'git status && git reset --hard'
deny 'rm -rf x'
deny 'echo hi | tee out'
deny 'sed -i s/a/b/ f'
deny 'find . -delete'
deny 'find . -name x -exec rm {} +'
deny 'echo x > f'
deny 'cat a >> f'
deny 'bash -c "echo x > f"'
deny 'ls
rm x'

allow 'git diff a..b && git show b:README.md'
allow 'git --no-pager log'
allow 'git -C /x log --oneline'
allow 'git branch'
allow 'git branch --list'
allow 'git branch --contains abc'
allow 'git status 2>&1 | head'
allow 'bash scripts/ci/check-terms.sh 2>&1'
allow 'grep -q x f >/dev/null'
allow 'grep -n "a > b" f'
allow 'grep -E "a|rm" f'
allow 'grep -rn "git checkout" skills'
allow "awk '\$1 > 5' f"
allow 'grep git README.md'
allow 'sed -n 1,5p f'
allow 'find . -name x'
allow 'cat f | wc -l'

untouched sherpa:rw 'git commit -m x'
untouched - 'git checkout x'
untouched ro 'git checkout x'
untouched other:ro 'git checkout x'
untouched sherpa:nope 'git checkout x'
untouched 'sherpa:../ro' 'git checkout x'

# No jq: a guarded caller is denied, everyone else passes.
nojq() { payload "$1" 'ls' | PATH="$tmp/nojq" CLAUDE_PLUGIN_ROOT="$tmp/root" "$tmp/nojq/bash" "$guard"; }
out=$(nojq sherpa:ro); assert_exit nojq-guarded-exit $? 0
assert_contains nojq-guarded "$out" '"permissionDecision":"deny"'
assert_contains nojq-reason "$out" "sherpa read-only guard needs jq"
assert_eq nojq-writable "$(nojq sherpa:rw)" ""
assert_eq nojq-bare "$(nojq ro)" ""
assert_eq nojq-no-agent "$(nojq -)" ""

[ "$fail" -eq 0 ] && echo "PASS: all guard cases" || echo "FAILED"
exit "$fail"
