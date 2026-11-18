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
for t in bash cat jq dirname basename sed wc head tr sort awk; do p=$(command -v "$t") && ln -s "$p" "$bin/$t"; done
oy=$(printf '{"cwd":"%s"}' "$tmp/nomatch" | PATH="$bin" bash "$resolver"); ry=$?
assert_contains noyq-warning "$oy" "yq not found"
assert_contains noyq-shared "$oy" "Be brief."
assert_exit noyq-exit-0 "$ry" 0

# --- PACK SKILLS index ---
mkskill() { mkdir -p "$1/skills/$2"; printf -- '---\nname: %s\ndescription: %s\n---\nbody\n' "$2" "$3" >"$1/skills/$2/SKILL.md"; }
rm -rf "$sh"; mkdir -p "$sh"
# no skills -> no block.
assert_not_contains skills-none "$(ctx "$tmp/nomatch")" "PACK SKILLS"
# shared skills alone make the shared pack present, with the index.
mkskill "$sh" greet "Say hello. Then more words."
os=$(ctx "$tmp/nomatch")
assert_contains skills-shared-only-line "$os" "WORKFLOW_PACK: name=shared configPath=none"
assert_contains skills-shared-only-header "$os" "PACK SKILLS — run one with /invoke <name> [args] when the request matches:"
assert_contains skills-shared-only-entry "$os" $'\n- greet: Say hello'
assert_not_contains skills-first-sentence "$os" "Then more words"
# no-yq branch lists shared skills.
oy=$(printf '{"cwd":"%s"}' "$tmp/nomatch" | PATH="$bin" bash "$resolver" | jq -r '.hookSpecificOutput.additionalContext'); ry=$?
assert_contains skills-noyq "$oy" "- greet: Say hello"
# project skills listed, project overrides shared by name.
mkskill "$tmp/proj/.sherpa" build "Build it."; mkskill "$tmp/proj/.sherpa" greet "Project greet."
op=$(ctx "$tmp/proj")
assert_contains skills-project-entry "$op" "- build: Build it"
assert_contains skills-project-override "$op" "- greet: Project greet"
# many long skills -> whole entries, a "more" line, block <= 2048 bytes.
rm -rf "$tmp/proj/.sherpa/skills" "$sh/skills"
long=$(printf 'x%.0s' $(seq 300))
for n in $(seq 20); do mkskill "$sh" "skill-$n" "$long"; done
ol=$(ctx "$tmp/nomatch")
blk=${ol#*PACK SKILLS}; blk="PACK SKILLS$blk"
assert_contains skills-more-line "$blk" "more — /invoke with no args lists all)"
assert_not_contains skills-no-truncated-entry "$blk" "$(printf 'x%.0s' $(seq 151))"
assert_eq skills-bytes-le-2048 "$([ "$(printf '%s' "$blk" | wc -c)" -le 2048 ] && echo ok)" ok
# first-sentence cut ignores abbreviations like "e.g. ".
mkskill "$sh" eg "Use for x (e.g. ship or deploy). Then more."
assert_contains skills-abbrev "$(ctx "$tmp/nomatch")" "- eg: Use for x (e.g. ship or deploy)"$'\n'
# a long non-ASCII description is cut on a character boundary (valid UTF-8).
if locale -a 2>/dev/null | grep -qi '^C\.utf-\?8$'; then
  rm -rf "$sh/skills"
  pt=$(printf 'ação não é coração %.0s' $(seq 20))
  mkskill "$sh" pt "$pt"
  ou=$(printf '{"cwd":"%s"}' "$tmp/nomatch" | LC_ALL=C.UTF-8 bash "$resolver" | jq -r '.hookSpecificOutput.additionalContext')
  assert_eq skills-utf8-valid "$(printf '%s' "$ou" | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1; echo $?)" 0
  assert_contains skills-utf8-entry "$ou" "- pt: ação"
fi
# unreadable skills dir -> hook still exits 0, valid JSON, no block.
if [ "$(id -u)" -ne 0 ]; then
  chmod 000 "$sh/skills"
  ou=$(out "$tmp/nomatch"); ru=$?
  chmod 755 "$sh/skills"
  assert_exit skills-unreadable-exit "$ru" 0
  assert_eq skills-unreadable-json "$(printf '%s' "$ou" | jq -e '.hookSpecificOutput' >/dev/null 2>&1; echo $?)" 0
  assert_not_contains skills-unreadable-none "$ou" "PACK SKILLS"
fi

[ "$fail" -eq 0 ] && echo "PASS: all shared cases" || echo "FAILED"
exit "$fail"
