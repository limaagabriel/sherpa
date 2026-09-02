#!/usr/bin/env bash
# Self-check for resolve-project-pack.sh, resolve-pack-basedir.sh, and
# resolve-pack-value.sh. Runs the real scripts against temp fixtures and
# asserts their output. No framework.
#
# Current schema under test (see the 3 resolver scripts for the source of
# truth): a project.yaml/.yml config carries only `name` and an optional
# `detect` command — no `pack:` map, no dotted-array YAML keys. Every
# content-bearing value (session, context, and the frame/shape/implement
# section keys) is a fixed convention path resolved by resolve-pack-value.sh
# relative to resolve-pack-basedir.sh's output (always dirname(configPath)).
# The only local candidate is $cwd/.sherpa/project.yaml|.yml; workspace
# candidates are <packs dir>/*/project.yaml|.yml. `detect` is optional for
# the local candidate (file presence there already proves activity) and
# required for a workspace candidate.
set -u
unset SHERPA_CONFIG_DIR

here=$(cd "$(dirname "$0")" && pwd)
resolver="$here/resolve-project-pack.sh"
basedir_script="$here/resolve-pack-basedir.sh"
value_script="$here/resolve-pack-value.sh"

command -v yq >/dev/null 2>&1 || { echo "SKIP: yq not installed"; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not installed"; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail=0
run() { printf '{"cwd":"%s"}' "$1" | bash "$resolver"; }
ctx() { run "$1" | jq -r '.hookSpecificOutput.additionalContext // ""'; }
msg() { run "$1" | jq -r '.systemMessage // ""'; }

assert_contains() {
  case "$2" in
    *"$3"*) ;;
    *) echo "FAIL [$1]: expected to contain:"; echo "  $3"; echo "got:"; echo "  $2"; fail=1 ;;
  esac
}
assert_not_contains() {
  case "$2" in
    *"$3"*) echo "FAIL [$1]: expected NOT to contain:"; echo "  $3"; echo "got:"; echo "  $2"; fail=1 ;;
  esac
}
assert_eq() {
  [ "$2" = "$3" ] || { echo "FAIL [$1]: expected:"; echo "  $3"; echo "got:"; echo "  $2"; fail=1; }
}
assert_exit_code() {
  [ "$2" -eq "$3" ] || { echo "FAIL [$1]: expected exit code $3, got $2"; fail=1; }
}

# ---------------------------------------------------------------------------
# resolve-project-pack.sh
# ---------------------------------------------------------------------------

# (a) local $cwd/.sherpa/project.yaml with NO `detect` still matches — file
# presence at the fixed local path is itself the detection.
repo_a="$tmp/repo-a"
mkdir -p "$repo_a/.sherpa"
cat >"$repo_a/.sherpa/project.yaml" <<'YAML'
name: proj-a
YAML
assert_contains "a/local-no-detect-matches" "$(msg "$repo_a")" 'Project "proj-a" loaded into Sherpa'

# (b) local $cwd/.sherpa/project.yaml WITH a `detect` that fails must NOT
# match — only the ABSENCE of `detect` is an automatic local match; a
# present-but-failing `detect` is still honored.
repo_b="$tmp/repo-b"
mkdir -p "$repo_b/.sherpa"
cat >"$repo_b/.sherpa/project.yaml" <<'YAML'
name: proj-b
detect: "exit 1"
YAML
msg_b=$(msg "$repo_b")
assert_not_contains "b/local-failing-detect-not-matched" "$msg_b" "proj-b"
assert_contains "b/local-failing-detect-falls-to-no-match" "$msg_b" "no project pack matched"

# (c) local $cwd/.sherpa/project.yml (.yml extension) also matches.
repo_c="$tmp/repo-c"
mkdir -p "$repo_c/.sherpa"
cat >"$repo_c/.sherpa/project.yml" <<'YAML'
name: proj-c
YAML
assert_contains "c/local-yml-extension-matches" "$(msg "$repo_c")" 'Project "proj-c" loaded into Sherpa'

