#!/usr/bin/env bash
# Usage: ensure-worktree.sh <project> <ID>
# Input:  <inventory_dir>/<project>/settings.yaml with `repository` (main worktree) and `worktree.path`
#   (required); both keys expand a leading ~ and any $NAME / ${NAME} from the environment, with
#   TICKET_ID set (see expand_path; nothing is run, an unset variable is an error), optional
#   `worktree.create` (shell command, default: git worktree add -b "$TICKET_ID" "$TICKET_WORKTREE").
# Output: prints the ticket's absolute worktree path. It CREATES the worktree by running
#   `worktree.create` via bash -c in `repository` (TICKET_ID, TICKET_WORKTREE exported, stdin
#   /dev/null, its stdout sent to stderr) when the path is missing; an existing path is reused.
#   The path is derived on every call, never stored. Needs yq.
#   The folder (reused or just made) must be a separate worktree root of `repository` (same git
#   common dir, its own top level, not the main checkout); the path is printed physically resolved.
# Exit:   0 worktree ready; 1 with a one-line reason on stderr (no settings.yaml, missing key,
#   bad ID, repository missing, create failed, dir still missing, the main checkout, not a
#   worktree root of repository); 2 usage.
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
repository=$(get repository); raw=$(get worktree.path); create=$(get worktree.create)
[ -n "$repository" ] || die "settings.yaml has no repository"
[ -n "$raw" ] || die "settings.yaml has no worktree.path"
[ -n "$create" ] || create='git worktree add -b "$TICKET_ID" "$TICKET_WORKTREE"'

expand() { # <key> <raw>: prints the expansion, or dies naming the unset variable
  local v; v=$(TICKET_ID=$id expand_path "$2") || die "settings.yaml: $1 uses unset variable \$$v"
  printf '%s\n' "$v"
}
repository=$(expand repository "$repository"); path=$(expand worktree.path "$raw")
case "$path" in /*) ;; *) die "worktree.path must be absolute after expansion: $path" ;; esac

[ -d "$repository" ] || die "repository is not a directory: $repository"
if [ ! -d "$path" ]; then
  (cd "$repository" && TICKET_ID=$id TICKET_WORKTREE=$path bash -c "$create" </dev/null >&2) ||
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
  die "$path is the main checkout; worktree.path must point to a separate worktree"
mine=$(common "$path") && theirs=$(common "$repository") && [ "$mine" = "$theirs" ] &&
  [ "$(top "$path")" = "$path" ] || die "$path is not a git worktree of $repository"
echo "$path"
