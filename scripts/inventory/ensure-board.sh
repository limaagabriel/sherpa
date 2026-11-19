#!/usr/bin/env bash
# Usage: ensure-board.sh [<pack>] [--repo <path>]
# Input:  run in a repo. <pack> defaults to `name` of the config find.sh finds for the repo
#   (--repo, else $PWD); `repo` is that directory's main worktree. An explicit <pack> is used as-is.
# Output: creates <inventory_dir>/<pack>/ and its six stage folders if missing, writes
#   settings.yaml ONLY when absent (repo, worktree.path, runner), builds board.md, prints the
#   pack dir. Warns on stderr when a workspace pack's detect misses worktree.path.
# Exit:   0 ready; 1 with a reason on stderr (no pack found, not a git repo, bad pack name);
#   2 usage. Needs yq and git.
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$here/../lib/inventory.sh"

usage() { echo "usage: ensure-board.sh [<pack>] [--repo <path>]" >&2; exit 2; }
die() { echo "ensure-board: $*" >&2; exit 1; }
pack= repo_arg= have_pack=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) [ $# -ge 2 ] || usage; repo_arg=$2; shift 2 ;;
    -*) usage ;;
    *) [ "$have_pack" -eq 0 ] || usage; pack=$1 have_pack=1; shift ;;
  esac
done

base=${repo_arg:-$PWD}
[ -d "$base" ] || die "not a directory: $base"
repo=$(git -C "$base" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' | sed -n 1p) ||
  repo=
[ -n "$repo" ] || die "not a git repo: $base (run in a repo or pass --repo)"
config=$(bash "$here/../pack/find.sh" "$base" || true)
if [ "$have_pack" -eq 0 ]; then
  [ -n "$config" ] || die "no pack found for $base; add .sherpa/project.yaml or pass <pack>"
  pack=$(yq '.name // ""' "$config")
fi
valid_id "$pack" || die "invalid pack name: '$pack' (letters, digits, . _ - only)"

dir="$(inventory_dir)/$pack"
for s in "${STAGES[@]}"; do mkdir -p "$dir/$s"; done

q() { local s=\'; printf "'%s'" "${1//$s/$s$s}"; }
if [ ! -e "$dir/settings.yaml" ] && [ ! -L "$dir/settings.yaml" ]; then
  wt="$(dirname "$repo")/$pack-worktrees/\$SHERPA_ID"
  tpl=$(cat <<'EOF2'
repo: @REPO@
# runner and worktree.create run arbitrary shell: keep this file yours. The pack's `detect`
# must match worktree.path, or ensure-worktree.sh refuses the new worktree.
worktree:
  path: @WT@
  # create: lp worktree add "$SHERPA_ID"
  # default: git worktree add -b "$SHERPA_ID" "$SHERPA_WORKTREE"
# --allowedTools: add your build/test commands (e.g. Bash(npm test:*)); never allow git push
# run via bash -c with SHERPA_LAYER and SHERPA_TASK exported; keep the prompt first, since
# --add-dir and --allowedTools take every argument that follows them
runner: |-
  claude -p "/sherpa:$SHERPA_LAYER --unattended \"$SHERPA_TASK\"" --permission-mode acceptEdits --add-dir "$(dirname "$SHERPA_TASK")" --allowedTools "Read,Grep,Glob,Edit,Write,Bash(git status:*),Bash(git diff:*),Bash(git log:*),Bash(git show:*),Bash(git add:*),Bash(git commit:*)"
EOF2
)
  tpl=${tpl//@REPO@/"$(q "$repo")"}; tpl=${tpl//@WT@/"$(q "$wt")"}
  printf '%s\n' "$tpl" >"$dir/settings.yaml"

  # a workspace pack's detect must match the worktree path; a local pack only exists once the
  # worktree does, so it is not checked
  case "$config" in '' | */.sherpa/project.y*ml) ;; *)
    sample=${wt//'$SHERPA_ID'/SAMPLE-1}
    found=$(bash "$here/../pack/find.sh" "$sample" || true)
    [ -n "$found" ] && [ "$(yq '.name // ""' "$found")" = "$pack" ] ||
      echo "ensure-board: warning: pack '$pack' detect does not match $sample; make detect match worktree.path in $dir/settings.yaml" >&2 ;;
  esac
fi

bash "$here/build-board.sh" "$pack" >/dev/null
echo "$dir"
