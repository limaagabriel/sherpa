#!/usr/bin/env bash
# Usage: test-sherpa.sh
# Input:  none; runs bin/sherpa against stub inventory scripts (SHERPA_SCRIPTS) in a temp dir, and
#   once through chained, relative symlinks against the real scripts (a temp SHERPA_CONFIG_DIR).
# Output: "PASS: all sherpa cases" or FAIL lines plus "FAILED".
# Exit:   0 when every case passes, 1 otherwise.
set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
tmp=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$tmp"' EXIT
fail=0
source "$root/scripts/lib/assert.sh"
sherpa="$here/sherpa"

stubs="$tmp/stubs"; mkdir -p "$stubs/inventory"
export SHERPA_SCRIPTS="$stubs" CALLS="$tmp/calls" CODES="$tmp/codes"
for s in ensure-board build-board; do
  printf '#!/usr/bin/env bash\necho "%s $*" >>"$CALLS"\n[ "%s" = build-board ] && echo "$STUB_BOARD"\nexit "${STUB_RC:-0}"\n' \
    "$s" "$s" >"$stubs/inventory/$s.sh"
done
# run.sh pops the next exit code from $CODES (the last one repeats when the file runs dry)
cat >"$stubs/inventory/run.sh" <<'STUB'
#!/usr/bin/env bash
echo "run $*" >>"$CALLS"
rc=$(head -n 1 "$CODES"); [ -n "$rc" ] || rc=0
[ "$(wc -l <"$CODES")" -le 1 ] || sed -i.bak 1d "$CODES"
[ -z "${STUB_HANG:-}" ] || sleep "$STUB_HANG"   # a long foreground child, like the real runner
echo "pass-output"
exit "$rc"
STUB
codes() { printf '%s\n' "$@" >"$CODES"; : >"$CALLS"; }
calls() { cat "$CALLS" 2>/dev/null; }
runs() { calls | grep '^run ' || true; }   # the run.sh passes only (loop also calls build-board once)
started() { for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do [ -n "$(runs)" ] && break; sleep 0.2; done; }
sherpa_run() { out=$(bash "$sherpa" "$@" 2>"$tmp/err"); rc=$?; err=$(cat "$tmp/err"); }

# init forwards args and exit code
: >"$CALLS"; STUB_RC=0 sherpa_run init mypack --repository /some/where
assert_exit "init rc" "$rc" 0
assert_eq "init args" "$(calls)" "ensure-board mypack --repository /some/where"
: >"$CALLS"; STUB_RC=1 sherpa_run init
assert_exit "init forwards failure" "$rc" 1
assert_eq "init no args" "$(calls)" "ensure-board "
STUB_RC=2 sherpa_run init --bogus
assert_exit "init forwards usage exit" "$rc" 2

# loop --once: one pass, exits with its code
for c in 0 1 2 3; do
  codes "$c" 0; sherpa_run loop p --once
  assert_exit "once exit $c" "$rc" "$c"
  assert_eq "once runs one pass ($c)" "$(runs)" "run p"
done
codes 3; sherpa_run loop p --once
assert_contains "once lock message" "$err" "another loop holds p"

# loop keeps going after 0 and 1, stops on 2 and on 3
codes 0 1 2; sherpa_run loop p --every 1
assert_exit "stop on 2" "$rc" 2
assert_eq "three passes before 2" "$(runs | wc -l | tr -d ' ')" "3"
assert_eq "pack passed to run.sh" "$(runs | sort -u)" "run p"
codes 1 3; sherpa_run loop p --every 1
assert_exit "stop on 3" "$rc" 3
assert_eq "two passes before 3" "$(runs | wc -l | tr -d ' ')" "2"
assert_contains "lock message" "$err" "another loop holds p"
assert_not_contains "no lock message on 2" "$(codes 2; sherpa_run loop p; echo "$err")" "another loop holds"

# the wait is --every seconds: the second pass does not start straight away
codes 0 2; s=$(date +%s); sherpa_run loop p --every 2; e=$(date +%s)
[ $((e - s)) -ge 2 ] || { echo "FAIL [every waits]: took $((e - s))s"; fail=1; }

# an unknown pack (build-board fails) stops loop before any pass, with --once too
for extra in "" "--once"; do
  codes 0; STUB_RC=1 sherpa_run loop typo $extra
  assert_exit "unknown pack stops [$extra]" "$rc" 2
  assert_eq "unknown pack runs nothing [$extra]" "$(runs)" ""
  assert_eq "unknown pack checked [$extra]" "$(calls)" "build-board typo"
done

