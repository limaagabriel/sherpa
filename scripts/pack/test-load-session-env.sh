#!/usr/bin/env bash
# Usage: test-load-session-env.sh
# Input:  none; runs load-session.sh against temp fixtures. No framework.
# Output: "PASS: all resolution cases" or FAIL lines plus "FAILED".
# Exit:   0 when every case passes, 1 otherwise (0 with SKIP when yq or jq is missing).
set -u
unset SHERPA_CONFIG_DIR
here=$(cd "$(dirname "$0")" && pwd)
resolver="$here/load-session.sh"

command -v yq >/dev/null 2>&1 || { echo "SKIP: yq not installed"; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not installed"; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export XDG_CONFIG_HOME="$tmp/xdg"  # keeps the real ~/.config/sherpa/shared out of tests
fail=0
# Helpers from lib/assert.sh: assert_contains, assert_exit.
source "$here/../lib/assert.sh"

run() { printf '{"cwd":"%s"}' "$1" | bash "$resolver"; }
ctx() { run "$1" | jq -r '.hookSpecificOutput.additionalContext // ""'; }
msg() { run "$1" | jq -r '.systemMessage // ""'; }
mkyaml() { mkdir -p "$(dirname "$1")"; { echo "name: $2"; [ -n "${3:-}" ] && echo "detect: \"$3\""; } >"$1"; }

# j) yq missing -> primer plus disabled-packs warning, exit 0.
binonly="$tmp/binonly"
mkdir -p "$binonly" "$tmp/nomatch-j"
for t in bash cat jq dirname basename sed; do p=$(command -v "$t" 2>/dev/null) && ln -s "$p" "$binonly/$t"; done
oj=$(printf '{"cwd":"%s"}' "$tmp/nomatch-j" | PATH="$binonly" bash "$resolver"); rj=$?
assert_contains j-primer-without-yq "$oj" "check whether one of these fits"
assert_contains j-yq-warning "$oj" "yq not found"
assert_exit j-exit-0 "$rj" 0

# o) workspace packs dir with a space in its path.
mkyaml "$tmp/my packs/proj-o/project.yaml" proj-o "exit 0"
oo=$(WORKFLOW_PACKS_DIR="$tmp/my packs" ctx "$tmp/cwd-o")
assert_contains o-space-in-path "$oo" "configPath=\"$tmp/my packs/proj-o/project.yaml\""

# p) SHERPA_CONFIG_DIR alone -> packs dir is $SHERPA_CONFIG_DIR/projects.
mkyaml "$tmp/cfgp/projects/proj-p/project.yaml" proj-p "exit 0"
run_p() { printf '{"cwd":"%s"}' "$1" | env -u WORKFLOW_PACKS_DIR SHERPA_CONFIG_DIR="$tmp/cfgp" bash "$resolver"; }
assert_contains p-sherpa-config-dir "$(run_p "$tmp/cwd-p" | jq -r '.systemMessage // ""')" 'Project "proj-p" loaded into Sherpa'

# q) WORKFLOW_PACKS_DIR alone -> no /projects suffix applied.
mkyaml "$tmp/pq/proj-q/project.yaml" proj-q "exit 0"
mq=$(printf '{"cwd":"%s"}' "$tmp/cwd-q" | env -u SHERPA_CONFIG_DIR WORKFLOW_PACKS_DIR="$tmp/pq" bash "$resolver" | jq -r '.systemMessage // ""')
assert_contains q-workflow-packs-dir "$mq" 'Project "proj-q" loaded into Sherpa'

# r) both set -> SHERPA_CONFIG_DIR wins.
mkyaml "$tmp/cfgr/projects/proj-r-win/project.yaml" proj-r-win "exit 0"
mkyaml "$tmp/pr/proj-r-lose/project.yaml" proj-r-lose "exit 0"
mr=$(printf '{"cwd":"%s"}' "$tmp/cwd-r" | env SHERPA_CONFIG_DIR="$tmp/cfgr" WORKFLOW_PACKS_DIR="$tmp/pr" bash "$resolver" | jq -r '.systemMessage // ""')
assert_contains r-sherpa-config-dir-wins "$mr" "proj-r-win"
assert_not_contains r-workflow-packs-dir-loses "$mr" "proj-r-lose"
[ "$fail" -eq 0 ] && echo "PASS: all resolution cases" || echo "FAILED"
exit "$fail"
