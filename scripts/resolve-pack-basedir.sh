#!/usr/bin/env bash
# Prints the base directory used to resolve a project-pack config's
# convention-path values — every key resolve-pack-value.sh understands.
#
# Usage: resolve-pack-basedir.sh <configPath>
#
# The base dir is always the config file's own directory: every pack config,
# project-local or workspace, now lives directly inside its own canonical
# directory (see resolve-project-pack.sh), so there is no ancestor to walk up
# to anymore.

set -u

config="${1:-}"
if [ -z "$config" ]; then
  echo "usage: resolve-pack-basedir.sh <configPath>" >&2
  exit 1
fi

own_dir=$(cd "$(dirname "$config")" 2>/dev/null && pwd) || own_dir=$(dirname "$config")

printf '%s' "$own_dir"
