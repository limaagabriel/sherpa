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
repository="$tmp/repo"
git init -q "$repository"; git -C "$repository" commit -q --allow-empty -m init

# settings <repository path> <pattern path> [create]: writes settings.yaml; an empty arg leaves that key out
settings() {
  { [ -z "$1" ] || printf 'repository:\n  path: %s\n' "$1"; echo "worktree:"
    [ -z "$2" ] || printf '  pattern:\n    path: %s\n' "$2"
    [ -z "${3:-}" ] || { echo "  create: |"; sed 's/^/    /' <<<"$3"; }; } >"$conf"
}
# settings_cmd <repository yaml lines> <pattern yaml lines>: writes the given lines under each key
settings_cmd() { { echo "repository:"; sed 's/^/  /' <<<"$1"; printf 'worktree:\n  pattern:\n'; sed 's/^/    /' <<<"$2"; } >"$conf"; }
run() { out=$(bash "$here/ensure-worktree.sh" p "$@" 2>"$tmp/err" <<<leak); rc=$?; err=$(cat "$tmp/err"); }
wt_add() { git -C "$repository" worktree add -q --detach "$1"; }  # <path>: a real worktree of the repo

# an existing path is reused: create must not run, and the path is printed
wt_add "$tmp/wt/T-1"
settings "$repository" "$tmp/wt/\$TICKET_ID" "touch $tmp/ran"
run T-1; assert_exit "reuse exit" "$rc" 0
assert_eq "reuse stdout" "$out" "$tmp/wt/T-1"
[ ! -e "$tmp/ran" ] || { echo "FAIL [reuse]: create ran"; fail=1; }

# a missing path is made by create: in repository, env set, stdin empty, chatter off stdout
settings "$repository" "$tmp/wt/\${TICKET_ID}-x" "echo chatter
echo \"\$PWD \$TICKET_ID \$TICKET_WORKTREE \$(cat | wc -c)\" >$tmp/seen
git worktree add -q --detach \"\$TICKET_WORKTREE\""
run T-2; assert_exit "fake create exit" "$rc" 0
assert_eq "chatter off stdout" "$out" "$tmp/wt/T-2-x"
assert_contains "chatter on stderr" "$err" "chatter"
assert_eq "create context" "$(cat "$tmp/seen")" "$repository T-2 $tmp/wt/T-2-x 0"

# a leading ~ is expanded
wt_add "$HOME/tilde/T-3"
settings "$repository" '~/tilde/$TICKET_ID'
run T-3; assert_eq "tilde" "$out" "$HOME/tilde/T-3"

# $HOME, ${HOME} and a custom variable expand in worktree.pattern.path and repository; ~ in repository
wt_add "$HOME/w/T-3"
settings "$repository" '$HOME/w/$TICKET_ID'; run T-3; assert_eq "\$HOME path" "$out" "$HOME/w/T-3"
settings "$repository" '${HOME}/w/${TICKET_ID}'; run T-3; assert_eq "\${HOME} path" "$out" "$HOME/w/T-3"
ln -s "$repository" "$HOME/repo-link"
mk_wt="git worktree add -q --detach \"\$TICKET_WORKTREE\""
settings '~/repo-link' "$tmp/wt/\$TICKET_ID" "pwd -P >$tmp/where; $mk_wt"; run T-10
assert_exit "~ in repository exit" "$rc" 0; assert_eq "~ in repository cwd" "$(cat "$tmp/where" 2>/dev/null)" "$repository"
rm -rf "$tmp/wt/T-11" "$tmp/where"; settings '$TEST_REPO_DIR/repo' "$tmp/wt/\$TICKET_ID" "pwd -P >$tmp/where; $mk_wt"
TEST_REPO_DIR=$tmp run T-11
assert_exit "custom var in repository exit" "$rc" 0; assert_eq "custom var in repository cwd" "$(cat "$tmp/where" 2>/dev/null)" "$repository"

