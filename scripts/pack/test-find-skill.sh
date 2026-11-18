#!/usr/bin/env bash
# Usage: test-find-skill.sh
# Input:  none; runs find-skill.sh against temp fixtures. No framework.
# Output: "PASS: all find-skill cases" or FAIL lines plus "FAILED".
# Exit:   0 when every case passes, 1 otherwise.
set -u
unset SHERPA_CONFIG_DIR
here=$(cd "$(dirname "$0")" && pwd)
script="$here/find-skill.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export XDG_CONFIG_HOME="$tmp/xdg"
fail=0
source "$here/../lib/assert.sh"

shared="$XDG_CONFIG_HOME/sherpa/shared/skills"
proj="$tmp/proj"
mk() { mkdir -p "$1/$2"; printf '%s\n' "$3" >"$1/$2/SKILL.md"; }
mk "$proj/skills" mine $'---\ndescription: mine\n---'
mk "$shared" both $'---\ndescription: shared\n---'
mk "$proj/skills" both $'---\ndescription: project\n---'
mk "$shared" only-shared $'---\ndescription: s\n---'

# a) project hit.
assert_eq a-project-hit "$("$script" "$proj/project.yaml" mine)" "$proj/skills/mine/SKILL.md"
# b) project overrides shared.
assert_eq b-override "$("$script" "$proj/project.yaml" both)" "$proj/skills/both/SKILL.md"
# c) shared hit, with a config and with none.
assert_eq c-shared-hit "$("$script" "$proj/project.yaml" only-shared)" "$shared/only-shared/SKILL.md"
assert_eq c-none-shared "$("$script" none both)" "$shared/both/SKILL.md"
# d) miss -> exit 1, no stdout.
out=$("$script" "$proj/project.yaml" nope); s=$?
assert_exit d-miss-exit-1 "$s" 1
assert_eq d-miss-silent "$out" ""
# e) none hides project-only skills.
"$script" none mine >/dev/null; assert_exit e-none-miss $? 1
# f) usage errors.
"$script" >/dev/null 2>&1; assert_exit f-no-args-2 $? 2
"$script" none >/dev/null 2>&1; assert_exit f-one-arg-2 $? 2
[ "$fail" -eq 0 ] && echo "PASS: all find-skill cases" || echo "FAILED"
exit "$fail"
