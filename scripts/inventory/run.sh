#!/usr/bin/env bash
# Usage: run.sh <project>
# Input:  <inventory_dir>/<project>/settings.yaml (`tools`, a list of extra allowed tools; `runner`,
#   an optional shell command; `source`, files sourced before it (see scripts/lib/source-cmd.sh); plus
#   what ensure-worktree.sh reads) and the tickets in the project's
#   stage folders. Needs yq.
# Output: one pass: each ticket whose state is queued, stages analyze, implement, shape, frame in
#   that order, runs in its worktree (TICKET_STAGE, TICKET_FILE exported, stdin /dev/null) the
#   default command (default_cmd in scripts/lib/inventory.sh, run directly, no shell) with `tools`
#   added to its --allowedTools, with no `source` files; or, when `runner` is set, `bash -c <runner>`
#   after the `source` files, and `tools` is ignored. The output goes into the ticket (see ticket_apply_result) and the ticket is
#   parked. Prints "TICKET <project>/<ID> <stage>: done|gate|failed" per ticket. Rebuilds board.md
#   at the start and after each ticket. Holds <project>/.lock (pid, ticket ID) during the pass.
#   A failed run keeps the runner's whole stdout in last-run; stdout is cut at $SHERPA_MAX_OUTPUT
#   bytes (default 1000000). A write that fails parks the ticket (fix) and keeps the output in
#   <ID>.lost-output.txt. The runner's first line starting "STATUS: " is parsed; lines before it
#   are dropped.
# Exit:   0 pass finished; 1 a ticket failed, or unknown project; 2 usage, or `tools` is not a
#   list of one-line strings (checked only when no runner is set); 3 pass already running.
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$here/../lib/inventory.sh"

[ $# -eq 1 ] || { echo "usage: run.sh <project>" >&2; exit 2; }
project=$1; dir="$(inventory_dir)/$project"
valid_id "$project" && [ -d "$dir" ] || { echo "run: unknown project: $project" >&2; exit 1; }
runner=$(yq '.runner // ""' "$dir/settings.yaml" 2>/dev/null || true)
[ -n "$runner" ] || settings_tools "$dir/settings.yaml" ||
  { echo "run: settings.yaml: tools must be a list of one-line strings" >&2; exit 2; }

lock=$dir/.lock
lock_acquire "$lock" || { echo "run: another pass is running for $project" >&2; exit 3; }
tmp=$(mktemp -d)
trap 'rm -rf "$lock" "$tmp"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
board() { bash "$here/build-board.sh" "$project" >/dev/null || true; }
board; failed=0

for stage in analyze implement shape frame; do
  for f in "$dir/$stage"/*.md; do
    [ -f "$f" ] && [ "$(ticket_state "$f" "$project")" = queued ] || continue
    id=$(basename "$f" .md); task="$(cd "$(dirname "$f")" && pwd)/$id.md"
    echo "$id" >"$lock/ticket"; board
    kind=failed rc=0 why= action=approval
    case $stage in implement) action=review ;; analyze) action=decision ;; esac
    : >"$tmp/body"; : >"$tmp/out"
    if wt=$(bash "$here/ensure-worktree.sh" "$project" "$id" 2>"$tmp/err" </dev/null); then
      if [ -n "$runner" ]; then source_cmd "$dir/settings.yaml" "$id" "$runner" && cmd=("${SHELL_CMD[@]}") ||
        cmd=(bash -c 'echo "$1" >&2; exit 1' bash "$SOURCE_ERR")
      else default_cmd "$stage" "$task" ${TOOLS[@]+"${TOOLS[@]}"}; cmd=("${DEFAULT_CMD[@]}"); fi
      (cd "$wt" && TICKET_STAGE=$stage TICKET_FILE=$task "${cmd[@]}" \
        </dev/null >"$tmp/out" 2>"$tmp/err") || rc=$?
      ticket_cap "$tmp/out"
      line=$(awk '/^STATUS: /{print; exit}' "$tmp/out")
      awk 'f{print} !f && /^STATUS: /{f=1}' "$tmp/out" >"$tmp/body"
      if [ "$rc" -ne 0 ]; then why="runner exited with code $rc"
      elif [ -z "$line" ]; then why="no STATUS line in the output"
      elif [[ ! $line =~ ^STATUS:\ (DONE|GATE|FAILED)\ protocol=([0-9]+)(\ |$) ]]; then
        why="unreadable STATUS line: $line"
      elif [ "${BASH_REMATCH[2]}" != "$PROTOCOL" ]; then
        why="plugin and CLI versions differ (runner protocol=${BASH_REMATCH[2]}, expected $PROTOCOL)"
      else
        word=${BASH_REMATCH[1]}; kind=${word,,}
        [[ $line =~ (^|[[:space:]])actionNeeded=(answers|approval|review|decision)([^a-z]|$) ]] &&
          action=${BASH_REMATCH[2]}
      fi
    else why="worktree: could not be prepared"; rc=; fi
    [ -z "$why" ] || ticket_diag "$why" "$rc" "$tmp/out" "$tmp/err" >"$tmp/body"
    rm -f "$lock/ticket"
    if res=$(ticket_apply_result "$project" "$id" "$stage" "$kind" "$action" "$tmp/body"); then kind=$res
    else kind=failed; echo "run: $project/$id: $res; output kept in $(ticket_save_lost "$project" "$id" "$tmp/body")" >&2; fi
    [ "$kind" != failed ] || failed=1
    echo "TICKET $project/$id $stage: $kind"
    board
  done
done
exit "$failed"