# the default create makes a real worktree
settings "$repository" "$tmp/wt/\$TICKET_ID"
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
settings "" "$tmp/wt/\$TICKET_ID"; bad "no repository" "repository needs exactly one of path or command" T-5
settings "$repository" ""; bad "no pattern" "worktree.pattern needs exactly one of path or command" T-5
settings "$repository" "$tmp/wt/\$TICKET_ID" "exit 3"; bad "create failed" "create failed" T-6
settings "$repository" "$tmp/wt/\$TICKET_ID" "true"; bad "still missing" "still missing" T-7
# a folder at the path that is not a worktree of repository is refused, created or reused
mkdir -p "$tmp/wt/T-8"; settings "$repository" "$tmp/wt/\$TICKET_ID"; bad "plain dir" "T-8 is not a git worktree of $repository" T-8
git init -q "$tmp/other"; git -C "$tmp/other" commit -q --allow-empty -m init
git -C "$tmp/other" worktree add -q --detach "$tmp/wt/T-9"; bad_same() { bad "$@"; unset 'msgs[-1]'; }  # same message as the case above: not another distinct one
bad_same "other repo worktree" "is not a git worktree of" T-9
git clone -q "$repository" "$tmp/wt/T-14"; bad_same "clone of repo" "is not a git worktree of" T-14
settings "$repository" "$tmp/wt/\$TICKET_ID" "mkdir -p \"\$TICKET_WORKTREE\""; bad_same "create made a plain dir" "is not a git worktree of" T-15
mkdir -p "$repository/sub/T-16" "$tmp/wt/T-17/sub"; settings "$repository" "$repository/sub/\$TICKET_ID"
bad_same "subfolder of main checkout" "is not a git worktree of" T-16
wt_add "$tmp/wt/T-17x"; mkdir -p "$tmp/wt/T-17x/sub/T-18"; settings "$repository" "$tmp/wt/T-17x/sub/\$TICKET_ID"
bad_same "subdir of a worktree" "is not a git worktree of" T-18
settings "$repository" "$repository"; bad "main checkout" "is the main checkout" T-19
ln -s "$repository" "$tmp/repo-alias"; settings "$repository" "$tmp/repo-alias"; bad_same "main checkout via symlink" "is the main checkout" T-19
ln -s "$tmp/wt/T-1" "$tmp/wt/link-1"; settings "$repository" "$tmp/wt/link-1"; run T-20
assert_exit "symlinked worktree exit" "$rc" 0; assert_eq "symlinked worktree physical" "$out" "$tmp/wt/T-1"
# an inherited GIT_DIR must not decide the check
settings "$repository" "$tmp/wt/\$TICKET_ID"
GIT_DIR="$repository/.git" bad_same "GIT_DIR plain dir" "is not a git worktree of" T-8
GIT_DIR="$repository/.git" run T-1; assert_exit "GIT_DIR real worktree exit" "$rc" 0; assert_eq "GIT_DIR real worktree" "$out" "$tmp/wt/T-1"
settings "$tmp/nope" "$tmp/wt/\$TICKET_ID"; bad "repository missing" "repository is not a directory" T-1
# an unset variable names itself; nothing in a path value is ever run
settings "$repository" '$NOPE_UNSET/$TICKET_ID'; bad "unset in path" "worktree.pattern.path uses unset variable \$NOPE_UNSET" T-5
settings '${NOPE_REPO}/r' "$tmp/wt/\$TICKET_ID"; bad "unset in repository" "repository.path uses unset variable \$NOPE_REPO" T-5
settings "$repository" "\$(touch $tmp/pwned)/\$TICKET_ID"; bad "cmd subst" "must be absolute" T-5
settings "$repository" "'\`touch $tmp/pwned2\`/\$TICKET_ID'"; bad "backtick" "must be absolute" T-5
wt_add "$tmp/wt/\$(touch $tmp/pwned3)"
settings "$repository" "$tmp/wt/\$(touch $tmp/pwned3)"; run T-13  # a folder with that literal name
assert_exit "cmd subst in abs path exit" "$rc" 0; assert_eq "cmd subst in abs path literal" "$out" "$tmp/wt/\$(touch $tmp/pwned3)"
[ ! -e "$tmp/pwned" ] && [ ! -e "$tmp/pwned2" ] && [ ! -e "$tmp/pwned3" ] || { echo "FAIL [path value ran code]"; fail=1; }
n=$(printf '%s\n' "${msgs[@]}" | sed "s/T-[0-9]//; s/$(printf '%s' "$tmp" | sed 's/[.[\*^$/]/\\&/g')[^ ]*//" | sort -u | wc -l)
assert_eq "messages distinct" "$n" "${#msgs[@]}"

