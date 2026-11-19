#!/usr/bin/env bash
# Usage: source scripts/lib/inventory.sh; ticket_state <file> <project> | ticket_get <file> <field> ...
# Input:  tickets are <inventory_dir>/<project>/<stage>/<ID>.md; see scripts/lib/dirs.sh.
# Output: STAGES (backlog, the middle stages named by LAYERS, done), PROTOCOL, ACTION_VALUES.
#   Functions (read side):
#   section_of <stage|marker>  prints "<marker>|<heading>", e.g. "plan|## Plan"; takes a stage
#                           or a marker name (frame plan implementation analysis last-run).
#   ticket_get <file> <field>  prints a front matter value, empty when absent.
#   ticket_title <file>     prints the first "# " line outside front matter, else the ID.
#   running_id <project>       prints the ID in .lock/ticket while .lock/pid is alive, else nothing.
#   ticket_state <file> <project>  prints backlog|done|running|you|queued|bad:<reason>.
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
#   ticket_find <project> <ID>  prints the path of <ID>.md in any STAGES folder; 1 when none.
#   ticket_apply_result <project> <ID> <stage> <done|gate|failed> <action> <content-file>  writes one
#                           run's output into the ticket where it is NOW (re-located with
#                           ticket_find): the stage's section (last-run when failed), parked: <folder
#                           now>, actionNeeded: <action> (fix when failed). Lines that would break
#                           the ticket ("## Answers", sherpa markers) get a backslash. done moves the
#                           ticket to done/ only when the stage is analyze and the ticket is still in
#                           analyze/ and done/ has no such file; otherwise it becomes gate. A
#                           non-failed run deletes last-run. Prints the result (done|gate|failed);
#                           on exit 1 prints the reason instead.
#   ticket_save_lost <project> <ID> <content-file>  when the write failed: parks the ticket (if it
#                           exists) with actionNeeded: fix and keeps the content as
#                           <stage dir>/<ID>.lost-output.txt (the project dir when the ticket is gone);
#                           prints that path.
#   ticket_cap <file>       cuts a file to $SHERPA_MAX_OUTPUT bytes (default 1000000), noting it.
#   ticket_diag <why> <rc|""> <stdout-file> <stderr-file>  prints a failed run's last-run text: the
#                           reason, the exit code (when rc is given), last 20 stderr lines, stdout.
#   expand_path <raw>       prints <raw> with a leading ~ or ~/ turned into $HOME and every $NAME or
#                           ${NAME} (NAME = letters, digits, _; not starting with a digit) turned into
#                           that variable's value from the environment. Nothing is run: no eval, no
#                           command substitution; $(...), backticks, a lone $ and $1 stay as text,
#                           and a value is not scanned again. An empty-but-set variable gives empty.
#                           An unset variable prints its name instead and returns 1.
#   resolve_location <settings-file> <key> <ID> <cwd>  resolves a place that settings.yaml gives as a
#                           map with exactly one of `path` (expand_path, TICKET_ID set) or `command`
#                           (bash -c in <cwd>, stdin /dev/null, TICKET_ID exported, stderr passed
#                           through; stdout must be exactly one non-empty line, used literally). <key>
#                           is repository or worktree.pattern. The result must be absolute. Sets
#                           LOCATION and returns 0; else returns 1 with the reason in LOCATION_ERR.
#                           Call it without a subshell.
#   lock_acquire <lock-dir>  mkdir lock with this shell's pid; takes over a lock whose pid is dead
#                           (rename aside, then mkdir); 1 when a live pass holds it or the race is lost.
#   project_title <project>  prints settings.yaml `name` (the display label) when it is a one-line,
#                           non-empty string, else the project ID; a missing or invalid file gives the ID.
#   BASE_TOOLS              the default --allowedTools list (comma separated).
#   settings_tools <settings-file>  sets the array TOOLS from the `tools` list (empty when absent);
#                           1 and an empty TOOLS when `tools` is not a list or an entry is not a
#                           one-line, non-empty string.
#   default_cmd <stage> <ticket-file> [tool...]  sets the array DEFAULT_CMD: the default runner
#                           command, `claude -p` with the prompt first, BASE_TOOLS plus each tool.
#                           An array, so a tool entry is never read as shell code.
# Exit:   0, except ticket_get: 1 when the front matter is not valid YAML. section_of: 1 for an
#   unknown stage or marker. ticket_apply_result and lock_acquire: 1, see above. Write side: 1 on a bad argument, bad YAML, or markers that open but
#   do not close; the file is then left untouched. Never exits the caller. Needs yq. Sourced only;
#   never run directly.

