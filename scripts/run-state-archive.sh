#!/bin/sh
# Archive a completed plan's run-state triplet into the branch key-dir's
# archive/ subtree, so a follow-up plan can supersede it without losing history.
# Moves SPEC.md/DECISIONS.md/PROGRESS.md into archive/<NNN>-<slug>/ and echoes
# the relative archive path (for the new SPEC's `Supersedes:` line).
# The COMPLETED gate is the caller's judgment — this script only moves files.
# Usage: run-state-archive.sh <key-dir> <slug>

if [ $# -lt 2 ]; then
  echo "usage: run-state-archive.sh <key-dir> <slug>" >&2
  exit 2
fi

key_dir="$1"
slug="$2"

if [ -z "$slug" ]; then
  echo "run-state-archive.sh: empty slug" >&2
  exit 2
fi

if [ ! -d "$key_dir" ]; then
  echo "run-state-archive.sh: no such key-dir: $key_dir" >&2
  exit 1
fi

if [ ! -f "$key_dir/SPEC.md" ]; then
  echo "run-state-archive.sh: no SPEC.md in $key_dir — nothing to archive" >&2
  exit 1
fi

n=0
for d in "$key_dir"/archive/[0-9][0-9][0-9]-*; do
  [ -d "$d" ] || continue
  n=$((n + 1))
done
seq=$(printf '%03d' $((n + 1)))

rel="archive/${seq}-${slug}"
dest="$key_dir/$rel"
mkdir -p "$dest"

for f in SPEC.md DECISIONS.md PROGRESS.md; do
  [ -f "$key_dir/$f" ] && mv "$key_dir/$f" "$dest/$f"
done

printf '%s\n' "$rel"