# command form: a map with exactly one of path or command, for repository and worktree.pattern
blk() { printf 'command: |\n'; sed 's/^/  /' <<<"$1"; }  # <shell text>: a YAML command: block
wt_add "$tmp/wt/T-30"
settings_cmd "$(blk "echo \"\$(pwd -P) \$TICKET_ID \$(cat | wc -c)\" >$tmp/seen-repo; echo chatter >&2; echo $repository")" "path: $tmp/wt/\$TICKET_ID"
run T-30; assert_exit "repository.command exit" "$rc" 0; assert_eq "repository.command stdout" "$out" "$tmp/wt/T-30"
assert_eq "repository.command context" "$(cat "$tmp/seen-repo")" "$(cd "$HOME" && pwd -P) T-30 0"
assert_contains "repository.command stderr passes" "$err" "chatter"
rm -rf "$tmp/seen-pat"
settings_cmd "path: $repository" "$(blk "echo \"\$(pwd -P) \$TICKET_ID \$(cat | wc -c)\" >$tmp/seen-pat; echo note >&2; echo $tmp/wt/cmd-\$TICKET_ID")"
run T-31; assert_exit "pattern.command exit" "$rc" 0; assert_eq "pattern.command stdout" "$out" "$tmp/wt/cmd-T-31"
assert_eq "pattern.command context" "$(cat "$tmp/seen-pat")" "$repository T-31 0"
assert_contains "pattern.command stderr passes" "$err" "note"
assert_eq "pattern.command made the worktree" "$(git -C "$tmp/wt/cmd-T-31" branch --show-current)" "T-31"
settings_cmd "$(blk "printf %s $repository")" "$(blk "printf %s $tmp/wt/cmd-\$TICKET_ID")"  # no trailing newline is fine
run T-31; assert_exit "no trailing newline exit" "$rc" 0; assert_eq "no trailing newline" "$out" "$tmp/wt/cmd-T-31"
mkdir -p "$tmp/wt/lit"; wt_add "$tmp/wt/\$(touch $tmp/pwned4)"
settings_cmd "path: $repository" "$(blk "printf '%s\n' '$tmp/wt/\$(touch $tmp/pwned4)'")"
run T-32; assert_exit "command output literal exit" "$rc" 0
assert_eq "command output literal" "$out" "$tmp/wt/\$(touch $tmp/pwned4)"
[ ! -e "$tmp/pwned4" ] || { echo "FAIL [command output was run]"; fail=1; }
P="path: $tmp/wt/\$TICKET_ID"; R="path: $repository"
settings_cmd "$R
$(blk "echo $repository")" "$P"; bad "repository both" "settings.yaml: repository needs exactly one of path or command" T-33
settings_cmd "$R" "$P
$(blk "echo x")"; bad "pattern both" "settings.yaml: worktree.pattern needs exactly one of path or command" T-33
settings_cmd "{}" "$P"; bad_same "repository neither" "settings.yaml: repository needs exactly one of path or command" T-33
settings_cmd "$R" "{}"; bad_same "pattern neither" "settings.yaml: worktree.pattern needs exactly one of path or command" T-33
settings_cmd "path: ''" "$P"; bad_same "repository empty path" "repository needs exactly one of path or command" T-33
printf 'repository: %s\nworktree:\n  pattern:\n    path: %s\n' "$repository" "$tmp/wt/\$TICKET_ID" >"$conf"
bad "old scalar repository" "repository needs exactly one of path or command (write \`repository:\` as a map" T-33
printf 'repository:\n  path: %s\nworktree:\n  pattern: %s\n' "$repository" "$tmp/wt/x" >"$conf"
bad "old scalar pattern" "worktree.pattern needs exactly one of path or command (write" T-33
printf 'repository:\n  path: %s\nworktree:\n  path: %s\n' "$repository" "$tmp/wt/\$TICKET_ID" >"$conf"
bad_same "old worktree.path" "worktree.pattern needs exactly one of path or command" T-33
settings_cmd "$(blk "echo rel/repo")" "$P"; bad "repository relative" "repository.command must be absolute: rel/repo" T-33
settings_cmd "$R" "$(blk "echo wt/x")"; bad "pattern relative" "worktree.pattern.command must be absolute: wt/x" T-33
settings_cmd "path: rel/repo" "$P"; bad "repository path relative" "repository.path must be absolute: rel/repo" T-33
settings_cmd "$R" "path: rel/\$TICKET_ID"; bad "pattern path relative" "worktree.pattern.path must be absolute: rel/T-33" T-33
settings_cmd "$(blk "echo $repository; echo $repository")" "$P"; bad "repository two lines" "repository.command must print one path" T-33
settings_cmd "$R" "$(blk "echo $tmp/wt/a; echo $tmp/wt/b")"; bad "pattern two lines" "worktree.pattern.command must print one path" T-33
settings_cmd "$R" "$(blk "echo $tmp/wt/a; echo")"; bad_same "pattern blank second line" "worktree.pattern.command must print one path" T-33
settings_cmd "$(blk "true")" "$P"; bad_same "repository prints nothing" "repository.command must print one path" T-33
settings_cmd "$R" "$(blk "echo")"; bad_same "pattern prints a blank line" "worktree.pattern.command must print one path" T-33
settings_cmd "$(blk "exit 7")" "$P"; bad "repository command fails" "repository.command failed (exit 7)" T-33
settings_cmd "$R" "$(blk "echo oops >&2; exit 4")"; bad "pattern command fails" "worktree.pattern.command failed (exit 4)" T-33
assert_contains "failing command stderr passes" "$err" "oops"