# (d) a workspace config with a real `detect` matches when it exits 0.
packs_d="$tmp/packs-d"
mkdir -p "$packs_d/proj-d"
cat >"$packs_d/proj-d/project.yaml" <<'YAML'
name: proj-d
detect: "exit 0"
YAML
cwd_d="$tmp/elsewhere-d"
mkdir -p "$cwd_d"
assert_contains "d/workspace-detect-exit0-matches" "$(WORKFLOW_PACKS_DIR="$packs_d" msg "$cwd_d")" 'Project "proj-d" loaded into Sherpa'

# (e) the same shape workspace config does NOT match when `detect` exits
# non-zero.
packs_e="$tmp/packs-e"
mkdir -p "$packs_e/proj-e"
cat >"$packs_e/proj-e/project.yaml" <<'YAML'
name: proj-e
detect: "exit 1"
YAML
cwd_e="$tmp/elsewhere-e"
mkdir -p "$cwd_e"
msg_e=$(WORKFLOW_PACKS_DIR="$packs_e" msg "$cwd_e")
assert_not_contains "e/workspace-detect-nonzero-not-matched" "$msg_e" "proj-e"
assert_contains "e/workspace-detect-nonzero-falls-to-no-match" "$msg_e" "no project pack matched"

# (f) a workspace config with NO `detect` at all must NOT match — one shared
# dir serves many projects, so `detect` is required there (unlike local).
packs_f="$tmp/packs-f"
mkdir -p "$packs_f/proj-f"
cat >"$packs_f/proj-f/project.yaml" <<'YAML'
name: proj-f
YAML
cwd_f="$tmp/elsewhere-f"
mkdir -p "$cwd_f"
msg_f=$(WORKFLOW_PACKS_DIR="$packs_f" msg "$cwd_f")
assert_not_contains "f/workspace-no-detect-not-matched" "$msg_f" "proj-f"
assert_contains "f/workspace-no-detect-falls-to-no-match" "$msg_f" "no project pack matched"

# (g) the local candidate takes precedence over a workspace candidate that
# would also match.
repo_g="$tmp/repo-g"
mkdir -p "$repo_g/.sherpa"
cat >"$repo_g/.sherpa/project.yaml" <<'YAML'
name: proj-g-local
YAML
packs_g="$tmp/packs-g"
mkdir -p "$packs_g/proj-g-ws"
cat >"$packs_g/proj-g-ws/project.yaml" <<'YAML'
name: proj-g-ws
detect: "exit 0"
YAML
msg_g=$(WORKFLOW_PACKS_DIR="$packs_g" msg "$repo_g")
assert_contains "g/local-precedence" "$msg_g" "proj-g-local"
assert_not_contains "g/workspace-loses" "$msg_g" "proj-g-ws"

# (h) the WORKFLOW_PACK: line carries only name=/configPath= — even when the
# on-disk config also has leftover content-like keys (pre-migration authoring
# habits), none of that content ever reaches additionalContext. Resolved
# values now live purely as convention-path files, fetched lazily by
# resolve-pack-value.sh, never inlined by this script.
repo_h="$tmp/repo-h"
mkdir -p "$repo_h/.sherpa"
cat >"$repo_h/.sherpa/project.yaml" <<'YAML'
name: proj-h
detect: "exit 0"
context: ./context.md
knowledge: "should never leak"
YAML
echo -n "leaked context content" >"$repo_h/.sherpa/context.md"
out_h=$(ctx "$repo_h")
assert_contains "h/workflow-pack-line-only" "$out_h" "WORKFLOW_PACK: name=proj-h configPath=$repo_h/.sherpa/project.yaml"
assert_not_contains "h/no-context-content-leak" "$out_h" "leaked context content"
assert_not_contains "h/no-knowledge-leak" "$out_h" "should never leak"

