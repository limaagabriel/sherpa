#!/usr/bin/env bash
# Usage: run.sh <configPath> <step|end>
# Input:  the `run` entries from list.sh for that phase (skill entries are skipped;
#   the driver runs those). Each runs via `bash -c` in the current directory.
# Output: "GUARDRAIL <name>: pass" or "GUARDRAIL <name>: fail" followed by the last
#   20 lines of its output.
# Exit:   0 all passed or nothing to do; 1 a guardrail failed; 2 cannot run (any
#   list.sh exit 2 reason, including usage errors).
set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ "$#" -eq 2 ] || { echo "usage: run.sh <configPath> <step|end>" >&2; exit 2; }

entries=$(bash "$dir/list.sh" "$1" "$2" run) || exit 2

failed=0
while IFS=$'\t' read -r name _ value; do
  [ -n "$name" ] || continue
  if out=$(bash -c "$value" </dev/null 2>&1); then
    echo "GUARDRAIL $name: pass"
  else
    echo "GUARDRAIL $name: fail"
    printf '%s\n' "$out" | tail -n 20
    failed=1
  fi
done <<<"$entries"
exit "$failed"