# --- source: files are sourced, in order, before every shell command; their stdout goes to stderr
sset() { printf '%s\n' "$@" >>"$conf"; }  # <yaml line>...: appended to settings.yaml (after settings_cmd)
create_cmd() { sset "  create: '$1'"; }
printf 'repo_path() { echo %q; }\nwt_path() { echo %q/"$1"; }\nmk_wt() { git worktree add -q --detach "$1"; }\nSEQ=a\necho noise\n' \
  "$repository" "$tmp/wt" >"$tmp/lp.sh"
printf 'SEQ+=b\n' >"$tmp/lp2.sh"
rm -rf "$tmp/wt/T-40"
settings_cmd "$(blk 'echo "$SEQ" >'"$tmp"'/seq; repo_path')" "$(blk 'wt_path "$TICKET_ID"')"; create_cmd 'mk_wt "$TICKET_WORKTREE"'
sset "source:" "  - $tmp/lp.sh" "  - $tmp/lp2.sh"
run T-40; assert_exit "source all three exit" "$rc" 0; assert_eq "source all three stdout" "$out" "$tmp/wt/T-40"
assert_eq "source order" "$(cat "$tmp/seq")" "ab"; assert_contains "source stdout goes to stderr" "$err" "noise"
assert_eq "source made the worktree" "$(git -C "$tmp/wt/T-40" rev-parse --is-inside-work-tree)" "true"
# ~ and $VAR (TICKET_ID too) expand; a single string works; the same file name in a list is fine
cp "$tmp/lp.sh" "$HOME/lp-home.sh"; cp "$tmp/lp.sh" "$tmp/lp-T-41.sh"; rm -rf "$tmp/wt/T-41"
settings_cmd "$(blk repo_path)" "$(blk 'wt_path "$TICKET_ID"')"; create_cmd 'mk_wt "$TICKET_WORKTREE"'; sset "source: ~/lp-home.sh"
run T-41; assert_exit "source ~ exit" "$rc" 0; assert_eq "source ~" "$out" "$tmp/wt/T-41"
rm -rf "$tmp/wt/T-41"; git -C "$repository" worktree prune; sed -i '$d' "$conf"; sset 'source: $SRC_BASE/lp-${TICKET_ID}.sh'; SRC_BASE=$tmp run T-41
assert_exit "source \$VAR exit" "$rc" 0; assert_eq "source \$VAR" "$out" "$tmp/wt/T-41"
# a missing file, a file that fails, a bad shape and an unset variable: each fails with a clear reason
settings_cmd "$(blk 'echo should-not-run; echo /x')" "path: $tmp/wt/\$TICKET_ID"; sset "source: $tmp/nope.sh"
bad "source missing (repository.command)" "settings.yaml: source $tmp/nope.sh failed" T-42
assert_not_contains "source missing: command not run" "$err" "should-not-run"
printf 'return 3\n' >"$tmp/fails.sh"; settings_cmd "path: $repository" "$(blk 'echo /x')"; sset "source:" "  - $tmp/lp.sh" "  - $tmp/fails.sh"
bad "source fails (pattern.command)" "settings.yaml: source $tmp/fails.sh failed" T-42
settings "$repository" "$tmp/wt/\$TICKET_ID" "touch $tmp/create-ran"; sset "source: $tmp/nope.sh"
bad "source missing (create)" "settings.yaml: source $tmp/nope.sh failed" T-42
[ ! -e "$tmp/create-ran" ] || { echo "FAIL [create ran despite a failed source]"; fail=1; }
for v in '{a: b}' '5' '[a, {b: c}]' '[a, 7]' "''" '[""]' '"a\nb"' '[[a]]'; do
  settings "$repository" "$tmp/wt/\$TICKET_ID"; sset "source: $v"
  bad_same "source bad shape $v" "settings.yaml: source must be a file or a list of files" T-42
