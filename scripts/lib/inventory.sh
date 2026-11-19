#!/usr/bin/env bash
# Usage: source scripts/lib/inventory.sh; ticket_state <file> <pack> | ticket_get <file> <field> ...
# Input:  tickets are <inventory_dir>/<pack>/<stage>/<ID>.md; see scripts/lib/dirs.sh.
# Output: STAGES (backlog, the layers, done), PROTOCOL, ACTION_VALUES. Functions (read side):
#   section_of <layer|marker>  prints "<marker>|<heading>", e.g. "plan|## Plan"; takes a layer
#                           or a marker name (frame plan implementation analysis last-run).
#   ticket_get <file> <field>  prints a front matter value, empty when absent.
#   ticket_title <file>     prints the first "# " line outside front matter, else the ID.
#   running_id <pack>       prints the ID in .lock/ticket while .lock/pid is alive, else nothing.
#   ticket_state <file> <pack>  prints backlog|done|running|you|queued|bad:<reason>.
#   valid_id <ID>           succeeds when the ID is letters, digits, . _ - and starts with a
#                           letter or digit.
# Write side (touch only the loop's own front matter fields and marker sections):
#   ticket_set <file> <field> <value>  sets a front matter field as a string; adds a front matter
#                           block when the file has none. The rest of the file stays byte-identical.
#   ticket_del <file> <field>  removes a field; drops the front matter block once it is empty.
#   ticket_section_put <file> <name> <content-file>  replaces the text between the name's markers,
#                           or inserts "## <Heading>" + markers before the line "## Answers", else
#                           at the end after a blank line. A missing final newline gets added.
#   ticket_section_del <file> <name>  removes heading, markers and content, plus one blank line.
#   ticket_find <pack> <ID>  prints the path of <ID>.md in any STAGES folder; 1 when none.
# Exit:   0, except ticket_get: 1 when the front matter is not valid YAML. section_of: 1 for an
#   unknown layer or marker. Write side: 1 on a bad argument, bad YAML, or markers that open but
#   do not close; the file is then left untouched. Never exits the caller. Needs yq. Sourced only;
#   never run directly.

source "$(dirname "${BASH_SOURCE[0]}")/layers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/dirs.sh"

STAGES=(backlog "${LAYERS[@]}" done)
PROTOCOL=1
ACTION_VALUES=(answers approval review decision fix)

section_of() {
  case "$1" in
    frame) echo "frame|## Frame" ;;
    shape | plan) echo "plan|## Plan" ;;
    implement | implementation) echo "implementation|## Implementation" ;;
    analyze | analysis) echo "analysis|## Analysis" ;;
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

# Copies <file> (mode kept) to a hidden temp file beside it and prints the temp path.
_ticket_tmp() {
  local t; t=$(mktemp "$(dirname "$1")/.sherpa.XXXXXX") || return 1
  cp -p "$1" "$t" 2>/dev/null || { rm -f "$t"; return 1; }
  printf '%s\n' "$t"
}