# (i) no pack matches at all — the layer-selection primer must still be
# force-loaded via additionalContext, and systemMessage says so.
nomatch_i="$tmp/nomatch-i"
mkdir -p "$nomatch_i"
out_i=$(ctx "$nomatch_i")
assert_contains "i/primer-still-loaded" "$out_i" "check whether one of these fits"
assert_contains "i/no-pack-matched-message" "$(msg "$nomatch_i")" "no project pack matched"

# (j) yq missing, jq present — resolver must still emit the primer plus a
# distinct warning systemMessage, and must exit 0 without touching pack/YAML work.
binonly="$tmp/binonly"
mkdir -p "$binonly"
for tool in bash cat jq dirname basename sed; do
  toolpath=$(command -v "$tool" 2>/dev/null) || continue
  ln -s "$toolpath" "$binonly/$tool"
done
nomatch_j="$tmp/nomatch-j"
mkdir -p "$nomatch_j"
run_masked() { printf '{"cwd":"%s"}' "$1" | PATH="$binonly" bash "$resolver"; }
out_j=$(run_masked "$nomatch_j")
rc_j=$?
assert_contains "j/primer-without-yq" "$out_j" "check whether one of these fits"
assert_contains "j/yq-warning-in-ctx" "$out_j" "yq not found"
msg_j=$(printf '%s' "$out_j" | jq -r '.systemMessage // ""')
assert_contains "j/yq-warning-message" "$msg_j" "yq not found"
assert_exit_code "j/exit-0" "$rc_j" 0

# (k) XDG workspace pack resolves without WORKFLOW_PACKS_DIR set.
xdg_k="$tmp/xdg-k"
fakehome_k="$tmp/home-k"
packs_k="$xdg_k/sherpa/projects"
mkdir -p "$packs_k/proj-k" "$fakehome_k"
cat >"$packs_k/proj-k/project.yaml" <<'YAML'
name: proj-k
detect: "exit 0"
YAML
cleancwd_k="$tmp/elsewhere-k"
mkdir -p "$cleancwd_k"
msg_k=$(printf '{"cwd":"%s"}' "$cleancwd_k" | env -u WORKFLOW_PACKS_DIR XDG_CONFIG_HOME="$xdg_k" HOME="$fakehome_k" bash "$resolver" | jq -r '.systemMessage // ""')
assert_contains "k/xdg-workspace-matches" "$msg_k" 'Project "proj-k" loaded into Sherpa'

# (l) per-pack colocated asset executes — a workspace pack's `detect` runs
# from the pack's own dir, so a relative ./detect.sh resolves and executes.
packs_l="$tmp/packs-l"
mkdir -p "$packs_l/proj-l"
cat >"$packs_l/proj-l/detect.sh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$packs_l/proj-l/detect.sh"
cat >"$packs_l/proj-l/project.yaml" <<'YAML'
name: proj-l
detect: "./detect.sh"
YAML
cleancwd_l="$tmp/elsewhere-l"
mkdir -p "$cleancwd_l"
assert_contains "l/colocated-detect-runs" "$(WORKFLOW_PACKS_DIR="$packs_l" msg "$cleancwd_l")" 'Project "proj-l" loaded into Sherpa'

