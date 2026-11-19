#!/usr/bin/env bash
# Usage: source scripts/lib/inventory.sh; ticket_state <file> <pack> | ticket_get <file> <field> ...
# Input:  tickets are <inventory_dir>/<pack>/<stage>/<ID>.md; see scripts/lib/dirs.sh.
# Output: STAGES (backlog, the layers, done), PROTOCOL, ACTION_VALUES. Functions (read side):
#   section_of <layer>      prints "<marker>|<heading>", e.g. "plan|## Plan"; also last-run.
#   ticket_get <file> <field>  prints a front matter value, empty when absent.
#   ticket_title <file>     prints the first "# " line outside front matter, else the ID.
#   running_id <pack>       prints the ID in .lock/ticket while .lock/pid is alive, else nothing.
#   ticket_state <file> <pack>  prints backlog|done|running|you|queued|bad:<reason>.
#   valid_id <ID>           succeeds when the ID is letters, digits, . _ - and starts with a
#                           letter or digit.
# Exit:   0, except ticket_get: 1 when the front matter is not valid YAML. section_of: 1 for an
#   unknown layer. Never exits the caller. Needs yq. Sourced only; never run directly.

source "$(dirname "${BASH_SOURCE[0]}")/layers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/dirs.sh"

STAGES=(backlog "${LAYERS[@]}" done)
PROTOCOL=1
ACTION_VALUES=(answers approval review decision fix)

section_of() {
  case "$1" in
    frame) echo "frame|## Frame" ;;
    shape) echo "plan|## Plan" ;;
    implement) echo "implementation|## Implementation" ;;
    analyze) echo "analysis|## Analysis" ;;
    last-run) echo "last-run|## Last run" ;;
    *) return 1 ;;
  esac
}

ticket_get() {
  local v
  [ "$(head -n 1 "$1")" = "---" ] || return 0
  v=$(yq --front-matter=extract ".$2 // \"\"" "$1" 2>/dev/null) || return 1
  printf '%s\n' "$v"
}

ticket_title() {
  local t
  t=$(awk 'NR==1 && /^---$/ {fm=1; next} fm && /^---$/ {fm=0; next}
    !fm && /^# / {sub(/^# /, ""); print; exit}' "$1")
  printf '%s\n' "${t:-$(basename "$1" .md)}"
}

running_id() {
  local lock; lock="$(inventory_dir)/$1/.lock"
  if [ -f "$lock/pid" ] && kill -0 "$(cat "$lock/pid")" 2>/dev/null; then
    cat "$lock/ticket" 2>/dev/null || true
  fi
  return 0
}

valid_id() { [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; }

ticket_state() {
  local f=$1 pack=$2 id stage s v n=0 parked action ok=0
  id=$(basename "$f" .md); stage=$(basename "$(dirname "$f")")
  if ! valid_id "$id"; then echo "bad:invalid ID (letters, digits, . _ - only)"; return 0; fi
  for s in "${STAGES[@]}"; do [ -f "$(inventory_dir)/$pack/$s/$id.md" ] && n=$((n + 1)); done
  if [ "$n" -gt 1 ]; then echo "bad:same ID in more than one folder"; return 0; fi
  if ! { parked=$(ticket_get "$f" parked) && action=$(ticket_get "$f" actionNeeded); }; then
    echo "bad:front matter is not valid YAML"; return 0
  fi
  for v in "${ACTION_VALUES[@]}"; do [ "$v" = "$action" ] && ok=1; done
  if [ -n "$action" ] && [ "$ok" -eq 0 ]; then echo "bad:unknown actionNeeded '$action'"; return 0; fi
  case "$stage" in backlog | done) echo "$stage"; return 0 ;; esac
  if [ "$id" = "$(running_id "$pack")" ]; then echo running
  elif [ -n "$action" ] && [ "$parked" = "$stage" ]; then echo you
  else echo queued; fi
  return 0
}