source "$(dirname "${BASH_SOURCE[0]}")/layers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/dirs.sh"

STAGES=(backlog "${LAYERS[@]}" done)
PROTOCOL=1
BASE_TOOLS="Read,Grep,Glob,Edit,Write,Bash(git status:*),Bash(git diff:*),Bash(git log:*),Bash(git show:*),Bash(git add:*),Bash(git commit:*)"
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
  local f=$1 project=$2 id stage s v n=0 parked action ok=0
  id=$(basename "$f" .md); stage=$(basename "$(dirname "$f")")
  if ! valid_id "$id"; then echo "bad:invalid ID (letters, digits, . _ - only)"; return 0; fi
  for s in "${STAGES[@]}"; do [ -f "$(inventory_dir)/$project/$s/$id.md" ] && n=$((n + 1)); done
  if [ "$n" -gt 1 ]; then echo "bad:same ID in more than one folder"; return 0; fi
  if ! { parked=$(ticket_get "$f" parked) && action=$(ticket_get "$f" actionNeeded); }; then
    echo "bad:front matter is not valid YAML"; return 0
  fi
  for v in "${ACTION_VALUES[@]}"; do [ "$v" = "$action" ] && ok=1; done
  if [ -n "$action" ] && [ "$ok" -eq 0 ]; then echo "bad:unknown actionNeeded '$action'"; return 0; fi
  case "$stage" in backlog | done) echo "$stage"; return 0 ;; esac
  if [ "$id" = "$(running_id "$project")" ]; then echo running
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

ticket_apply_result() {
  local project=$1 id=$2 stage=$3 kind=$4 action=$5 cf=$6 f cur sec=$3 dest
  f=$(ticket_find "$project" "$id") || { echo "ticket is gone: $id"; return 1; }
  cur=$(basename "$(dirname "$f")"); dest=$(inventory_dir)/$project/done/$id.md
  [ "$kind" = failed ] && { sec=last-run; action=fix; }
  [ "$kind" = done ] && { [ "$stage" != analyze ] || [ "$cur" != analyze ]; } && kind=gate
  sed -e 's/^## Answers$/\\## Answers/' -e 's/^<!-- \(\/\{0,1\}\)sherpa:/<!-- \\\1sherpa:/' "$cf" >"$cf.safe" ||
    { echo "cannot read the output"; return 1; }
  ticket_section_put "$f" "$sec" "$cf.safe" ||
    { echo "cannot write section $sec (broken markers or YAML?)"; return 1; }
  [ "$kind" = failed ] || ticket_section_del "$f" last-run || { echo "cannot remove last-run"; return 1; }
  if [ "$kind" = done ]; then
    if [ ! -e "$dest" ] && mv -n "$f" "$dest" && [ ! -e "$f" ]; then
      ticket_del "$dest" parked && ticket_del "$dest" actionNeeded || { echo "cannot clear front matter"; return 1; }
      echo done; return 0
    fi
    echo "run: $id stays in analyze/: $dest exists or cannot be moved" >&2; kind=gate
  fi
  ticket_set "$f" parked "$cur" && ticket_set "$f" actionNeeded "$action" ||
    { echo "cannot write front matter (not valid YAML?)"; return 1; }
  echo "$kind"
}

ticket_save_lost() {
  local f d
  if f=$(ticket_find "$1" "$2"); then
    d=$(dirname "$f")
    { ticket_set "$f" parked "$(basename "$d")" && ticket_set "$f" actionNeeded fix; } || true
  else d=$(inventory_dir)/$1; fi
  cp "$3" "$d/$2.lost-output.txt" && echo "$d/$2.lost-output.txt"
}

ticket_cap() {
  local max=${SHERPA_MAX_OUTPUT:-1000000} t
  [ "$(wc -c <"$1")" -gt "$max" ] || return 0
  t=$(mktemp "$1.XXXXXX") || return 0
  { head -c "$max" "$1"; printf '\n[truncated: output was over %s bytes]\n' "$max"; } >"$t" && mv -f "$t" "$1"
}

ticket_diag() {
  local max=${SHERPA_MAX_OUTPUT:-1000000}
  printf '%s\n\n' "$1"
  [ -z "$2" ] || printf 'exit code: %s\n' "$2"
  echo "stderr (last 20 lines):"; tail -n 20 "$4" | tail -c "$max"
  printf '\nstdout:\n'; cat "$3"
}

