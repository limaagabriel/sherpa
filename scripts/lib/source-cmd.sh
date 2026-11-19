#!/usr/bin/env bash
# Usage: source scripts/lib/source-cmd.sh; source_cmd <settings-file> <ID> <command>
# Input:  settings.yaml `source` (optional): one file (a string) or a list of files, each a one-line,
#   non-empty string. Every entry goes through expand_path (scripts/lib/inventory.sh) with TICKET_ID
#   set to <ID>: a leading ~ and $NAME / ${NAME} expand, nothing is run. Use absolute paths or ~.
# Output: sets the array SHELL_CMD, the argv that runs <command> where `bash -c "<command>"` ran
#   before. With no `source`, that is exactly (bash -c <command>). With files it is
#   (bash -c <fixed prelude> bash <command> <file>...): the prelude `source`s each file in order,
#   its stdout sent to stderr (it can never reach a command's result), then runs <command> with eval
#   after clearing the positional parameters. File names and <command> are arguments, never pasted
#   into shell code. A file that is missing or whose sourcing returns non-zero stops the command
#   with exit 1 after the stderr line `settings.yaml: source <file> failed`. The files are sourced
#   into the command's own shell: a `set -e`, `set -u` or trap in one of them applies to the command.
#   Callers run it as `TICKET_ID=<ID> ... "${SHELL_CMD[@]}"`.
# Exit:   0 SHELL_CMD is set; 1 with the reason in SOURCE_ERR (settings.yaml is not valid YAML,
#   `source` is neither a string nor a list of one-line, non-empty strings, an unset variable).
#   Never exits the caller. Needs yq. Sourced only; never run directly.

SOURCE_PRELUDE='__sherpa_c=$1; shift; __sherpa_f=("$@"); set --
for __sherpa_x in "${__sherpa_f[@]}"; do
  source "$__sherpa_x" >&2 || { echo "settings.yaml: source $__sherpa_x failed" >&2; exit 1; }
done
unset __sherpa_f __sherpa_x; eval "$__sherpa_c"'

source_cmd() {
  local conf=$1 id=$2 cmd=$3 t each= f v files=()
  SHELL_CMD=(bash -c "$cmd") SOURCE_ERR=
  t=$(yq '.source | type' "$conf" 2>/dev/null) || { SOURCE_ERR="settings.yaml is not valid YAML: $conf"; return 1; }
  case "$t" in
    "" | '!!null') return 0 ;;
    '!!str') yq -e '.source | select(length > 0) | select(test("\n") | not)' "$conf" >/dev/null 2>&1 || t=bad ;;
    '!!seq') each='[]'; yq -e '[.source[] | select((type != "!!str") or (length == 0) or test("\n"))] | length == 0' \
      "$conf" >/dev/null 2>&1 || t=bad ;;
    *) t=bad ;;
  esac
  [ "$t" != bad ] || { SOURCE_ERR="settings.yaml: source must be a file or a list of files (one-line text)"; return 1; }
  while IFS= read -r f; do
    v=$(TICKET_ID=$id expand_path "$f") || { SOURCE_ERR="settings.yaml: source uses unset variable \$$v"; return 1; }
    files+=("$v")
  done < <(yq ".source$each" "$conf")
  [ ${#files[@]} -eq 0 ] || SHELL_CMD=(bash -c "$SOURCE_PRELUDE" bash "$cmd" "${files[@]}")
}
