#!/usr/bin/env bash
# Self-check for resolve-project-pack.sh and resolve-pack-value.sh. Runs the
# real scripts against temp fixtures and asserts their output. No framework.
#
# Schema: project.yaml/.yml carries only `name` and optional `detect`. Local
# candidate: $cwd/.sherpa/project.yaml|.yml (detect optional). Workspace
# candidates: <packs dir>/*/project.yaml|.yml (detect required). Content is
# fetched lazily via `resolve-pack-value.sh <configPath> [frame|shape|implement]`.
set -u
unset SHERPA_CONFIG_DIR

here=$(cd "$(dirname "$0")" && pwd)
resolver="$here/resolve-project-pack.sh"
value_script="$here/resolve-pack-value.sh"

command -v yq >/dev/null 2>&1 || { echo "SKIP: yq not installed"; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not installed"; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0

run() { printf '{"cwd":"%s"}' "$1" | bash "$resolver"; }
ctx() { run "$1" | jq -r '.hookSpecificOutput.additionalContext // ""'; }
msg() { run "$1" | jq -r '.systemMessage // ""'; }
mkyaml() { mkdir -p "$(dirname "$1")"; { echo "name: $2"; [ -n "${3:-}" ] && echo "detect: \"$3\""; } >"$1"; }

assert_contains() { case "$2" in *"$3"*) ;; *) echo "FAIL [$1]: expected contains: $3 -- got: $2"; fail=1 ;; esac; }
assert_not_contains() { case "$2" in *"$3"*) echo "FAIL [$1]: expected NOT contains: $3 -- got: $2"; fail=1 ;; esac; }
assert_eq() { [ "$2" = "$3" ] || { echo "FAIL [$1]: expected: $3 -- got: $2"; fail=1; }; }
assert_exit() { [ "$2" -eq "$3" ] || { echo "FAIL [$1]: expected exit $3, got $2"; fail=1; }; }

# --- resolve-project-pack.sh ---

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

# --- resolve-pack-value.sh ---
# u) root only.
mkdir -p "$tmp/vu"
echo -n "ROOT" >"$tmp/vu/context.md"
assert_eq u-root-only "$("$value_script" "$tmp/vu/project.yaml")" "ROOT"
# v) root + layer, exactly one blank line between.
mkdir -p "$tmp/vv/shape"
echo -n "ROOT" >"$tmp/vv/context.md"
echo -n "LAYER" >"$tmp/vv/shape/context.md"
assert_eq v-root-plus-layer "$("$value_script" "$tmp/vv/project.yaml" shape)" "$(printf 'ROOT\n\nLAYER')"
# w) layer present, root absent -> prints layer only, no stderr.
mkdir -p "$tmp/vw/implement"
echo -n "LAYER-ONLY" >"$tmp/vw/implement/context.md"
ow=$("$value_script" "$tmp/vw/project.yaml" implement 2>"$tmp/vw.err")
assert_eq w-layer-only "$ow" "LAYER-ONLY"
assert_eq w-no-stderr "$(cat "$tmp/vw.err")" ""
# x) root present, layer absent -> prints root only, no stderr.
mkdir -p "$tmp/vx"
echo -n "ROOT-ONLY" >"$tmp/vx/context.md"
ox=$("$value_script" "$tmp/vx/project.yaml" frame 2>"$tmp/vx.err")
assert_eq x-root-only "$ox" "ROOT-ONLY"
assert_eq x-no-stderr "$(cat "$tmp/vx.err")" ""
# y) neither present -> empty stdout/stderr, exit 0.
mkdir -p "$tmp/vy"
oy=$("$value_script" "$tmp/vy/project.yaml" frame 2>"$tmp/vy.err"); ys=$?
assert_eq y-empty-stdout "$oy" ""
assert_eq y-empty-stderr "$(cat "$tmp/vy.err")" ""
assert_exit y-exit-0 "$ys" 0
# z) unknown layer -> exit 1 with stderr.
mkdir -p "$tmp/vz"
"$value_script" "$tmp/vz/project.yaml" bogus >/dev/null 2>"$tmp/vz.err"; zs=$?
assert_exit z-exit-1 "$zs" 1
assert_contains z-stderr-names-it "$(cat "$tmp/vz.err")" "bogus"
# aa) no configPath -> exit 1.
"$value_script" >/dev/null 2>"$tmp/vaa.err"; aas=$?
assert_exit aa-no-configpath-exit-1 "$aas" 1
[ "$fail" -eq 0 ] && echo "PASS: all resolution cases" || echo "FAILED"
exit "$fail"
