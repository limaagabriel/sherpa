#!/usr/bin/env bash
# Prints the base directory used to resolve a project-pack config's relative
# values — command keys and knowledge paths via resolve-pack-value.sh.
#
# Usage: resolve-pack-basedir.sh <configPath>
#
# Classification is filename-driven, not cwd-driven — this runs standalone,
# possibly long after the original SessionStart hook's cwd is gone:
#   sherpa.yaml|.yml   project-local config. Walk up from the config's own dir
#                      to the nearest ancestor literally named .sherpa, .claude,
#                      .codex, or .pi, and print that ancestor's path.
#   project.yaml|.yml  workspace config (and anything else). Print the config's
#                      own dir directly — NEVER walk up, even if an ancestor
#                      happens to be named .claude or similar; one packs dir
#                      serves many projects, so its own dir IS the base.
#
# Adapted from resolve-project-pack.sh's proximate_base()/is_local(), which did
# the same classification from a cwd plus a candidate-path membership check
# instead of a bare config path with no cwd input.

set -u

config="${1:-}"
if [ -z "$config" ]; then
  echo "usage: resolve-pack-basedir.sh <configPath>" >&2
  exit 1
fi

own_dir=$(cd "$(dirname "$config")" 2>/dev/null && pwd) || own_dir=$(dirname "$config")

case "$(basename "$config")" in
  sherpa.yaml|sherpa.yml)
    d="$own_dir"
    while [ "$d" != "/" ]; do
      case "$(basename "$d")" in
        .sherpa|.claude|.codex|.pi) printf '%s' "$d"; exit 0 ;;
      esac
      d=$(dirname "$d")
    done
    printf '%s' "$own_dir" ;;
  *)
    printf '%s' "$own_dir" ;;
esac