# a signal stops the loop and its child, even while waiting
codes 0
bash "$sherpa" loop p --every 3071 >/dev/null 2>&1 & pid=$!
started; sleep 0.5; kill -TERM "$pid"; wait "$pid"; rc=$?
assert_exit "TERM exit" "$rc" 143
sleep 0.3; assert_eq "no wait left behind" "$(pgrep -f "sleep 3071" | wc -l | tr -d ' ')" "0"
# a background job in a script starts with INT ignored, so give the loop a default INT first
codes 0; perl -e '$SIG{INT}="DEFAULT"; exec @ARGV' bash "$sherpa" loop p --every 3071 >/dev/null 2>&1 & pid=$!
started; sleep 0.5; kill -INT "$pid"; wait "$pid"; rc=$?
assert_exit "INT exit" "$rc" 130
sleep 0.3; assert_eq "no wait left behind after INT" "$(pgrep -f "sleep 3071" | wc -l | tr -d ' ')" "0"

# a signal mid-pass also stops the runner (a long foreground child of run.sh) and its group
codes 0
STUB_HANG=3072 bash "$sherpa" loop p --every 1 >/dev/null 2>&1 & pid=$!
started; sleep 0.5
assert_eq "runner is running" "$(pgrep -f "sleep 3072" | wc -l | tr -d ' ')" "1"
kill -TERM "$pid"; wait "$pid"; rc=$?
assert_exit "TERM mid-pass exit" "$rc" 143
sleep 0.3; assert_eq "runner stopped by TERM" "$(pgrep -f "sleep 3072" | wc -l | tr -d ' ')" "0"
codes 0
STUB_HANG=3072 perl -e '$SIG{INT}="DEFAULT"; exec @ARGV' bash "$sherpa" loop p --every 1 >/dev/null 2>&1 & pid=$!
started; sleep 0.5
kill -INT "$pid"; wait "$pid"; rc=$?
assert_exit "INT mid-pass exit" "$rc" 130
sleep 0.3; assert_eq "runner stopped by INT" "$(pgrep -f "sleep 3072" | wc -l | tr -d ' ')" "0"

# board prints the board file and forwards failure
board="$tmp/board.md"; echo "the board" >"$board"; : >"$CALLS"
STUB_BOARD="$board" sherpa_run board p
assert_exit "board rc" "$rc" 0
assert_eq "board prints file" "$out" "the board"
assert_eq "board arg" "$(calls)" "build-board p"
STUB_RC=1 STUB_BOARD="$board" sherpa_run board p
assert_exit "board failure" "$rc" 1
assert_not_contains "board failure prints nothing" "$out" "the board"

# bad usage exits 2 with usage on stderr, nothing run
: >"$CALLS"
for args in "" "nope" "loop" "loop p --every" "loop p --bogus" "loop p q" "board" "board a b"; do
  # shellcheck disable=SC2086
  sherpa_run $args
  assert_exit "usage [$args]" "$rc" 2
  assert_contains "usage text [$args]" "$err" "usage:"
done
for n in 0 x -3 05 1.5; do
  sherpa_run loop p --every "$n"
  assert_exit "bad --every $n" "$rc" 2
  assert_contains "bad --every text $n" "$err" "positive integer"
done
assert_eq "usage runs nothing" "$(calls)" ""
sherpa_run help; assert_exit "help rc" "$rc" 0; assert_contains "help stdout" "$out" "usage: sherpa init"

# through chained, relative symlinks, without SHERPA_SCRIPTS, it finds the real scripts
unset SHERPA_SCRIPTS
cfg="$tmp/cfg"; mkdir -p "$cfg/inventory/p"
mkdir -p "$tmp/x/y" "$tmp/z"
up=$(printf '%s' "$tmp/x/y" | sed 's#[^/]\{1,\}#..#g'); up=${up#/}
ln -s "$up$root/bin/sherpa" "$tmp/x/y/l1"
ln -s "x/y/l1" "$tmp/l2"
ln -s "../l2" "$tmp/z/sherpa"
out=$(SHERPA_CONFIG_DIR="$cfg" bash "$tmp/z/sherpa" board p 2>&1); rc=$?
assert_exit "symlink board rc" "$rc" 0
assert_contains "symlink board content" "$out" "generated by sherpa"
out=$(cd "$tmp/z" && SHERPA_CONFIG_DIR="$cfg" bash ./sherpa board p 2>&1)
assert_contains "relative invocation" "$out" "generated by sherpa"
[ -f "$cfg/inventory/p/board.md" ] || { echo "FAIL [symlink board file]: not written"; fail=1; }

[ "$fail" -eq 0 ] && echo "PASS: all sherpa cases" || { echo "FAILED"; exit 1; }
