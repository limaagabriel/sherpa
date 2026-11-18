#!/usr/bin/env bash
# Usage: test-list-skills.sh
# Input:  none; runs list-skills.sh against temp fixtures. No framework.
# Output: "PASS: all list-skills cases" or FAIL lines plus "FAILED".
# Exit:   0 when every case passes, 1 otherwise.
set -u
unset SHERPA_CONFIG_DIR
here=$(cd "$(dirname "$0")" && pwd)
script="$here/list-skills.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export XDG_CONFIG_HOME="$tmp/xdg"
fail=0
source "$here/../lib/assert.sh"

shared="$XDG_CONFIG_HOME/sherpa/shared/skills"
proj="$tmp/proj"
mk() { mkdir -p "$1/$2"; printf '%s\n' "$3" >"$1/$2/SKILL.md"; }
T=$'\t'

# a) no skills dir anywhere.
assert_eq a-empty "$("$script" "$proj/project.yaml")" ""
"$script" "$proj/project.yaml" >/dev/null; assert_exit a-exit-0 $? 0

# b) project only, quotes stripped, sorted by name.
mk "$proj/skills" zeta $'---\ndescription: "Z skill"\n---\nbody'
mk "$proj/skills" alpha $'---\nname: alpha\ndescription: \x27A skill\x27\n---'
assert_eq b-project-sorted "$("$script" "$proj/project.yaml")" \
  "alpha${T}$proj/skills/alpha/SKILL.md${T}A skill
zeta${T}$proj/skills/zeta/SKILL.md${T}Z skill"

# c) shared only (config has no skills).
mk "$shared" sh $'---\ndescription: Shared one\n---'
assert_eq c-shared-only "$("$script" "$tmp/none/project.yaml")" "sh${T}$shared/sh/SKILL.md${T}Shared one"

# d) project overrides shared by dir name.
mk "$shared" alpha $'---\ndescription: shared alpha\n---'
out=$("$script" "$proj/project.yaml")
assert_contains d-project-wins "$out" "alpha${T}$proj/skills/alpha/SKILL.md${T}A skill"
assert_not_contains d-no-shared-alpha "$out" "shared alpha"
assert_contains d-shared-kept "$out" "sh${T}$shared/sh/SKILL.md"

# e) none skips the project scan.
out=$("$script" none)
assert_not_contains e-none-no-zeta "$out" "zeta"
assert_contains e-none-shared "$out" "alpha${T}$shared/alpha/SKILL.md${T}shared alpha"

# f) missing description -> empty field.
mk "$proj/skills" nodesc $'---\nname: nodesc\n---'
assert_contains f-empty-desc "$("$script" "$proj/project.yaml")" "nodesc${T}$proj/skills/nodesc/SKILL.md${T}"

# g) folded multi-line description: only the one-line form is supported (empty value).
mk "$proj/skills" folded $'---\ndescription: >\n  long text\n---'
assert_contains g-folded-empty "$("$script" "$proj/project.yaml")" "folded${T}$proj/skills/folded/SKILL.md${T}
"

# g2) a TAB in the description becomes a space; CRLF line endings are stripped.
mk "$proj/skills" tabbed $'---\ndescription: a\tb\n---'
assert_contains g2-tab-to-space "$("$script" "$proj/project.yaml")" "tabbed${T}$proj/skills/tabbed/SKILL.md${T}a b"
mkdir -p "$proj/skills/crlf"
printf -- '---\r\ndescription: "crlf one"\r\n---\r\n' >"$proj/skills/crlf/SKILL.md"
assert_contains g2-crlf "$("$script" "$proj/project.yaml")" "crlf${T}$proj/skills/crlf/SKILL.md${T}crlf one
"

# h) usage error.
"$script" >/dev/null 2>&1; assert_exit h-usage-2 $? 2
[ "$fail" -eq 0 ] && echo "PASS: all list-skills cases" || echo "FAILED"
exit "$fail"