# (m) two workspace packs, each with its own detect keyed to a distinct cwd —
# matching doesn't cross-contaminate across for-loop iterations.
packs_m="$tmp/packs-m"
mkdir -p "$packs_m/proj-m1" "$packs_m/proj-m2"
cwd_m1="$tmp/proj-m1-repo"
cwd_m2="$tmp/proj-m2-repo"
mkdir -p "$cwd_m1" "$cwd_m2"
cat >"$packs_m/proj-m1/project.yaml" <<'YAML'
name: proj-m1
detect: 'test "$CWD" = "__CWD_M1__"'
YAML
sed -i "s#__CWD_M1__#$cwd_m1#" "$packs_m/proj-m1/project.yaml"
cat >"$packs_m/proj-m2/project.yaml" <<'YAML'
name: proj-m2
detect: 'test "$CWD" = "__CWD_M2__"'
YAML
sed -i "s#__CWD_M2__#$cwd_m2#" "$packs_m/proj-m2/project.yaml"
msg_m1=$(WORKFLOW_PACKS_DIR="$packs_m" msg "$cwd_m1")
msg_m2=$(WORKFLOW_PACKS_DIR="$packs_m" msg "$cwd_m2")
assert_contains "m/pack1-matches-own-cwd" "$msg_m1" "proj-m1"
assert_not_contains "m/pack1-not-pack2" "$msg_m1" "proj-m2"
assert_contains "m/pack2-matches-own-cwd" "$msg_m2" "proj-m2"
assert_not_contains "m/pack2-not-pack1" "$msg_m2" "proj-m1"

# (n) hard cut — a flat <name>.yaml layout directly under a workspace packs
# dir no longer loads; only the per-pack project.yaml layout is scanned.
packs_n="$tmp/packs-n"
mkdir -p "$packs_n"
cat >"$packs_n/proj-flat.yaml" <<'YAML'
name: proj-flat
detect: "exit 0"
YAML
cleancwd_n="$tmp/elsewhere-n"
mkdir -p "$cleancwd_n"
msg_n=$(WORKFLOW_PACKS_DIR="$packs_n" msg "$cleancwd_n")
assert_not_contains "n/flat-layout-ignored" "$msg_n" "proj-flat"
assert_contains "n/no-pack-matched" "$msg_n" "no project pack matched"

# (o) workspace packs dir with a space in its path — the glob must still find
# it and configPath must be double-quoted correctly in the emitted line.
packs_o="$tmp/my packs"
mkdir -p "$packs_o/proj-o"
cat >"$packs_o/proj-o/project.yaml" <<'YAML'
name: proj-o
detect: "exit 0"
YAML
cleancwd_o="$tmp/elsewhere-o"
mkdir -p "$cleancwd_o"
out_o=$(WORKFLOW_PACKS_DIR="$packs_o" ctx "$cleancwd_o")
assert_contains "o/space-in-packs-dir-configPath" "$out_o" "configPath=\"$packs_o/proj-o/project.yaml\""

# (p) SHERPA_CONFIG_DIR alone — packs dir is $SHERPA_CONFIG_DIR/projects.
config_p="$tmp/config-p"
packs_p="$config_p/projects"
mkdir -p "$packs_p/proj-p"
cat >"$packs_p/proj-p/project.yaml" <<'YAML'
name: proj-p
detect: "exit 0"
YAML
cleancwd_p="$tmp/elsewhere-p"
mkdir -p "$cleancwd_p"
run_p() { printf '{"cwd":"%s"}' "$1" | env -u WORKFLOW_PACKS_DIR SHERPA_CONFIG_DIR="$config_p" bash "$resolver"; }
out_p=$(run_p "$cleancwd_p" | jq -r '.hookSpecificOutput.additionalContext // ""')
msg_p=$(run_p "$cleancwd_p" | jq -r '.systemMessage // ""')
assert_contains "p/sherpa-config-dir-loads" "$msg_p" 'Project "proj-p" loaded into Sherpa'
assert_contains "p/sherpa-config-dir-projects-suffix" "$out_p" "configPath=$packs_p/proj-p/project.yaml"

# (q) WORKFLOW_PACKS_DIR alone — packs dir is $WORKFLOW_PACKS_DIR itself, NO
# `/projects` suffix applied; unset SHERPA_CONFIG_DIR so it can't also satisfy this.
packs_q="$tmp/packs-q"
mkdir -p "$packs_q/proj-q"
cat >"$packs_q/proj-q/project.yaml" <<'YAML'
name: proj-q
detect: "exit 0"
YAML
cleancwd_q="$tmp/elsewhere-q"
mkdir -p "$cleancwd_q"
msg_q=$(printf '{"cwd":"%s"}' "$cleancwd_q" | env -u SHERPA_CONFIG_DIR WORKFLOW_PACKS_DIR="$packs_q" bash "$resolver" | jq -r '.systemMessage // ""')
assert_contains "q/workflow-packs-dir-no-suffix-loads" "$msg_q" 'Project "proj-q" loaded into Sherpa'

