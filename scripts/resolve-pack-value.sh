#!/usr/bin/env bash
# Prints a project pack's context for a subagent, in one call.
#
# Usage: resolve-pack-value.sh <configPath> [frame|shape|implement]
#
# Base dir = dirname(configPath). Prints <basedir>/context.md if present,
# then <basedir>/<layer>/context.md if a layer was given and present, with
# exactly one blank line between them when both print. A missing file prints
# nothing and warns nothing (exit 0). An unknown layer, a missing configPath,
# or a 3rd argument is a one-line stderr usage error, exit 1.

set -u

config="${1:-}"
layer="${2:-}"
extra="${3:-}"
if [ -z "$config" ]; then
  echo "usage: resolve-pack-value.sh <configPath> [frame|shape|implement]" >&2
  exit 1
fi

if [ -n "$extra" ]; then
  echo "resolve-pack-value.sh: unrecognized argument: $extra" >&2
  exit 1
fi

case "$layer" in
  ""|frame|shape|implement) ;;
  *)
    echo "resolve-pack-value.sh: unrecognized layer: $layer (expected one of: frame, shape, implement)" >&2
    exit 1
    ;;
esac

basedir=$(cd "$(dirname "$config")" 2>/dev/null && pwd) || basedir=$(dirname "$config")

root_file="$basedir/context.md"
layer_file=""
[ -n "$layer" ] && layer_file="$basedir/$layer/context.md"

root_exists=0
layer_exists=0
[ -f "$root_file" ] && root_exists=1
[ -n "$layer_file" ] && [ -f "$layer_file" ] && layer_exists=1

# $(...) strips trailing newlines, so re-adding exactly one below guarantees
# a single blank line between the blocks, regardless of source trailing
# newlines.
if [ "$root_exists" -eq 1 ]; then
  root_content=$(cat "$root_file")
  printf '%s\n' "$root_content"
fi

if [ "$layer_exists" -eq 1 ]; then
  [ "$root_exists" -eq 1 ] && printf '\n'
  layer_content=$(cat "$layer_file")
  printf '%s\n' "$layer_content"
fi

exit 0
