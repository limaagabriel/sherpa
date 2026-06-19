#!/bin/sh
# Build-Id git-note read/write surface (refs/notes/build-id).
# The single set-aware parse contract for the scope consumers + write path + config.
# A note holds a deduped key-SET after squash (cat_sort_uniq) — never assume one key per commit.
# Subcommands:
#   init                      set repo-local notes.rewrite* config (idempotent)
#   stamp <RUN>.<n> [commit]  union the key into <commit>'s note key-set (default HEAD)
#   head-key                  print HEAD's note key-set (one per line; empty if none)
#   range <RUN> <base>        print '<sha> <key>' for each in-range note key prefixed <RUN>.
#   owner <RUN>.<n> <base>    print the single SHA whose note key-set holds <RUN>.<n>

set -e

REF=build-id

usage() {
  echo "usage: build-notes.sh <init|stamp|head-key|range|owner> [args]" >&2
  exit 2
}

notes_show() {
  git notes --ref="$REF" show "$1" 2>/dev/null || true
}

ensure_config_value() {
  git config --get-all "$1" 2>/dev/null | grep -qxF "$2" || git config --add "$1" "$2"
}

cmd_init() {
  ensure_config_value notes.rewriteRef "refs/notes/$REF"
  git config notes.rewriteMode cat_sort_uniq
  git config notes.rewrite.amend true
  git config notes.rewrite.rebase true
}

cmd_stamp() {
  key="$1"
  if [ -z "$key" ]; then
    echo "build-notes stamp: missing <RUN>.<n>" >&2
    exit 2
  fi
  commit="${2:-HEAD}"
  merged=$(printf '%s\n%s\n' "$(notes_show "$commit")" "$key" | grep -v '^$' | sort -u)
  git notes --ref="$REF" add -f -m "$merged" "$commit"
}

cmd_head_key() {
  notes_show HEAD
}

cmd_range() {
  run="$1"
  base="$2"
  if [ -z "$run" ] || [ -z "$base" ]; then
    echo "usage: build-notes.sh range <RUN> <base>" >&2
    exit 2
  fi
  for sha in $(git rev-list "$base"..HEAD); do
    notes_show "$sha" | while IFS= read -r key; do
      [ -n "$key" ] || continue
      case "$key" in
        "$run".*) echo "$sha $key" ;;
      esac
    done
  done
}

cmd_owner() {
  key="$1"
  base="$2"
  if [ -z "$key" ] || [ -z "$base" ]; then
    echo "usage: build-notes.sh owner <RUN>.<n> <base>" >&2
    exit 2
  fi
  for sha in $(git rev-list "$base"..HEAD); do
    if notes_show "$sha" | grep -qxF "$key"; then
      echo "$sha"
      return 0
    fi
  done
}

[ $# -ge 1 ] || usage
cmd="$1"
shift

case "$cmd" in
  init)     cmd_init ;;
  stamp)    cmd_stamp "$@" ;;
  head-key) cmd_head_key ;;
  range)    cmd_range "$@" ;;
  owner)    cmd_owner "$@" ;;
  *)        usage ;;
esac