# (r) both set — SHERPA_CONFIG_DIR wins over WORKFLOW_PACKS_DIR.
config_r="$tmp/config-r"
packs_r_sherpa="$config_r/projects"
mkdir -p "$packs_r_sherpa/proj-r-sherpa-win"
cat >"$packs_r_sherpa/proj-r-sherpa-win/project.yaml" <<'YAML'
name: proj-r-sherpa-win
detect: "exit 0"
YAML
packs_r_workflow="$tmp/packs-r-workflow"
mkdir -p "$packs_r_workflow/proj-r-workflow-lose"
cat >"$packs_r_workflow/proj-r-workflow-lose/project.yaml" <<'YAML'
name: proj-r-workflow-lose
detect: "exit 0"
YAML
cleancwd_r="$tmp/elsewhere-r"
mkdir -p "$cleancwd_r"
msg_r=$(printf '{"cwd":"%s"}' "$cleancwd_r" | env SHERPA_CONFIG_DIR="$config_r" WORKFLOW_PACKS_DIR="$packs_r_workflow" bash "$resolver" | jq -r '.systemMessage // ""')
assert_contains "r/sherpa-config-dir-wins" "$msg_r" "proj-r-sherpa-win"
assert_not_contains "r/workflow-packs-dir-loses" "$msg_r" "proj-r-workflow-lose"

# ---------------------------------------------------------------------------
# resolve-pack-basedir.sh — always dirname(configPath), no filename branching
# ---------------------------------------------------------------------------

# (s) a config literally named sherpa.yaml, NOT living under any .sherpa/
# location at all — basedir is simply its own directory.
dir_s="$tmp/basedir-s/somewhere/random"
mkdir -p "$dir_s"
assert_eq "s/sherpa-yaml-anywhere-own-dir" "$("$basedir_script" "$dir_s/sherpa.yaml")" "$dir_s"

# (t) a config named project.yaml, nested arbitrarily deep — same rule: own
# directory, no ancestor walk-up of any kind.
dir_t="$tmp/basedir-t/packs/proj-x/deeply/nested"
mkdir -p "$dir_t"
assert_eq "t/project-yaml-own-dir" "$("$basedir_script" "$dir_t/project.yaml")" "$dir_t"

# ---------------------------------------------------------------------------
# resolve-pack-value.sh — fixed convention keys, file-vs-dir precedence
# ---------------------------------------------------------------------------
# Note: resolve-pack-value.sh never reads the config file's own content — it
# only calls resolve-pack-basedir.sh on the configPath to find the basedir,
# then looks for convention-path files under it. The configPath argument
# below therefore doesn't need to point at a real file, only a real directory.

# (u) single-file: <stem>.md exists alone — content printed exactly.
base_u="$tmp/value-u"
mkdir -p "$base_u/implement"
echo -n "STYLE RULES CONTENT" >"$base_u/implement/codeStyle.md"
out_u=$("$value_script" "$base_u/project.yaml" implement.codeStyle)
assert_eq "u/single-file-content" "$out_u" "STYLE RULES CONTENT"

# (v) directory: <stem>/ exists alone with 2+ *.md files, concatenated in
# `LC_ALL=C sort`-by-filename order. "10-a.md" and "2-b.md" are chosen
# because byte-order sort puts "10-" before "2-" (first differing char '1'
# < '2'), unlike a numeric-aware sort — so this actually exercises the
# documented sort rule instead of an order that would pass either way.
base_v="$tmp/value-v"
mkdir -p "$base_v/session"
echo -n "TEN" >"$base_v/session/10-a.md"
echo -n "TWO" >"$base_v/session/2-b.md"
out_v=$("$value_script" "$base_v/project.yaml" session)
assert_eq "v/dir-sorted-content" "$out_v" "$(printf 'TEN\nTWO')"

