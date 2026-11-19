#!/usr/bin/env bash
# Usage: ensure-worktree.sh <project> <ID>
# Input:  <inventory_dir>/<project>/settings.yaml with `repository` (the main checkout) and
#   `worktree.pattern`, each a map with exactly one of `path` or `command` (see resolve_location):
#   `path` expands a leading ~ and $NAME / ${NAME} with TICKET_ID set (nothing is run, an unset
#   variable is an error); `command` runs via bash -c (repository.command in $HOME,
#   worktree.pattern.command in the repository; TICKET_ID exported) and prints one absolute path.
#   Optional `worktree.create` (shell command, default: git worktree add -b "$TICKET_ID" "$TICKET_WORKTREE").
#   Optional `source` (a file or a list): sourced, in order, before every command above, create
#   included, with stdout sent to stderr (see scripts/lib/source-cmd.sh). A bad `source` value, a
#   missing file or a file whose sourcing fails stops the call with a reason naming it.
# Output: prints the ticket's absolute worktree path. It CREATES the worktree by running
#   `worktree.create` via bash -c in `repository` (TICKET_ID, TICKET_WORKTREE exported, stdin
#   /dev/null, its stdout sent to stderr) when the path is missing; an existing path is reused.
#   The path is derived on every call, never stored. Needs yq.
#   The folder (reused or just made) must be a separate worktree root of `repository` (same git
#   common dir, its own top level, not the main checkout); the path is printed physically resolved.
# Exit:   0 worktree ready; 1 with a one-line reason on stderr (no settings.yaml, a key that is not
#   exactly one of path or command, a command that fails or prints other than one path, a path
#   that is not absolute, bad ID, repository missing, create failed, dir still missing, the main
#   checkout, not a worktree root of repository); 2 usage.
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$here/../lib/inventory.sh"

[ $# -eq 2 ] || { echo "usage: ensure-worktree.sh <project> <ID>" >&2; exit 2; }
project=$1 id=$2
die() { echo "ensure-worktree: $*" >&2; exit 1; }
conf="$(inventory_dir)/$project/settings.yaml"
valid_id "$project" || conf=/nonexistent
[ -f "$conf" ] || die "no settings.yaml for project: $project"
valid_id "$id" || die "invalid ID: $id (letters, digits, . _ - only)"

get() { yq ".$1 // \"\"" "$conf" 2>/dev/null || die "settings.yaml is not valid YAML: $conf"; }
create=$(get worktree.create); [ -n "$create" ] || create='git worktree add -b "$TICKET_ID" "$TICKET_WORKTREE"'
source_cmd "$conf" "$id" true || die "$SOURCE_ERR"
resolve_location "$conf" repository "$id" "$HOME" || die "$LOCATION_ERR"
repository=$LOCATION
[ -d "$repository" ] || die "repository is not a directory: $repository"
resolve_location "$conf" worktree.pattern "$id" "$repository" || die "$LOCATION_ERR"
path=$LOCATION
if [ ! -d "$path" ]; then
  source_cmd "$conf" "$id" "$create" || die "$SOURCE_ERR"
  (cd "$repository" && TICKET_ID=$id TICKET_WORKTREE=$path "${SHELL_CMD[@]}" </dev/null >&2) ||
    die "worktree.create failed for $id"
  [ -d "$path" ] || die "worktree.create ran but $path is still missing"
fi
path=$(cd "$path" && pwd -P); repository=$(cd "$repository" && pwd -P)

g() { env -u GIT_DIR -u GIT_COMMON_DIR -u GIT_WORK_TREE git -C "$@"; }  # an inherited GIT_DIR must not decide
common() { # <dir>: prints the absolute git common dir, or fails when <dir> is not in a git repo
  local d; d=$(g "$1" rev-parse --git-common-dir 2>/dev/null) || return 1
  case "$d" in /*) ;; *) d=$1/$d ;; esac
  (cd "$d" && pwd -P)
}
top() { local t; t=$(g "$1" rev-parse --show-toplevel 2>/dev/null) && (cd "$t" && pwd -P); }
[ "$path" != "$repository" ] ||
  die "$path is the main checkout; worktree.pattern must point to a separate worktree"
mine=$(common "$path") && theirs=$(common "$repository") && [ "$mine" = "$theirs" ] &&
  [ "$(top "$path")" = "$path" ] || die "$path is not a git worktree of $repository"
echo "$path"