expand_path() {
  local _ep_s=$1 _ep_out="" _ep_name _ep_a='^\{([A-Za-z_][A-Za-z0-9_]*)\}(.*)$' _ep_b='^([A-Za-z_][A-Za-z0-9_]*)(.*)$'
  case "$_ep_s" in "~" | "~/"*) _ep_out=$HOME; _ep_s=${_ep_s#"~"} ;; esac
  while [[ $_ep_s == *'$'* ]]; do
    _ep_out+=${_ep_s%%'$'*}; _ep_s=${_ep_s#*'$'}
    if [[ $_ep_s =~ $_ep_a ]] || [[ $_ep_s =~ $_ep_b ]]; then
      _ep_name=${BASH_REMATCH[1]}; _ep_s=${BASH_REMATCH[2]}
      [ -n "${!_ep_name+x}" ] || { printf '%s\n' "$_ep_name"; return 1; }
      _ep_out+=${!_ep_name}
    else _ep_out+='$'; fi
  done
  printf '%s\n' "$_ep_out$_ep_s"
}

lock_acquire() {
  local lock=$1 old _
  if ! mkdir "$lock" 2>/dev/null; then
    for _ in 1 2 3; do [ -f "$lock/pid" ] && break; sleep 0.2; done
    old=$(cat "$lock/pid" 2>/dev/null || true)
    if [ -n "$old" ] && kill -0 "$old" 2>/dev/null; then return 1; fi
    mv "$lock" "$lock.stale.$$" 2>/dev/null || return 1
    if [ "$(cat "$lock.stale.$$/pid" 2>/dev/null || true)" != "$old" ]; then  # moved a fresh lock
      mv "$lock.stale.$$" "$lock" 2>/dev/null; return 1
    fi
    rm -rf "$lock.stale.$$"
    mkdir "$lock" 2>/dev/null || return 1
  fi
  echo $$ >"$lock/pid"
}

project_title() {
  local n
  if n=$(yq -e '.name | select((type == "!!str") and (length > 0) and (test("\n") | not))' \
    "$(inventory_dir)/$1/settings.yaml" 2>/dev/null) && [ -n "$n" ]; then printf '%s\n' "$n"
  else printf '%s\n' "$1"; fi
}

settings_tools() {
  TOOLS=()
  yq -e '(.tools // []) | ((type == "!!seq") and (([.[] | select((type != "!!str") or (length == 0) or test("\n"))] | length) == 0))' \
    "$1" >/dev/null 2>&1 || return 1
  local t; while IFS= read -r t; do TOOLS+=("$t"); done < <(yq '.tools // [] | .[]' "$1")
}

default_cmd() {
  local stage=$1 file=$2 tools=$BASE_TOOLS t; shift 2
  for t in "$@"; do tools+=",$t"; done
  DEFAULT_CMD=(claude -p "/sherpa:$stage --unattended \"$file\"" --permission-mode acceptEdits
    --add-dir "$(dirname "$file")" --allowedTools "$tools")
}

resolve_location() {
  local conf=$1 key=$2 id=$3 cwd=$4 t p c v out rc
  LOCATION= LOCATION_ERR="settings.yaml: $key needs exactly one of path or command"
  t=$(yq ".$key | type" "$conf" 2>/dev/null) || { LOCATION_ERR="settings.yaml is not valid YAML: $conf"; return 1; }
  case "$t" in
    "" | '!!null') return 1 ;;
    '!!map') ;;
    *) LOCATION_ERR+=" (write \`$key:\` as a map with \`path:\` or \`command:\` under it, not a plain value)"; return 1 ;;
  esac
  p=$(yq ".$key.path // \"\"" "$conf") && c=$(yq ".$key.command // \"\"" "$conf") ||
    { LOCATION_ERR="settings.yaml is not valid YAML: $conf"; return 1; }
  { [ -n "$p" ] && [ -z "$c" ]; } || { [ -z "$p" ] && [ -n "$c" ]; } || return 1
  if [ -n "$p" ]; then
    v=$(TICKET_ID=$id expand_path "$p") || { LOCATION_ERR="settings.yaml: $key.path uses unset variable \$$v"; return 1; }
    key=$key.path
  else
    key=$key.command
    out=$(cd "$cwd" && TICKET_ID=$id bash -c "$c" </dev/null; printf 'x%s' "$?")
    rc=${out##*x}; out=${out%x*}
    [ "$rc" -eq 0 ] || { LOCATION_ERR="settings.yaml: $key failed (exit $rc)"; return 1; }
    v=${out%$'\n'}
    if [ -z "$v" ] || [[ $v == *$'\n'* ]]; then LOCATION_ERR="settings.yaml: $key must print one path"; return 1; fi
  fi
  case "$v" in /*) ;; *) LOCATION_ERR="settings.yaml: $key must be absolute: $v"; return 1 ;; esac
  LOCATION=$v
}