# (w) both-present: both <stem>.md and <stem>/ exist — stdout is the file's
# content only (directory content NOT included), and stderr carries the
# ambiguity warning.
base_w="$tmp/value-w"
mkdir -p "$base_w/shape/architecture"
echo -n "FILE WINS" >"$base_w/shape/architecture.md"
echo -n "DIR CONTENT, must not appear" >"$base_w/shape/architecture/extra.md"
out_w=$("$value_script" "$base_w/project.yaml" shape.architecture 2>"$tmp/value-w-stderr.txt")
err_w=$(cat "$tmp/value-w-stderr.txt")
assert_eq "w/both-present-file-wins" "$out_w" "FILE WINS"
assert_not_contains "w/both-present-dir-excluded" "$out_w" "DIR CONTENT"
assert_contains "w/both-present-ambiguity-warning" "$err_w" "ambiguous"

# (x) missing: neither <stem>.md nor <stem>/ exists — stdout empty, exit
# code 0 (non-fatal), stderr carries a warning.
base_x="$tmp/value-x"
mkdir -p "$base_x"
out_x=$("$value_script" "$base_x/project.yaml" context 2>"$tmp/value-x-stderr.txt")
x_status=$?
err_x=$(cat "$tmp/value-x-stderr.txt")
assert_eq "x/missing-empty-stdout" "$out_x" ""
assert_exit_code "x/missing-exit-0" "$x_status" 0
assert_contains "x/missing-stderr-warning" "$err_x" "missing convention path"

# (y) unrecognized key — hard failure: exit 1, stderr names the bad key.
base_y="$tmp/value-y"
mkdir -p "$base_y"
"$value_script" "$base_y/project.yaml" bogus.key >/dev/null 2>"$tmp/value-y-stderr.txt"
y_status=$?
err_y=$(cat "$tmp/value-y-stderr.txt")
assert_exit_code "y/unrecognized-key-exit-1" "$y_status" 1
assert_contains "y/unrecognized-key-stderr-names-it" "$err_y" "bogus.key"

# (z) escape hatch for the now-removed absolute-path support: a symlink AT a
# convention path resolves transparently, since `cat`/`-f` follow symlinks.
base_z="$tmp/value-z"
target_z="$tmp/value-z-target/elsewhere-style.md"
mkdir -p "$base_z/implement" "$(dirname "$target_z")"
echo -n "SYMLINKED STYLE" >"$target_z"
ln -s "$target_z" "$base_z/implement/codeStyle.md"
out_z=$("$value_script" "$base_z/project.yaml" implement.codeStyle)
assert_eq "z/symlink-resolves-transparently" "$out_z" "SYMLINKED STYLE"

# (aa) a stale 3rd argument (e.g. the old --raw mode) is a hard error — this
# script has exactly one resolution mode, so a stale caller still passing a
# mode flag must fail loud, not be silently ignored into different behavior.
base_aa="$tmp/value-aa"
mkdir -p "$base_aa/implement"
echo -n "npm test" >"$base_aa/implement/validate.md"
"$value_script" "$base_aa/project.yaml" implement.validate --raw >/dev/null 2>"$tmp/value-aa-stderr.txt"
aa_status=$?
err_aa=$(cat "$tmp/value-aa-stderr.txt")
assert_exit_code "aa/unrecognized-arg-exit-1" "$aa_status" 1
assert_contains "aa/unrecognized-arg-stderr" "$err_aa" "--raw"

[ "$fail" -eq 0 ] && echo "PASS: all resolution cases" || echo "FAILED"
exit "$fail"
