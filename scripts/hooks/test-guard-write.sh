#!/usr/bin/env bash
# Usage: test-guard-write.sh
# Input:  none; runs guard-write.sh against fixture agents in a temp plugin root. No framework.
# Output: "PASS: all guard cases" or FAIL lines plus "FAILED".
# Exit:   0 when every case passes, 1 otherwise (including when jq is missing — never a skip).
set -u
here=$(cd "$(dirname "$0")" && pwd)
guard="$here/guard-write.sh"
if ! command -v jq >/dev/null 2>&1; then echo "FAIL: jq is required to run this test"; exit 1; fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
source "$here/../lib/assert.sh"

# TMPDIR points at a fixture dir, so the test never touches the real /tmp.
mkdir -p "$tmp/root/agents" "$tmp/tmpdir/sherpa-AbC123" "$tmp/tmpdir/other" "$tmp/repo"
printf -- '---\nname: ro\ncodexSandbox: read-only\n---\n' >"$tmp/root/agents/ro.md"
printf -- '---\nname: rw\ncodexSandbox: workspace-write\n---\n' >"$tmp/root/agents/rw.md"
ln -s "$tmp/repo" "$tmp/tmpdir/sherpa-AbC123/escape"
h="$tmp/tmpdir/sherpa-AbC123"

run() {  # <agent_type> <file_path>
  jq -cn --arg a "$1" --arg p "$2" '{agent_type:$a,tool_input:{file_path:$p}}' |
    TMPDIR="$tmp/tmpdir" CLAUDE_PLUGIN_ROOT="$tmp/root" bash "$guard"
}
deny() {  # <label> <file_path>
  local out; out=$(run sherpa:ro "$2"); assert_exit "exit [$1]" $? 0
  assert_contains "deny [$1]" "$out" '"permissionDecision":"deny"'
  assert_contains "reason [$1]" "$out" "protocols/handoff.md"
  assert_not_contains "no-updatedInput [$1]" "$out" updatedInput
}
allow() {  # <label> <agent_type> <file_path>
  local out; out=$(run "$2" "$3"); assert_exit "exit [$1]" $? 0
  assert_eq "allow [$1]" "$out" ""
}

allow handoff-file sherpa:ro "$h/ro-lens.md"
deny dotdot-escape "$h/../other/x.md"
deny sibling-dir "$tmp/tmpdir/other/x.md"
deny repo-path "$tmp/repo/README.md"
deny symlink-escape "$h/escape/x.md"
allow non-sherpa-agent sherpa:rw "$tmp/repo/README.md"

[ "$fail" -eq 0 ] && echo "PASS: all guard cases" || echo "FAILED"
exit "$fail"
