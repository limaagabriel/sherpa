#!/usr/bin/env bash
# Usage: test-load-session-shared.sh
# Input:  none; runs load-session.sh against temp shared and project fixtures. No framework.
# Output: "PASS: all shared cases" or FAIL lines plus "FAILED".
# Exit:   0 when every case passes, 1 otherwise (0 with SKIP when yq or jq is missing).
set -u
unset SHERPA_CONFIG_DIR
here=$(cd "$(dirname "$0")" && pwd)
resolver="$here/load-session.sh"

command -v yq >/dev/null 2>&1 || { echo "SKIP: yq not installed"; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not installed"; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export XDG_CONFIG_HOME="$tmp/xdg"  # shared dir = $XDG_CONFIG_HOME/sherpa/shared
fail=0
# Helpers from lib/assert.sh: assert_contains, assert_not_contains, assert_eq, assert_exit.
source "$here/../lib/assert.sh"

sh="$tmp/xdg/sherpa/shared"
out() { printf '{"cwd":"%s"}' "$1" | bash "$resolver"; }
ctx() { out "$1" | jq -r '.hookSpecificOutput.additionalContext // ""'; }
msg() { out "$1" | jq -r '.systemMessage // ""'; }
primer=$(sed -n '/^---$/,/^---$/!p' "$here/../../skills/using-sherpa/SKILL.md")
mkdir -p "$tmp/nomatch" "$tmp/proj/.sherpa" "$sh"
echo "name: proj" >"$tmp/proj/.sherpa/project.yaml"

# neither shared nor project -> exactly today's generic output.
assert_eq neither-ctx "$(ctx "$tmp/nomatch")" "$primer"
assert_contains neither-msg "$(msg "$tmp/nomatch")" "running generic"

# shared only -> name=shared configPath=none plus the shared rules.
echo -n "Be brief." >"$sh/session.md"
os=$(ctx "$tmp/nomatch")
assert_contains shared-only-line "$os" "WORKFLOW_PACK: name=shared configPath=none"
assert_contains shared-only-rules "$os" "SHARED SESSION RULES — from $sh/session.md."
assert_contains shared-only-content "$os" "Be brief."
assert_contains shared-only-msg "$(msg "$tmp/nomatch")" "shared pack only"

# a shared context.md alone (no session.md) is enough to announce it.
rm "$sh/session.md"; echo -n "ctx" >"$sh/context.md"
os=$(ctx "$tmp/nomatch")
assert_contains shared-ctx-only "$os" "configPath=none"
assert_not_contains shared-ctx-no-rules "$os" "SHARED SESSION RULES"

# shared + project -> shared block before the project block.
echo -n "Be brief." >"$sh/session.md"; echo -n "Run tests." >"$tmp/proj/.sherpa/session.md"
op=$(ctx "$tmp/proj")
assert_contains both-project-line "$op" "WORKFLOW_PACK: name=proj"
assert_not_contains both-no-shared-line "$op" "name=shared"
assert_contains both-shared-first "${op%%PROJECT SESSION RULES*}" "SHARED SESSION RULES"

# yq missing -> primer, warning and the shared rules.
bin="$tmp/bin"; mkdir -p "$bin"
for t in bash cat jq dirname basename sed wc head; do p=$(command -v "$t") && ln -s "$p" "$bin/$t"; done
oy=$(printf '{"cwd":"%s"}' "$tmp/nomatch" | PATH="$bin" bash "$resolver"); ry=$?
assert_contains noyq-warning "$oy" "yq not found"
assert_contains noyq-shared "$oy" "Be brief."
assert_exit noyq-exit-0 "$ry" 0

[ "$fail" -eq 0 ] && echo "PASS: all shared cases" || echo "FAILED"
exit "$fail"
