#!/usr/bin/env bash
# Usage: find.sh <cwd>
# Input:  the project working directory.
# Output: prints the first matching project config path.
# Exit:   0 on a match, 1 on no match.
#
# Candidates, highest precedence first: <cwd>/.sherpa/project.yaml|.yml (local;
# `detect` optional, file presence is the detection), then <packs dir>/*/project.yaml|.yml
# for each dir from packs_dirs (workspace; `detect` required). `detect` runs in the
# config's own directory with CWD=<cwd>. Needs yq.
set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$dir/../lib/dirs.sh"

cwd=${1:?usage: find.sh <cwd>}
shopt -s nullglob
candidates=("$cwd/.sherpa/project.yaml" "$cwd/.sherpa/project.yml")
while IFS= read -r pd; do
  candidates+=("$pd"/*/project.yaml "$pd"/*/project.yml)
done < <(packs_dirs)

for config in "${candidates[@]}"; do
  [ -f "$config" ] || continue
  detect=$(yq '.detect // ""' "$config" 2>/dev/null) || continue
  base=$(cd "$(dirname "$config")" 2>/dev/null && pwd) || base=$(dirname "$config")

  local_match=0
  case "$config" in
    "$cwd/.sherpa/project.yaml"|"$cwd/.sherpa/project.yml") local_match=1 ;;
  esac

  if [ -n "$detect" ]; then
    ( cd "$base" 2>/dev/null && CWD="$cwd" bash -c "$detect" ) >/dev/null 2>&1 || continue
  elif [ "$local_match" -ne 1 ]; then
    continue
  fi

  printf '%s\n' "$config"
  exit 0
done
exit 1
