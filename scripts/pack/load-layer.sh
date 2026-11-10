#!/usr/bin/env bash
# Usage: load-layer.sh <configPath|none> [frame|shape|implement|analyze]
# Input:  configPath (project.yaml) or the literal `none` (no project pack), and an
#   optional layer.
# Output: the shared pack first — <shared_dir>/context.md, then <shared_dir>/<layer>/context.md.
#   Then the project pack — <basedir>/context.md, then <basedir>/<layer>/context.md, where
#   basedir = dirname(configPath); `none` prints shared only. One blank line between
#   files. When shared output was printed and project files follow, they are preceded by
#   "PROJECT RULES (override shared rules above on conflict):". Missing files print
#   nothing and warn nothing.
# Exit:   0 ok or nothing to print; 1 usage error (unknown layer, missing configPath, or a
#   3rd argument) with a one-line stderr message.
set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$dir/../lib/dirs.sh"

config="${1:-}"
layer="${2:-}"
extra="${3:-}"
if [ -z "$config" ]; then
  echo "usage: load-layer.sh <configPath|none> [frame|shape|implement|analyze]" >&2
  exit 1
fi

if [ -n "$extra" ]; then
  echo "load-layer.sh: unrecognized argument: $extra" >&2
  exit 1
fi

case "$layer" in
  ""|frame|shape|implement|analyze) ;;
  *)
    echo "load-layer.sh: unrecognized layer: $layer (expected one of: frame, shape, implement, analyze)" >&2
    exit 1
    ;;
esac

# Files that exist in <base>: context.md, then <layer>/context.md.
files_in() {
  [ ! -f "$1/context.md" ] || echo "$1/context.md"
  [ -z "$layer" ] || [ ! -f "$1/$layer/context.md" ] || echo "$1/$layer/context.md"
}

# $(cat) strips trailing newlines, so each file ends in exactly one newline and
# files are separated by exactly one blank line.
print_files() {
  local first=1 f
  for f in "$@"; do
    [ "$first" -eq 1 ] || printf '\n'
    printf '%s\n' "$(cat "$f")"
    first=0
  done
}

mapfile -t shared < <(files_in "$(shared_dir)")
project=()
if [ "$config" != none ]; then
  basedir=$(cd "$(dirname "$config")" 2>/dev/null && pwd) || basedir=$(dirname "$config")
  mapfile -t project < <(files_in "$basedir")
fi

[ "${#shared[@]}" -eq 0 ] || print_files "${shared[@]}"
if [ "${#project[@]}" -gt 0 ]; then
  if [ "${#shared[@]}" -gt 0 ]; then
    printf '\nPROJECT RULES (override shared rules above on conflict):\n'
  fi
  print_files "${project[@]}"
fi
exit 0
