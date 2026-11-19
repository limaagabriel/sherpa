#!/usr/bin/env bash
# Usage: ensure-board.sh [<project>] [--repository <path>]
# Input:  run in a repo (any git repository). `repository` is the main
#   worktree of --repository (else $PWD). <project>, the board's ID, defaults to that folder's name.
# Output: creates <inventory_dir>/<project>/ and its six stage folders if missing, writes
#   settings.yaml ONLY when absent (repository, worktree.path, tools), builds board.md, prints the
#   project dir.
# Exit:   0 ready; 1 with a reason on stderr (not a git repo, bad or unusable project name);
#   2 usage. Needs yq and git.
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$here/../lib/inventory.sh"

usage() { echo "usage: ensure-board.sh [<project>] [--repository <path>]" >&2; exit 2; }
die() { echo "ensure-board: $*" >&2; exit 1; }
project= repository_arg= have_project=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repository) [ $# -ge 2 ] || usage; repository_arg=$2; shift 2 ;;
    -*) usage ;;
    *) [ "$have_project" -eq 0 ] || usage; project=$1 have_project=1; shift ;;
  esac
done

base=${repository_arg:-$PWD}
[ -d "$base" ] || die "not a directory: $base"
repository=$(git -C "$base" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' | sed -n 1p) ||
  repository=
[ -n "$repository" ] || die "not a git repo: $base (run in a repo or pass --repository)"
[ "$have_project" -eq 1 ] || project=$(basename "$repository")
valid_id "$project" || die "invalid project name: '$project' (letters, digits, . _ - only); pass a name: sherpa init <project>"

dir="$(inventory_dir)/$project"
for s in "${STAGES[@]}"; do mkdir -p "$dir/$s"; done

q() { local s=\'; printf "'%s'" "${1//$s/$s$s}"; }
if [ ! -e "$dir/settings.yaml" ] && [ ! -L "$dir/settings.yaml" ]; then
  wt="$(dirname "$repository")/$project-worktrees/\$TICKET_ID"
  tpl=$(cat <<'EOF2'
repository: @REPOSITORY@
# worktree.create and runner run arbitrary shell: keep this file yours.
worktree:
  path: @WT@
  # create: lp worktree add "$TICKET_ID"
  # default: git worktree add -b "$TICKET_ID" "$TICKET_WORKTREE"
# extra commands the headless agent may run, added to the default --allowedTools
# (never allow git push), e.g.
#   - Bash(./gradlew test:*)
tools: []
# runner: replaces the whole default command (tools is then ignored); runs via bash -c in the
# ticket's worktree with TICKET_STAGE and TICKET_FILE set, and must print the STATUS line
EOF2
)
  tpl=${tpl//@REPOSITORY@/"$(q "$repository")"}; tpl=${tpl//@WT@/"$(q "$wt")"}
  printf '%s\n' "$tpl" >"$dir/settings.yaml"
fi

bash "$here/build-board.sh" "$project" >/dev/null
echo "$dir"
