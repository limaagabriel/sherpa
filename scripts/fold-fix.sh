#!/bin/sh
# Folds a Review-stage fix into the subtask commit that owns <BUILD ID>.<n>.
# Resolves the target by its Build-Id note key (never `git commit --fixup=""`).
# Requires git >= 2.38 (non-interactive --autosquash). On older git, abort.
# Aborts (exit 1) on unresolvable target, conflict, or older git; never force-resolves.
# Args: <BUILD ID>.<n> <PRE-BUILD BASE> [files...]

set -e

if [ $# -lt 2 ]; then
  echo "usage: fold-fix.sh <BUILD ID>.<n> <PRE-BUILD BASE> [files...]" >&2
  exit 2
fi

key="$1"
prebuild="$2"
shift 2

git_version=$(git --version | awk '{print $3}')
required="2.38.0"
if [ "$(printf '%s\n' "$required" "$git_version" | sort -V | head -1)" != "$required" ]; then
  echo "fold-fix: requires git >= $required (found $git_version); abort for manual fold" >&2
  exit 1
fi

target=$("$(dirname "$0")/build-notes.sh" owner "$key" "$prebuild")

if [ -z "$target" ]; then
  echo "fold-fix: no commit carries key '$key' in $prebuild..HEAD" >&2
  exit 1
fi

if [ $# -gt 0 ]; then
  git add "$@"
fi
git commit --fixup="$target"
git rebase --autosquash "$prebuild"
