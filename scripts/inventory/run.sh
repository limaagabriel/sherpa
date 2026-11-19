#!/usr/bin/env bash
# Usage: run.sh <pack>
# Input:  <inventory_dir>/<pack>/settings.yaml (`runner`, a shell command; plus what
#   ensure-worktree.sh reads) and the tickets in the pack's stage folders. Needs yq.
# Output: one pass: each ticket whose state is queued, stages analyze, implement, shape, frame in
#   that order, runs `bash -c <runner>` in its worktree (TICKET_STAGE, TICKET_FILE exported, stdin
#   /dev/null); the output goes into the ticket (see ticket_apply_result) and the ticket is
#   parked. Prints "TICKET <pack>/<ID> <stage>: done|gate|failed" per ticket. Rebuilds board.md
#   at the start and after each ticket. Holds <pack>/.lock (pid, ticket ID) during the pass.
#   A failed run keeps the runner's whole stdout in last-run; stdout is cut at $SHERPA_MAX_OUTPUT
#   bytes (default 1000000). A write that fails parks the ticket (fix) and keeps the output in
#   <ID>.lost-output.txt. The runner's first line starting "STATUS: " is parsed; lines before it
#   are dropped.
# Exit:   0 pass finished; 1 a ticket failed, or unknown pack; 2 usage or no runner; 3 pass
#   already running.
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$here/../lib/inventory.sh"

[ $# -eq 1 ] || { echo "usage: run.sh <pack>" >&2; exit 2; }
pack=$1; dir="$(inventory_dir)/$pack"
valid_id "$pack" && [ -d "$dir" ] || { echo "run: unknown pack: $pack" >&2; exit 1; }
runner=$(yq '.runner // ""' "$dir/settings.yaml" 2>/dev/null || true)
[ -n "$runner" ] || { echo "run: no runner; set runner in settings.yaml" >&2; exit 2; }

lock=$dir/.lock
lock_acquire "$lock" || { echo "run: another pass is running for $pack" >&2; exit 3; }
tmp=$(mktemp -d)
trap 'rm -rf "$lock" "$tmp"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
board() { bash "$here/build-board.sh" "$pack" >/dev/null || true; }
board; failed=0

for stage in analyze implement shape frame; do
  for f in "$dir/$stage"/*.md; do
    [ -f "$f" ] && [ "$(ticket_state "$f" "$pack")" = queued ] || continue
    id=$(basename "$f" .md); task="$(cd "$(dirname "$f")" && pwd)/$id.md"
    echo "$id" >"$lock/ticket"; board
    kind=failed rc=0 why= action=approval
    case $stage in implement) action=review ;; analyze) action=decision ;; esac
    : >"$tmp/body"; : >"$tmp/out"
    if wt=$(bash "$here/ensure-worktree.sh" "$pack" "$id" 2>"$tmp/err" </dev/null); then
      (cd "$wt" && TICKET_STAGE=$stage TICKET_FILE=$task bash -c "$runner" \
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
    if res=$(ticket_apply_result "$pack" "$id" "$stage" "$kind" "$action" "$tmp/body"); then kind=$res
    else kind=failed; echo "run: $pack/$id: $res; output kept in $(ticket_save_lost "$pack" "$id" "$tmp/body")" >&2; fi
    [ "$kind" != failed ] || failed=1
    echo "TICKET $pack/$id $stage: $kind"
    board
  done
done
exit "$failed"
