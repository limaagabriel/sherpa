#!/usr/bin/env bash
# Resolves a project-pack config's value at a fixed convention key, as file
# content read straight off disk — no YAML lookup is involved anymore.
#
# Usage: resolve-pack-value.sh <configPath> <key>
#
# <key> must be one of the 9 fixed convention keys below. Each maps to a path
# stem relative to resolve-pack-basedir.sh's output for this configPath (see
# packs/README.md for the full rationale):
#   session              -> session.md
#   context              -> context.md
#   frame.context        -> frame/context.md
#   shape.context        -> shape/context.md
#   shape.architecture   -> shape/architecture.md
#   implement.context    -> implement/context.md
#   implement.codeStyle  -> implement/codeStyle.md
#   implement.validate   -> implement/validate.md
#   implement.review     -> implement/review.md
# Any other <key> is a programming-contract violation (not a missing-value
# case) and is a hard failure.
#
# Precedence, per stem:
#   1. <stem>.md exists       -> print its content, done.
#   2. else <stem>/ exists    -> concatenate every *.md directly inside it,
#                                 `LC_ALL=C sort`-by-filename, done.
#   3. both exist              -> the file wins (its content is printed), and
#                                 a stderr warning names the ambiguity.
#   4. neither exists          -> print nothing to stdout; warn to stderr.
# A missing convention path is a warning, never a hard failure, matching this
# script's tone before this change.

set -u

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

config="${1:-}"
key="${2:-}"
extra="${3:-}"

if [ -z "$config" ] || [ -z "$key" ]; then
  echo "usage: resolve-pack-value.sh <configPath> <key>" >&2
  exit 1
fi

if [ -n "$extra" ]; then
  echo "resolve-pack-value.sh: unrecognized argument: $extra (this script has exactly one resolution mode; no 3rd argument is accepted)" >&2
  exit 1
fi

case "$key" in
  session) stem="session" ;;
  context) stem="context" ;;
  frame.context) stem="frame/context" ;;
  shape.context) stem="shape/context" ;;
  shape.architecture) stem="shape/architecture" ;;
  implement.context) stem="implement/context" ;;
  implement.codeStyle) stem="implement/codeStyle" ;;
  implement.validate) stem="implement/validate" ;;
  implement.review) stem="implement/review" ;;
  *)
    echo "resolve-pack-value.sh: unrecognized key: $key (expected one of: session, context, frame.context, shape.context, shape.architecture, implement.context, implement.codeStyle, implement.validate, implement.review)" >&2
    exit 1
    ;;
esac

basedir=$("$here/resolve-pack-basedir.sh" "$config")

file="$basedir/$stem.md"
dir="$basedir/$stem"

file_exists=0
dir_exists=0
[ -f "$file" ] && file_exists=1
[ -d "$dir" ] && dir_exists=1

if [ "$file_exists" -eq 1 ]; then
  if [ "$dir_exists" -eq 1 ]; then
    echo "resolve-pack-value.sh: ambiguous convention path (both $stem.md and $stem/ exist) — using the file: $file" >&2
  fi
  cat "$file"
  exit 0
fi

if [ "$dir_exists" -eq 1 ]; then
  # `LC_ALL=C sort` gives a byte-order sort, independent of locale, so the
  # concatenation order is stable across machines.
  mapfile -t files < <(find "$dir" -maxdepth 1 -type f -name '*.md' 2>/dev/null | LC_ALL=C sort)
  if [ "${#files[@]}" -gt 0 ]; then
    for f in "${files[@]}"; do
      cat "$f"
      printf '\n'
    done
    exit 0
  fi
fi

echo "resolve-pack-value.sh: missing convention path: $stem.md (or $stem/)" >&2
exit 0
