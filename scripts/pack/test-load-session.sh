#!/usr/bin/env bash
# Usage: test-load-session.sh
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
# Helpers from lib/assert.sh: assert_contains, assert_not_contains.
source "$here/../lib/assert.sh"

run() { printf '{"cwd":"%s"}' "$1" | bash "$resolver"; }
ctx() { run "$1" | jq -r '.hookSpecificOutput.additionalContext // ""'; }
msg() { run "$1" | jq -r '.systemMessage // ""'; }
mkyaml() { mkdir -p "$(dirname "$1")"; { echo "name: $2"; [ -n "${3:-}" ] && echo "detect: \"$3\""; } >"$1"; }

# a) local, no detect -> matches on presence alone.
mkyaml "$tmp/a/.sherpa/project.yaml" proj-a
assert_contains a-local-no-detect "$(msg "$tmp/a")" 'Project "proj-a" loaded into Sherpa'

# b) local, failing detect -> does not match.
mkyaml "$tmp/b/.sherpa/project.yaml" proj-b "exit 1"
m=$(msg "$tmp/b")
assert_not_contains b-local-failing-detect "$m" "proj-b"
assert_contains b-falls-to-no-match "$m" "no project pack matched"

# d/e) workspace pack matches iff detect exits 0.
mkyaml "$tmp/pd/proj-d/project.yaml" proj-d "exit 0"
assert_contains d-workspace-detect0 "$(WORKFLOW_PACKS_DIR="$tmp/pd" msg "$tmp/cwd-d")" 'Project "proj-d" loaded into Sherpa'
mkyaml "$tmp/pe/proj-e/project.yaml" proj-e "exit 1"
assert_not_contains e-workspace-detect1 "$(WORKFLOW_PACKS_DIR="$tmp/pe" msg "$tmp/cwd-e")" "proj-e"

# f) workspace pack with no detect at all never matches.
mkyaml "$tmp/pf/proj-f/project.yaml" proj-f
assert_not_contains f-workspace-no-detect "$(WORKFLOW_PACKS_DIR="$tmp/pf" msg "$tmp/cwd-f")" "proj-f"

# g) local beats a matching workspace candidate.
mkyaml "$tmp/g/.sherpa/project.yaml" proj-g-local
mkyaml "$tmp/pg/proj-g-ws/project.yaml" proj-g-ws "exit 0"
mg=$(WORKFLOW_PACKS_DIR="$tmp/pg" msg "$tmp/g")
assert_contains g-local-wins "$mg" "proj-g-local"
assert_not_contains g-workspace-loses "$mg" "proj-g-ws"

# h) WORKFLOW_PACK: line carries only name=/configPath=, no content leak.
mkyaml "$tmp/h/.sherpa/project.yaml" proj-h "exit 0"
echo "knowledge: leak" >>"$tmp/h/.sherpa/project.yaml"
oh=$(ctx "$tmp/h")
assert_contains h-line-only "$oh" "WORKFLOW_PACK: name=proj-h configPath=$tmp/h/.sherpa/project.yaml"
assert_not_contains h-no-leak "$oh" "leak"

# h2/h3/h4) session.md is inlined, framed, and truncated at 4 KB.
mkyaml "$tmp/h2/.sherpa/project.yaml" proj-h2 "exit 0"
echo -n "Always run tests." >"$tmp/h2/.sherpa/session.md"
oh2=$(ctx "$tmp/h2")
after_h2="${oh2#*"WORKFLOW_PACK: name=proj-h2 configPath=$tmp/h2/.sherpa/project.yaml"}"
assert_contains h2-session-framed "$after_h2" "PROJECT SESSION RULES"
assert_contains h2-session-content "$after_h2" "Always run tests."
mkyaml "$tmp/h3/.sherpa/project.yaml" proj-h3 "exit 0"
assert_not_contains h3-no-session-no-rules "$(ctx "$tmp/h3")" "PROJECT SESSION RULES"
mkyaml "$tmp/h4/.sherpa/project.yaml" proj-h4 "exit 0"
head -c 5000 /dev/zero | tr '\0' 'x' >"$tmp/h4/.sherpa/session.md"
exp_h4="$(head -c 4096 "$tmp/h4/.sherpa/session.md")"$'\n'"(session.md truncated at 4 KB — keep it short)"
assert_contains h4-truncated-4kb "$(ctx "$tmp/h4")" "$exp_h4"

# i) no pack matches -> layer-selection primer still force-loaded.
mkdir -p "$tmp/nomatch"
assert_contains i-primer-loaded "$(ctx "$tmp/nomatch")" "check whether one of these fits"
assert_contains i-no-match-message "$(msg "$tmp/nomatch")" "no project pack matched"
[ "$fail" -eq 0 ] && echo "PASS: all resolution cases" || echo "FAILED"
exit "$fail"
