#!/usr/bin/env bash
# Resolves a project-pack config's value(s) at a dotted key under `.pack`,
# as concatenated file contents. Every key, including `validate`, resolves
# this same way — there is no alternate resolution mode.
#
# Usage: resolve-pack-value.sh <configPath> <dotted.key>
#
# <dotted.key> reads `.pack.<dotted.key>` via yq (a bare key with no dot, e.g.
# `knowledge`, reads the top-level `.pack.knowledge` the same way — there's no
# special-casing needed, the yq path is built the same either way), with one
# exception: the bare key `context` reads the config's top-level `.context`
# instead — `context` is a sibling of `pack`, not nested under it (see
# packs/README.md and packs/TEMPLATE.yaml), matching how using-sherpa's SKILL.md
# HARD GATE calls this script (`resolve-pack-value.sh <configPath> context`).
# The value may be a single string or a YAML array of strings.
#
# Default mode treats each entry as a path: an absolute path (/*) is used
# as-is; a relative path resolves against resolve-pack-basedir.sh's output for
# this configPath. No shell/environment expansion is ever performed on the
# value ($HOME, ~, ${VAR} are all literal, never expanded) — it's a path
# string, nothing more. Each resolved path that exists has its full contents
# printed, followed by a newline (so a file missing its own trailing newline
# never glues onto the next entry); a path that doesn't exist gets a stderr
# warning naming it and is skipped, not a hard failure. Files are printed in
# the order listed, concatenated into one blob on stdout.

set -u

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

config="${1:-}"
key="${2:-}"
extra="${3:-}"

if [ -z "$config" ] || [ -z "$key" ]; then
  echo "usage: resolve-pack-value.sh <configPath> <dotted.key>" >&2
  exit 1
fi

if [ -n "$extra" ]; then
  echo "resolve-pack-value.sh: unrecognized argument: $extra (this script has exactly one resolution mode; no 3rd argument is accepted)" >&2
  exit 1
fi

command -v yq >/dev/null 2>&1 || { echo "resolve-pack-value.sh: yq not found" >&2; exit 1; }

# `context` is the one content-bearing key that lives at the config's top
# level, a sibling of `pack` — everything else nests under `.pack`.
if [ "$key" = "context" ]; then
  yq_path=".context"
else
  yq_path=".pack.$key"
fi

# Normalize a scalar-or-array YAML value into one entry per line: wrapping the
# value in `[.]` then `flatten` collapses an already-array value back down to
# a flat array, while leaving a scalar as a single-element array — either way
# `.[]` then yields one entry per line, with `select` dropping a missing/empty
# result entirely.
mapfile -t entries < <(yq -r "$yq_path // \"\" | [.] | flatten | .[] | select(. != \"\")" "$config" 2>/dev/null)

[ "${#entries[@]}" -gt 0 ] || exit 0

basedir=$("$here/resolve-pack-basedir.sh" "$config")

for entry in "${entries[@]}"; do
  case "$entry" in
    /*) resolved="$entry" ;;
    *) resolved="$basedir/$entry" ;;
  esac
  if [ -f "$resolved" ]; then
    # A trailing newline after every successfully-read entry guarantees two
    # concatenated entries are always separated by at least one newline, even
    # when a file's own content doesn't end in one — otherwise its last line
    # would glue directly onto the next entry's first line.
    cat "$resolved"
    printf '\n'
  else
    echo "resolve-pack-value.sh: missing pack value file: $resolved" >&2
  fi
done