ticket_set() {
  local f=$1 field=$2 t
  [ -f "$f" ] && [[ $field =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 1
  t=$(_ticket_tmp "$f") || return 1
  if [ "$(head -n 1 "$f")" != "---" ]; then
    { printf -- '---\n---\n'; cat "$f"; } >"$t" || { rm -f "$t"; return 1; }
  fi
  if ! V=$3 yq --front-matter=process -i ".$field = strenv(V)" "$t" 2>/dev/null; then
    rm -f "$t"; return 1
  fi
  mv -f "$t" "$f"
}

ticket_del() {
  local f=$1 field=$2 t
  [ -f "$f" ] && [[ $field =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 1
  [ "$(head -n 1 "$f")" = "---" ] || return 0
  t=$(_ticket_tmp "$f") || return 1
  if ! yq --front-matter=process -i "del(.$field)" "$t" 2>/dev/null; then
    rm -f "$t"; return 1
  fi
  # yq leaves "---", "{}", "---" when the last field goes; drop that empty block.
  if [ "$(head -n 3 "$t")" = $'---\n{}\n---' ]; then tail -n +4 "$t" >"$t.b"
  elif [ "$(head -n 2 "$t")" = $'---\n---' ]; then tail -n +3 "$t" >"$t.b"
  else mv -f "$t" "$f"; return $?; fi
  mv -f "$t.b" "$t" && mv -f "$t" "$f"
}

# Prints none, open (opening marker without a closing one after it) or closed.
_section_state() {  # <file> <open> <close>
  S_OPEN=$2 S_CLOSE=$3 awk '
    $0 == ENVIRON["S_OPEN"] && !o { o = 1; next }
    o && $0 == ENVIRON["S_CLOSE"] { c = 1; exit }
    END { print c ? "closed" : (o ? "open" : "none") }' "$1"
}

ticket_section_put() {
  local f=$1 name=$2 cf=$3 sec head state t
  [ -f "$f" ] && [ -r "$cf" ] || return 1
  sec=$(section_of "$name") || return 1
  name=${sec%%|*}; head=${sec#*|}
  state=$(_section_state "$f" "<!-- sherpa:$name -->" "<!-- /sherpa:$name -->")
  [ "$state" = open ] && return 1
  t=$(_ticket_tmp "$f") || return 1
  S_OPEN="<!-- sherpa:$name -->" S_CLOSE="<!-- /sherpa:$name -->" S_HEAD=$head S_CF=$cf \
    S_STATE=$state awk '
    BEGIN {
      op = ENVIRON["S_OPEN"]; cl = ENVIRON["S_CLOSE"]
      while ((getline l < ENVIRON["S_CF"]) > 0) c = c l "\n"
    }
    ENVIRON["S_STATE"] == "closed" {
      if (skip) { if ($0 == cl) { skip = 0; print } ; next }
      if ($0 == op && !done) { print; printf "%s", c; skip = 1; done = 1; next }
      print; next
    }
    !done && $0 == "## Answers" {
      print ENVIRON["S_HEAD"]; print op; printf "%s", c; print cl; print ""; done = 1
    }
    { print }
    END {
      if (ENVIRON["S_STATE"] == "none" && !done) {
        if (NR > 0) print ""
        print ENVIRON["S_HEAD"]; print op; printf "%s", c; print cl
      }
    }' "$f" >"$t" || { rm -f "$t"; return 1; }
  mv -f "$t" "$f"
}

ticket_section_del() {
  local f=$1 name=$2 sec head state t
  [ -f "$f" ] || return 1
  sec=$(section_of "$name") || return 1
  name=${sec%%|*}; head=${sec#*|}
  state=$(_section_state "$f" "<!-- sherpa:$name -->" "<!-- /sherpa:$name -->")
  [ "$state" = open ] && return 1
  [ "$state" = none ] && return 0
  t=$(_ticket_tmp "$f") || return 1
  S_OPEN="<!-- sherpa:$name -->" S_CLOSE="<!-- /sherpa:$name -->" S_HEAD=$head awk '
    { L[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) if (L[i] == ENVIRON["S_OPEN"]) { o = i; break }
      for (i = o; i <= NR; i++) if (L[i] == ENVIRON["S_CLOSE"]) { e = i; break }
      s = (o > 1 && L[o - 1] == ENVIRON["S_HEAD"]) ? o - 1 : o
      if (e < NR && L[e + 1] == "") e++
      else if (s > 1 && L[s - 1] == "") s--
      for (i = 1; i <= NR; i++) if (i < s || i > e) print L[i]
    }' "$f" >"$t" || { rm -f "$t"; return 1; }
  mv -f "$t" "$f"
}

ticket_find() {
  local s
  valid_id "$2" || return 1
  for s in "${STAGES[@]}"; do
    [ -f "$(inventory_dir)/$1/$s/$2.md" ] && { echo "$(inventory_dir)/$1/$s/$2.md"; return 0; }
  done
  return 1
}