done
settings "$repository" "$tmp/wt/\$TICKET_ID"; sset 'source: $NOPE_SRC/x.sh'; bad_same "source unset var" 'source uses unset variable $NOPE_SRC' T-42
# a path with spaces and $(...) text is a file name, never code
mkdir -p "$tmp/we ird \$(touch $tmp/pwned5)"; printf 'repo_path() { echo %q; }\n' "$repository" >"$tmp/we ird \$(touch $tmp/pwned5)/f.sh"
settings_cmd "$(blk repo_path)" "path: $tmp/wt/\$TICKET_ID"; sset "source: '$tmp/we ird \$(touch $tmp/pwned5)/f.sh'"
run T-1; assert_exit "source odd path exit" "$rc" 0; assert_eq "source odd path" "$out" "$tmp/wt/T-1"
[ ! -e "$tmp/pwned5" ] || { echo "FAIL [source path was run]"; fail=1; }
# positional parameters and $0 are as with plain bash -c; no source: bash -c exactly
settings_cmd "$(blk 'echo "[$#][$0]" >'"$tmp"'/pos; echo '"$repository")" "path: $tmp/wt/\$TICKET_ID"; sset "source: $tmp/lp2.sh"
run T-1; assert_eq "source keeps \$# and \$0" "$(cat "$tmp/pos")" "[0][bash]"

mkdir -p "$SHERPA_CONFIG_DIR/inventory/a b"; settings "$repository" "$tmp/wt/\$TICKET_ID"; cp "$conf" "$SHERPA_CONFIG_DIR/inventory/a b/"
out=$(bash "$here/ensure-worktree.sh" "a b" T-1 2>&1); assert_exit "bad project name" $? 1; assert_contains "bad project msg" "$out" "no settings.yaml"
bash "$here/ensure-worktree.sh" p >/dev/null 2>&1; assert_exit "one arg" $? 2

[ "$fail" -eq 0 ] && echo "PASS: all worktree cases" || { echo FAILED; exit 1; }
