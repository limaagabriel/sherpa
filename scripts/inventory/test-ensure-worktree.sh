#!/usr/bin/env bash
# Usage: test-ensure-worktree.sh
# Input:  none; builds fixtures in a temp SHERPA_CONFIG_DIR and HOME. Needs yq and git.
# Output: "PASS: all worktree cases" or FAIL lines plus "FAILED".
# Exit:   0 when every case passes, 1 otherwise.
set -u
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
source "$here/../lib/assert.sh"
export SHERPA_CONFIG_DIR="$tmp/cfg" HOME="$tmp/home"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
mkdir -p "$HOME" "$SHERPA_CONFIG_DIR/inventory/p"
conf="$SHERPA_CONFIG_DIR/inventory/p/settings.yaml"
repo="$tmp/repo"

# settings <repo> <path> [create]: writes settings.yaml; an empty arg leaves that key out
settings() {
  { [ -z "$1" ] || echo "repo: $1"; echo "worktree:"; [ -z "$2" ] || echo "  path: $2"
    [ -z "${3:-}" ] || { echo "  create: |"; sed 's/^/    /' <<<"$3"; }; } >"$conf"
}
run() { out=$(bash "$here/ensure-worktree.sh" p "$@" 2>"$tmp/err" <<<leak); rc=$?; err=$(cat "$tmp/err"); }
pack_in() { mkdir -p "$1/.sherpa"; echo "name: ${2:-p}" >"$1/.sherpa/project.yaml"; }

# an existing path is reused: create must not run, and the path is printed
pack_in "$tmp/wt/T-1"
settings "$repo" "$tmp/wt/\$SHERPA_ID" "touch $tmp/ran"
run T-1; assert_exit "reuse exit" "$rc" 0
assert_eq "reuse stdout" "$out" "$tmp/wt/T-1"
[ ! -e "$tmp/ran" ] || { echo "FAIL [reuse]: create ran"; fail=1; }

# a missing path is made by create: in repo, env set, stdin empty, chatter off stdout
mkdir -p "$repo"
settings "$repo" "$tmp/wt/\${SHERPA_ID}-x" "echo chatter
echo \"\$PWD \$SHERPA_ID \$SHERPA_WORKTREE \$(cat | wc -c)\" >$tmp/seen
mkdir -p \"\$SHERPA_WORKTREE/.sherpa\"; echo 'name: p' >\"\$SHERPA_WORKTREE/.sherpa/project.yaml\""
run T-2; assert_exit "fake create exit" "$rc" 0
assert_eq "chatter off stdout" "$out" "$tmp/wt/T-2-x"
assert_contains "chatter on stderr" "$err" "chatter"
assert_eq "create context" "$(cat "$tmp/seen")" "$repo T-2 $tmp/wt/T-2-x 0"

# a leading ~ is expanded
pack_in "$HOME/tilde/T-3"
settings "$repo" '~/tilde/$SHERPA_ID'
run T-3; assert_eq "tilde" "$out" "$HOME/tilde/T-3"

# the default create makes a real worktree (the branch holds the pack file)
git init -q "$repo" && pack_in "$repo" && git -C "$repo" add -A && git -C "$repo" commit -qm init
settings "$repo" "$tmp/wt/\$SHERPA_ID"
run T-4; assert_exit "default create exit" "$rc" 0
assert_eq "default create path" "$out" "$tmp/wt/T-4"
assert_eq "real worktree branch" "$(git -C "$tmp/wt/T-4" branch --show-current)" "T-4"
run T-4; assert_eq "second call reuses" "$out" "$tmp/wt/T-4"

# failures: exit 1 with a distinct message each
msgs=()
bad() { # <label> <want> <ID>
  local l=$1 w=$2; shift 2; run "$@"
  assert_exit "$l exit" "$rc" 1; assert_eq "$l stdout" "$out" ""; assert_contains "$l msg" "$err" "$w"
  msgs+=("$err")
}
bad "bad ID" "invalid ID" 'a/b'; bad "leading dot ID" "invalid ID" .hidden
mv "$conf" "$conf.off"; bad "no settings" "no settings.yaml" T-5; mv "$conf.off" "$conf"
settings "" "$tmp/wt/\$SHERPA_ID"; bad "no repo" "no repo" T-5
settings "$repo" ""; bad "no path" "no worktree.path" T-5
settings "$repo" "$tmp/wt/\$SHERPA_ID" "exit 3"; bad "create failed" "create failed" T-6
settings "$repo" "$tmp/wt/\$SHERPA_ID" "true"; bad "still missing" "still missing" T-7
mkdir -p "$tmp/wt/T-8"; settings "$repo" "$tmp/wt/\$SHERPA_ID"; bad "no pack" "no pack found" T-8
pack_in "$tmp/wt/T-9" other
bad "other pack" "detects pack 'other'" T-9
n=$(printf '%s\n' "${msgs[@]}" | sed "s/T-[0-9]//; s/$(printf '%s' "$tmp" | sed 's/[.[\*^$/]/\\&/g')[^ ]*//" | sort -u | wc -l)
assert_eq "messages distinct" "$n" "${#msgs[@]}"

mkdir -p "$SHERPA_CONFIG_DIR/inventory/a b"; settings "$repo" "$tmp/wt/\$SHERPA_ID"; cp "$conf" "$SHERPA_CONFIG_DIR/inventory/a b/"
out=$(bash "$here/ensure-worktree.sh" "a b" T-1 2>&1); assert_exit "bad pack name" $? 1; assert_contains "bad pack msg" "$out" "no settings.yaml"
bash "$here/ensure-worktree.sh" p >/dev/null 2>&1; assert_exit "one arg" $? 2

[ "$fail" -eq 0 ] && echo "PASS: all worktree cases" || { echo FAILED; exit 1; }
