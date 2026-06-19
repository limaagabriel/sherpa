#!/bin/sh
# Slug <raw task string> to the run-state <key> used by state-persistence.md.
# Lowercase, non-alnum runs -> single hyphen, trim leading/trailing hyphens, truncate to 40.
# Usage: run-state-key.sh "<raw task string>"

if [ $# -lt 1 ]; then
  echo "usage: run-state-key.sh <raw>" >&2
  exit 2
fi

printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | sed 's/^-\+//;s/-\+$//' | cut -c1-40
