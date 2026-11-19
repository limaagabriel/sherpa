#!/usr/bin/env bash
# Usage: ensure-worktree.sh <pack> <ID>
# Input:  <inventory_dir>/<pack>/settings.yaml with `repo` (main worktree) and `worktree.path`
#   (required; a leading ~ and $SHERPA_ID / ${SHERPA_ID} are expanded, nothing else), optional
#   `worktree.create` (shell command, default: git worktree add -b "$SHERPA_ID" "$SHERPA_WORKTREE").
# Output: prints the ticket's absolute worktree path. It CREATES the worktree by running
#   `worktree.create` via bash -c in `repo` (SHERPA_ID, SHERPA_WORKTREE exported, stdin
#   /dev/null, its stdout sent to stderr) when the path is missing; an existing path is reused.
#   The path is derived on every call, never stored. Needs yq.
# Exit:   0 worktree ready and pack detected there; 1 with a one-line reason on stderr (no
#   settings.yaml, missing key, bad ID, create failed, dir still missing, no pack or another
#   pack found there); 2 usage.
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$here/../lib/inventory.sh"

[ $# -eq 2 ] || { echo "usage: ensure-worktree.sh <pack> <ID>" >&2; exit 2; }
pack=$1 id=$2
die() { echo "ensure-worktree: $*" >&2; exit 1; }
conf="$(inventory_dir)/$pack/settings.yaml"
case "$pack" in '' | */* | .*) conf=/nonexistent ;; esac
[ -f "$conf" ] || die "no settings.yaml for pack: $pack"
valid_id "$id" || die "invalid ID: $id (letters, digits, . _ - only)"

get() { yq ".$1 // \"\"" "$conf" 2>/dev/null || die "settings.yaml is not valid YAML: $conf"; }
repo=$(get repo); raw=$(get worktree.path); create=$(get worktree.create)
[ -n "$repo" ] || die "settings.yaml has no repo"
[ -n "$raw" ] || die "settings.yaml has no worktree.path"
[ -n "$create" ] || create='git worktree add -b "$SHERPA_ID" "$SHERPA_WORKTREE"'

path=$raw
case "$path" in "~" | "~/"*) path="$HOME${path#"~"}" ;; esac
path=${path//'${SHERPA_ID}'/$id}; path=${path//'$SHERPA_ID'/$id}
case "$path" in /*) ;; *) die "worktree.path must be absolute after expansion: $path" ;; esac

if [ ! -d "$path" ]; then
  [ -d "$repo" ] || die "repo is not a directory: $repo"
  (cd "$repo" && SHERPA_ID=$id SHERPA_WORKTREE=$path bash -c "$create" </dev/null >&2) ||
    die "worktree.create failed for $id"
  [ -d "$path" ] || die "worktree.create ran but $path is still missing"
fi
path=$(cd "$path" && pwd)

found=$(bash "$here/../pack/find.sh" "$path") ||
  die "no pack found in $path; give the worktree a .sherpa/project.yaml or make the pack's detect match worktree.path"
name=$(yq '.name // ""' "$found")
[ "$name" = "$pack" ] ||
  die "$path detects pack '$name', not '$pack'; make the pack's detect match worktree.path"
echo "$path"
