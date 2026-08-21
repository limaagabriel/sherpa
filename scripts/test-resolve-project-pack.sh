#!/usr/bin/env bash
# Self-check for resolve-project-pack.sh, resolve-pack-basedir.sh, and
# resolve-pack-value.sh. Runs the real scripts against temp fixtures and
# asserts their output. No framework.
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

# ---------------------------------------------------------------------------
# resolve-project-pack.sh
# ---------------------------------------------------------------------------

# (a) project-local .codex/sherpa.yaml — matches, and the WORKFLOW_PACK: line
# carries only name=/configPath= — the pack's command key is NOT eagerly
# inlined (that's resolve-pack-value.sh's job now, given configPath).
repo="$tmp/repo"
mkdir -p "$repo/.codex"
cat >"$repo/.codex/sherpa.yaml" <<'YAML'
name: proj-a
detect: "exit 0"
pack:
  implement:
    codeStyleRules: cat ./rules.md
YAML
out=$(ctx "$repo")
assert_not_contains "a/command-not-inlined" "$out" "cat ./rules.md"
assert_not_contains "a/key-not-inlined" "$out" "implement.codeStyleRules"
assert_contains "a/message" "$(msg "$repo")" "Project \"proj-a\" loaded into Sherpa from $repo/.codex/sherpa.yaml 🏔️"
assert_contains "a/primer" "$out" "check whether one of these fits"
# configPath, bare path (no spaces) — unquoted
assert_contains "a/configPath-bare" "$out" "configPath=$repo/.codex/sherpa.yaml"
assert_contains "a/name" "$out" "WORKFLOW_PACK: name=proj-a"

# (b) workspace pack under a .claude ancestor — still matches and announces by
# name; the base-dir question (own dir vs walk-up to .claude) now belongs to
# resolve-pack-basedir.sh, covered separately below in (am).
ws_home="$tmp/home"
packs="$ws_home/.claude/sherpa/projects"
mkdir -p "$packs/proj-b"
cat >"$packs/proj-b/project.yaml" <<'YAML'
name: proj-b
detect: "exit 0"
pack:
  decompose:
    architectureRules: cat ./arch.md
YAML
cleancwd="$tmp/elsewhere"
mkdir -p "$cleancwd"
out=$(WORKFLOW_PACKS_DIR="$packs" ctx "$cleancwd")
assert_contains "b/message" "$out" "WORKFLOW_PACK: name=proj-b"
assert_not_contains "b/command-not-inlined" "$out" "cat ./arch.md"

# (d) configPath with a space — must be double-quoted in the emitted line
# (matching the pre-existing escaping convention for other space-containing
# values); the base-dir-quoting/runnable-command concern for space-containing
# paths now belongs to resolve-pack-value.sh, covered separately below in (ar).
repo_d="$tmp/repo d"
mkdir -p "$repo_d/.codex"
cat >"$repo_d/.codex/sherpa.yaml" <<'YAML'
name: proj-d
detect: "exit 0"
pack:
  implement:
    codeStyleRules: cat ./rules.md
YAML
out=$(ctx "$repo_d")
assert_contains "d/configPath-quoted" "$out" "configPath=\"$repo_d/.codex/sherpa.yaml\""
assert_not_contains "d/command-not-inlined" "$out" "cat ./rules.md"

# (f) project-local .pi/sherpa.yaml — same shape as (a)
repo_f="$tmp/repof"
mkdir -p "$repo_f/.pi"
cat >"$repo_f/.pi/sherpa.yaml" <<'YAML'
name: proj-f
detect: "exit 0"
pack:
  implement:
    codeStyleRules: cat ./rules.md
YAML
out=$(ctx "$repo_f")
assert_not_contains "f/command-not-inlined" "$out" "cat ./rules.md"
assert_contains "f/message" "$(msg "$repo_f")" "Project \"proj-f\" loaded into Sherpa from $repo_f/.pi/sherpa.yaml 🏔️"

# (g) a bare top-level `knowledge`, a nested `implement.knowledge`, and a
# sibling command key (`implement.validate`) coexist in the same pack — none
# of them, knowledge or command key alike, appear in the emitted line in any
# form (as a key=value pair or as bare raw prose/value); only name=/configPath=
# survive.
repo_g="$tmp/repog"
mkdir -p "$repo_g/.claude"
cat >"$repo_g/.claude/sherpa.yaml" <<'YAML'
name: proj-g
detect: "exit 0"
pack:
  knowledge: "Top-level project prose."
  implement:
    knowledge: "Implement-section prose."
    validate: /my-validate-skill
YAML
out=$(ctx "$repo_g")
assert_not_contains "g/top-level-knowledge" "$out" 'knowledge='
assert_not_contains "g/nested-knowledge" "$out" 'implement.knowledge='
assert_not_contains "g/nested-validate-key" "$out" "implement.validate"
assert_not_contains "g/no-cross-leak-top-prose" "$out" "Top-level project prose."
assert_not_contains "g/no-cross-leak-nested-prose" "$out" "Implement-section prose."
assert_not_contains "g/no-cross-leak-validate-value" "$out" "/my-validate-skill"

# (h) project-local config with NO `detect` key still matches — file presence
# at the fixed path is the detection.
repo_h="$tmp/repoh"
mkdir -p "$repo_h/.claude"
cat >"$repo_h/.claude/sherpa.yaml" <<'YAML'
name: proj-h
pack:
  knowledge: /my-project-init
YAML
assert_contains "h/local-no-detect-matches" "$(msg "$repo_h")" "Project \"proj-h\" loaded into Sherpa"

# (i) workspace config with NO `detect` key must NOT match — one shared dir
# serves many projects, so a real `detect` is required to pick the right one.
packs_i="$tmp/packs-i"
mkdir -p "$packs_i"
cat >"$packs_i/proj-i.yaml" <<'YAML'
name: proj-i
pack:
  knowledge: /my-project-init
YAML
cleancwd_i="$tmp/elsewhere-i"
mkdir -p "$cleancwd_i"
assert_not_contains "i/workspace-no-detect-skipped" "$(WORKFLOW_PACKS_DIR="$packs_i" msg "$cleancwd_i")" "proj-i"

# (m) yq missing, jq present — resolver must still emit the primer plus a
# distinct warning systemMessage, and must exit 0 without touching pack/YAML work.
binonly="$tmp/binonly"
mkdir -p "$binonly"
for tool in bash cat jq dirname basename sed; do
  toolpath=$(command -v "$tool" 2>/dev/null) || continue
  ln -s "$toolpath" "$binonly/$tool"
done
nomatch_m="$tmp/nomatch-m"
mkdir -p "$nomatch_m"
run_masked() { printf '{"cwd":"%s"}' "$1" | PATH="$binonly" bash "$resolver"; }
out_m=$(run_masked "$nomatch_m")
rc_m=$?
assert_contains "m/primer-without-yq" "$out_m" "check whether one of these fits"
assert_contains "m/yq-warning-in-ctx" "$out_m" "yq not found"
msg_m=$(printf '%s' "$out_m" | jq -r '.systemMessage // ""')
assert_contains "m/yq-warning-message" "$msg_m" "yq not found"
[ "$rc_m" -eq 0 ] || { echo "FAIL [m/exit-0]: resolver exited $rc_m with yq masked"; fail=1; }

# (n) project-local .sherpa/sherpa.yaml — same shape as (a)/(f)
repo_n="$tmp/repo-sherpa"
mkdir -p "$repo_n/.sherpa"
cat >"$repo_n/.sherpa/sherpa.yaml" <<'YAML'
name: proj-n
detect: "exit 0"
pack:
  implement:
    codeStyleRules: cat ./rules.md
YAML
out=$(ctx "$repo_n")
assert_not_contains "n/command-not-inlined" "$out" "cat ./rules.md"
assert_contains "n/message" "$(msg "$repo_n")" "Project \"proj-n\" loaded into Sherpa from $repo_n/.sherpa/sherpa.yaml 🏔️"

# (o) .sherpa wins over a co-present .claude — .sherpa is first in local_candidates
repo_o="$tmp/repoo"
mkdir -p "$repo_o/.sherpa" "$repo_o/.claude"
cat >"$repo_o/.sherpa/sherpa.yaml" <<'YAML'
name: proj-sherpa-win
detect: "exit 0"
pack:
  knowledge: "sherpa wins"
YAML
cat >"$repo_o/.claude/sherpa.yaml" <<'YAML'
name: proj-claude-lose
detect: "exit 0"
pack:
  knowledge: "claude loses"
YAML
msg_o=$(msg "$repo_o")
assert_contains "o/sherpa-wins" "$msg_o" "proj-sherpa-win"
assert_not_contains "o/claude-loses" "$msg_o" "proj-claude-lose"

# (p) XDG workspace pack resolves without WORKFLOW_PACKS_DIR
xdg_p="$tmp/xdg-p"
fakehome_p="$tmp/home-p"
packs_p="$xdg_p/sherpa/projects"
mkdir -p "$packs_p/proj-p" "$fakehome_p"
cat >"$packs_p/proj-p/project.yaml" <<'YAML'
name: proj-p
detect: "exit 0"
pack:
  decompose:
    architectureRules: cat ./arch.md
YAML
cleancwd_p="$tmp/elsewhere-p"
mkdir -p "$cleancwd_p"
msg_p=$(printf '{"cwd":"%s"}' "$cleancwd_p" | env -u WORKFLOW_PACKS_DIR XDG_CONFIG_HOME="$xdg_p" HOME="$fakehome_p" bash "$resolver" | jq -r '.systemMessage // ""')
assert_contains "p/xdg-workspace-matches" "$msg_p" "Project \"proj-p\" loaded into Sherpa"

# (q) legacy .claude/sherpa/projects still resolves as a fallback when WORKFLOW_PACKS_DIR
# is unset and XDG_CONFIG_HOME points at a dir with no sherpa/projects
fakehome_q="$tmp/home-q"
legacy_q="$fakehome_q/.claude/sherpa/projects"
mkdir -p "$legacy_q/proj-q"
cat >"$legacy_q/proj-q/project.yaml" <<'YAML'
name: proj-q
detect: "exit 0"
YAML
xdg_q="$tmp/xdg-q"
mkdir -p "$xdg_q"
cleancwd_q="$tmp/elsewhere-q"
mkdir -p "$cleancwd_q"
msg_q=$(printf '{"cwd":"%s"}' "$cleancwd_q" | env -u WORKFLOW_PACKS_DIR XDG_CONFIG_HOME="$xdg_q" HOME="$fakehome_q" bash "$resolver" | jq -r '.systemMessage // ""')
assert_contains "q/legacy-fallback" "$msg_q" "Project \"proj-q\" loaded into Sherpa from $legacy_q/proj-q/project.yaml 🏔️"

# (r) XDG workspace wins over legacy .claude workspace when both have a matching pack
fakehome_r="$tmp/home-r"
legacy_r="$fakehome_r/.claude/sherpa/projects"
mkdir -p "$legacy_r/proj-legacy-lose"
cat >"$legacy_r/proj-legacy-lose/project.yaml" <<'YAML'
name: proj-legacy-lose
detect: "exit 0"
YAML
xdg_r="$tmp/xdg-r"
packs_r="$xdg_r/sherpa/projects"
mkdir -p "$packs_r/proj-xdg-win"
cat >"$packs_r/proj-xdg-win/project.yaml" <<'YAML'
name: proj-xdg-win
detect: "exit 0"
YAML
cleancwd_r="$tmp/elsewhere-r"
mkdir -p "$cleancwd_r"
msg_r=$(printf '{"cwd":"%s"}' "$cleancwd_r" | env -u WORKFLOW_PACKS_DIR XDG_CONFIG_HOME="$xdg_r" HOME="$fakehome_r" bash "$resolver" | jq -r '.systemMessage // ""')
assert_contains "r/xdg-wins" "$msg_r" "proj-xdg-win"
assert_not_contains "r/legacy-loses" "$msg_r" "proj-legacy-lose"

# (u) per-pack colocated asset executes — a workspace pack's `detect` runs from
# the pack's own dir, so a relative ./detect.sh resolves and executes from there
packs_u="$tmp/packs-u"
mkdir -p "$packs_u/proj-u"
cat >"$packs_u/proj-u/detect.sh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$packs_u/proj-u/detect.sh"
cat >"$packs_u/proj-u/project.yaml" <<'YAML'
name: proj-u
detect: "./detect.sh"
YAML
cleancwd_u="$tmp/elsewhere-u"
mkdir -p "$cleancwd_u"
assert_contains "u/colocated-detect-runs" "$(WORKFLOW_PACKS_DIR="$packs_u" msg "$cleancwd_u")" "Project \"proj-u\" loaded into Sherpa"

# (v) two workspace packs, each with its own detect keyed to a distinct cwd —
# matching doesn't cross-contaminate across for-loop iterations
packs_v="$tmp/packs-v"
mkdir -p "$packs_v/proj-v1" "$packs_v/proj-v2"
cwd_v1="$tmp/proj-v1-repo"
cwd_v2="$tmp/proj-v2-repo"
mkdir -p "$cwd_v1" "$cwd_v2"
cat >"$packs_v/proj-v1/project.yaml" <<'YAML'
name: proj-v1
detect: 'test "$CWD" = "__CWD_V1__"'
YAML
sed -i "s#__CWD_V1__#$cwd_v1#" "$packs_v/proj-v1/project.yaml"
cat >"$packs_v/proj-v2/project.yaml" <<'YAML'
name: proj-v2
detect: 'test "$CWD" = "__CWD_V2__"'
YAML
sed -i "s#__CWD_V2__#$cwd_v2#" "$packs_v/proj-v2/project.yaml"
msg_v1=$(WORKFLOW_PACKS_DIR="$packs_v" msg "$cwd_v1")
msg_v2=$(WORKFLOW_PACKS_DIR="$packs_v" msg "$cwd_v2")
assert_contains "v/pack1-matches-own-cwd" "$msg_v1" "proj-v1"
assert_not_contains "v/pack1-not-pack2" "$msg_v1" "proj-v2"
assert_contains "v/pack2-matches-own-cwd" "$msg_v2" "proj-v2"
assert_not_contains "v/pack2-not-pack1" "$msg_v2" "proj-v1"

# (w) hard cut — the old flat <name>.yaml layout under a workspace packs dir no
# longer loads; only the per-pack project.yaml layout is scanned
packs_w="$tmp/packs-w"
mkdir -p "$packs_w"
cat >"$packs_w/proj-flat.yaml" <<'YAML'
name: proj-flat
detect: "exit 0"
YAML
cleancwd_w="$tmp/elsewhere-w"
mkdir -p "$cleancwd_w"
msg_w=$(WORKFLOW_PACKS_DIR="$packs_w" msg "$cleancwd_w")
assert_not_contains "w/flat-layout-ignored" "$msg_w" "proj-flat"
assert_contains "w/no-pack-matched" "$msg_w" "no project pack matched"

# (x) workspace pack with NO `detect` key, per-pack layout — must NOT match
packs_x="$tmp/packs-x"
mkdir -p "$packs_x/proj-x"
cat >"$packs_x/proj-x/project.yaml" <<'YAML'
name: proj-x
pack:
  knowledge: /my-project-init
YAML
cleancwd_x="$tmp/elsewhere-x"
mkdir -p "$cleancwd_x"
msg_x=$(WORKFLOW_PACKS_DIR="$packs_x" msg "$cleancwd_x")
assert_not_contains "x/workspace-no-detect-skipped" "$msg_x" "proj-x"
assert_contains "x/no-pack-matched" "$msg_x" "no project pack matched"

# (y) workspace packs dir with a space in its path — the glob must still find
# it and configPath must be double-quoted correctly in the emitted line
packs_y="$tmp/my packs"
mkdir -p "$packs_y/proj-y"
cat >"$packs_y/proj-y/project.yaml" <<'YAML'
name: proj-y
detect: "exit 0"
YAML
cleancwd_y="$tmp/elsewhere-y"
mkdir -p "$cleancwd_y"
out_y=$(WORKFLOW_PACKS_DIR="$packs_y" ctx "$cleancwd_y")
assert_contains "y/space-in-packs-dir-configPath" "$out_y" "configPath=\"$packs_y/proj-y/project.yaml\""

# (z) SHERPA_CONFIG_DIR alone — packs dir is $SHERPA_CONFIG_DIR/projects
config_z="$tmp/config-z"
packs_z="$config_z/projects"
mkdir -p "$packs_z/proj-z"
cat >"$packs_z/proj-z/project.yaml" <<'YAML'
name: proj-z
detect: "exit 0"
YAML
cleancwd_z="$tmp/elsewhere-z"
mkdir -p "$cleancwd_z"
run_z() { printf '{"cwd":"%s"}' "$1" | env -u WORKFLOW_PACKS_DIR SHERPA_CONFIG_DIR="$config_z" bash "$resolver"; }
out_z=$(run_z "$cleancwd_z" | jq -r '.hookSpecificOutput.additionalContext // ""')
msg_z=$(run_z "$cleancwd_z" | jq -r '.systemMessage // ""')
assert_contains "z/sherpa-config-dir-loads" "$msg_z" "Project \"proj-z\" loaded into Sherpa"
assert_contains "z/sherpa-config-dir-projects-suffix" "$out_z" "configPath=$packs_z/proj-z/project.yaml"

# (aa) WORKFLOW_PACKS_DIR alone — packs dir is $WORKFLOW_PACKS_DIR itself, NO
# `/projects` suffix applied; unset SHERPA_CONFIG_DIR so it can't also satisfy this
packs_aa="$tmp/packs-aa"
mkdir -p "$packs_aa/proj-aa"
cat >"$packs_aa/proj-aa/project.yaml" <<'YAML'
name: proj-aa
detect: "exit 0"
YAML
cleancwd_aa="$tmp/elsewhere-aa"
mkdir -p "$cleancwd_aa"
msg_aa=$(printf '{"cwd":"%s"}' "$cleancwd_aa" | env -u SHERPA_CONFIG_DIR WORKFLOW_PACKS_DIR="$packs_aa" bash "$resolver" | jq -r '.systemMessage // ""')
assert_contains "aa/workflow-packs-dir-no-suffix-loads" "$msg_aa" "Project \"proj-aa\" loaded into Sherpa"

# (ab) both set — SHERPA_CONFIG_DIR wins over WORKFLOW_PACKS_DIR
config_ab="$tmp/config-ab"
packs_ab_sherpa="$config_ab/projects"
mkdir -p "$packs_ab_sherpa/proj-ab-sherpa-win"
cat >"$packs_ab_sherpa/proj-ab-sherpa-win/project.yaml" <<'YAML'
name: proj-ab-sherpa-win
detect: "exit 0"
YAML
packs_ab_workflow="$tmp/packs-ab-workflow"
mkdir -p "$packs_ab_workflow/proj-ab-workflow-lose"
cat >"$packs_ab_workflow/proj-ab-workflow-lose/project.yaml" <<'YAML'
name: proj-ab-workflow-lose
detect: "exit 0"
YAML
cleancwd_ab="$tmp/elsewhere-ab"
mkdir -p "$cleancwd_ab"
msg_ab=$(printf '{"cwd":"%s"}' "$cleancwd_ab" | env SHERPA_CONFIG_DIR="$config_ab" WORKFLOW_PACKS_DIR="$packs_ab_workflow" bash "$resolver" | jq -r '.systemMessage // ""')
assert_contains "ab/sherpa-config-dir-wins" "$msg_ab" "proj-ab-sherpa-win"
assert_not_contains "ab/workflow-packs-dir-loses" "$msg_ab" "proj-ab-workflow-lose"

# (ad) nothing under `pack` appears in the emitted line, at any nesting depth —
# proves the resolver drops the WHOLE pack map (not just `knowledge`), while
# still emitting name=/configPath=.
repo_ad="$tmp/repoad"
mkdir -p "$repo_ad/.claude"
cat >"$repo_ad/.claude/sherpa.yaml" <<'YAML'
name: proj-ad
detect: "exit 0"
pack:
  knowledge: "Top-level prose."
  frame:
    knowledge: "Frame prose."
  shape:
    knowledge: "Shape prose."
  decompose:
    knowledge: "Decompose prose."
  implement:
    knowledge: "Implement prose."
    codeStyleRules: cat ./rules.md
YAML
out=$(ctx "$repo_ad")
assert_not_contains "ad/knowledge-absent" "$out" "knowledge="
assert_not_contains "ad/frame-knowledge-absent" "$out" "frame.knowledge="
assert_not_contains "ad/shape-knowledge-absent" "$out" "shape.knowledge="
assert_not_contains "ad/decompose-knowledge-absent" "$out" "decompose.knowledge="
assert_not_contains "ad/implement-knowledge-absent" "$out" "implement.knowledge="
assert_not_contains "ad/implement-codeStyleRules-absent" "$out" "implement.codeStyleRules"
assert_contains "ad/name-and-configPath-present" "$out" "WORKFLOW_PACK: name=proj-ad configPath=$repo_ad/.claude/sherpa.yaml"

# (ae) context is never emitted — a config's top-level `context` (formerly
# `sessionInstructions`) must not appear anywhere in additionalContext; only the
# primer and the WORKFLOW_PACK: line survive. using-sherpa's HARD GATE fetches
# `context` lazily via resolve-pack-value.sh, off the WORKFLOW_PACK: configPath.
repo_ae="$tmp/repoae"
mkdir -p "$repo_ae/.claude"
cat >"$repo_ae/.claude/sherpa.yaml" <<'YAML'
name: proj-ae
detect: "exit 0"
context: ./context.md
sessionInstructions: "Always run the project's lint step first."
YAML
out=$(ctx "$repo_ae")
assert_not_contains "ae/context-key-not-inlined" "$out" "./context.md"
assert_not_contains "ae/legacy-sessionInstructions-not-inlined" "$out" "Always run the project's lint step first."
assert_contains "ae/workflow-pack-still-present" "$out" "WORKFLOW_PACK: name=proj-ae"

# (af) legacy sessionInstructions key, still present in an unmigrated config —
# must NOT be read or emitted either; the resolver no longer knows this key at
# all, migrated or not.
repo_af="$tmp/repoaf"
mkdir -p "$repo_af/.claude"
cat >"$repo_af/.claude/sherpa.yaml" <<'YAML'
name: proj-af
detect: "exit 0"
sessionInstructions: "Keep commits small."
YAML
out_af=$(ctx "$repo_af")
assert_not_contains "af/legacy-key-absent" "$out_af" "Keep commits small."
assert_contains "af/primer-still-present" "$out_af" "check whether one of these fits"

# (e) no pack matches — primer must still be force-loaded via additionalContext
nomatch="$tmp/nomatch"
mkdir -p "$nomatch"
out=$(ctx "$nomatch")
assert_contains "e/primer" "$out" "check whether one of these fits"

# ---------------------------------------------------------------------------
# resolve-pack-basedir.sh
# ---------------------------------------------------------------------------

# (aj) project-local .claude/sherpa.yaml, immediate (0-hop) — the marker dir
# IS the config's own dir, so the walk-up returns it trivially.
repo_aj="$tmp/basedir-aj/repo/.claude"
mkdir -p "$repo_aj"
assert_eq "aj/project-local-immediate" "$("$basedir_script" "$repo_aj/sherpa.yaml")" "$repo_aj"

# (ak) project-local .codex/sherpa.yaml, nested several levels deeper than the
# marker dir — proves the walk-up actually climbs multiple levels, not just
# checks the immediate parent.
marker_ak="$tmp/basedir-ak/repo/.codex"
nested_ak="$marker_ak/some/nested/place"
mkdir -p "$nested_ak"
: >"$nested_ak/sherpa.yaml"
assert_eq "ak/project-local-multi-hop-walkup" "$("$basedir_script" "$nested_ak/sherpa.yaml")" "$marker_ak"

# (al) workspace project.yaml, no ancestor named .sherpa/.claude/.codex/.pi
# anywhere — base is simply the config's own dir.
packs_al="$tmp/basedir-al/packs/proj-al"
mkdir -p "$packs_al"
assert_eq "al/workspace-own-dir" "$("$basedir_script" "$packs_al/project.yaml")" "$packs_al"

# (am) workspace project.yaml nested under a directory literally named .claude
# — must NOT walk up to it; the workspace rule is filename-driven off
# project.yaml/.yml and never walks up, regardless of ancestor names. This is
# the same edge case the pre-redesign suite covered for the old
# proximate_base()/is_local() cwd-based logic, adapted to the bare-configPath
# script.
packs_am="$tmp/basedir-am/home/.claude/sherpa/projects/proj-am"
mkdir -p "$packs_am"
assert_eq "am/workspace-under-.claude-no-walkup" "$("$basedir_script" "$packs_am/project.yaml")" "$packs_am"

# ---------------------------------------------------------------------------
# resolve-pack-value.sh
# ---------------------------------------------------------------------------

# (an) single path, existing file — reads .pack.knowledge (bare top-level key)
# and prints its contents.
repo_an="$tmp/value-an/.claude"
mkdir -p "$repo_an"
cat >"$repo_an/sherpa.yaml" <<'YAML'
name: proj-an
pack:
  knowledge: ./notes.md
YAML
echo -n "project notes" >"$repo_an/notes.md"
out_an=$("$value_script" "$repo_an/sherpa.yaml" knowledge)
assert_eq "an/single-path-content" "$out_an" "project notes"

# (at) bare `context` key reads the config's TOP-LEVEL `.context`, not
# `.pack.context` — `context` is a sibling of `pack`, not nested under it
# (packs/README.md, packs/TEMPLATE.yaml), and using-sherpa's HARD GATE calls
# this script with the bare key `context`. A decoy `.pack.context` must be
# ignored in favor of the real top-level value.
repo_at="$tmp/value-at/.claude"
mkdir -p "$repo_at"
cat >"$repo_at/sherpa.yaml" <<'YAML'
name: proj-at
context: ./context.md
pack:
  context: ./decoy.md
YAML
echo -n "top-level context prose" >"$repo_at/context.md"
echo -n "DECOY, must not be read" >"$repo_at/decoy.md"
out_at=$("$value_script" "$repo_at/sherpa.yaml" context)
assert_eq "at/context-reads-top-level" "$out_at" "top-level context prose"

# (ao) array of paths, existing files — concatenation happens in listed order
repo_ao="$tmp/value-ao/.claude"
mkdir -p "$repo_ao"
cat >"$repo_ao/sherpa.yaml" <<'YAML'
name: proj-ao
pack:
  implement:
    codeStyleRules:
      - ./first.md
      - ./second.md
YAML
echo -n "FIRST" >"$repo_ao/first.md"
echo -n "SECOND" >"$repo_ao/second.md"
out_ao=$("$value_script" "$repo_ao/sherpa.yaml" implement.codeStyleRules)
pos_first=$(printf '%s' "$out_ao" | grep -bo "FIRST" | head -1 | cut -d: -f1)
pos_second=$(printf '%s' "$out_ao" | grep -bo "SECOND" | head -1 | cut -d: -f1)
assert_contains "ao/array-has-first" "$out_ao" "FIRST"
assert_contains "ao/array-has-second" "$out_ao" "SECOND"
if [ -z "$pos_first" ] || [ -z "$pos_second" ] || [ "$pos_first" -ge "$pos_second" ]; then
  echo "FAIL [ao/array-order]: expected FIRST before SECOND in: $out_ao"
  fail=1
fi
# first.md has no trailing newline of its own — without a separator its last
# line would glue directly onto second.md's first line (e.g. "FIRSTSECOND").
# A literal newline must sit between them in the output.
assert_contains "ao/array-separator-newline" "$out_ao" "$(printf 'FIRST\nSECOND')"
assert_not_contains "ao/array-not-glued" "$out_ao" "FIRSTSECOND"

# (ap) array with one missing entry — the missing entry is skipped with a
# stderr warning naming it, but the rest still resolves (not all-or-nothing).
repo_ap="$tmp/value-ap/.claude"
mkdir -p "$repo_ap"
cat >"$repo_ap/sherpa.yaml" <<'YAML'
name: proj-ap
pack:
  knowledge:
    - ./present-a.md
    - ./missing.md
    - ./present-b.md
YAML
echo -n "PRESENT-A" >"$repo_ap/present-a.md"
echo -n "PRESENT-B" >"$repo_ap/present-b.md"
out_ap=$("$value_script" "$repo_ap/sherpa.yaml" knowledge 2>"$tmp/value-ap-stderr.txt")
err_ap=$(cat "$tmp/value-ap-stderr.txt")
assert_contains "ap/present-a-resolves" "$out_ap" "PRESENT-A"
assert_contains "ap/present-b-resolves" "$out_ap" "PRESENT-B"
assert_contains "ap/missing-warns-on-stderr" "$err_ap" "missing.md"

# (aq) --raw mode — prints the literal command string with the `cd <base> &&`
# prefix, without reading any file (the referenced "value" is a shell command,
# not a path, and is never treated as one).
repo_aq="$tmp/value-aq/.claude"
mkdir -p "$repo_aq"
cat >"$repo_aq/sherpa.yaml" <<'YAML'
name: proj-aq
pack:
  implement:
    validate: cat ./validate.sh
YAML
# validate.sh deliberately does not exist here — --raw must never try to read
# it as a file; the exact-match assertion below is only possible if the value
# was treated as a literal command string, not a path.
out_aq=$("$value_script" "$repo_aq/sherpa.yaml" implement.validate --raw)
assert_eq "aq/raw-cd-prefix" "$out_aq" "cd '$repo_aq' && cat ./validate.sh"

# (ar) --raw mode, absolute value — an authored value starting with `/` is
# printed as-is, with no `cd` prefix (matches the old resolve_pack_value's
# absolute-value passthrough branch).
repo_ar="$tmp/value-ar/.claude"
mkdir -p "$repo_ar"
cat >"$repo_ar/sherpa.yaml" <<'YAML'
name: proj-ar
pack:
  implement:
    validate: /my-validate-skill
YAML
out_ar=$("$value_script" "$repo_ar/sherpa.yaml" implement.validate --raw)
assert_eq "ar/raw-absolute-passthrough" "$out_ar" "/my-validate-skill"

# (as) --raw mode, base dir with a space — the emitted cd must single-quote
# it so a consumer's `bash -c` doesn't split it into too many args, and the
# emitted command must actually run.
repo_as="$tmp/value as/.claude"
mkdir -p "$repo_as"
cat >"$repo_as/sherpa.yaml" <<'YAML'
name: proj-as
pack:
  implement:
    validate: echo hi >out.txt
YAML
out_as=$("$value_script" "$repo_as/sherpa.yaml" implement.validate --raw)
assert_eq "as/raw-quoted-base-with-space" "$out_as" "cd '$repo_as' && echo hi >out.txt"
bash -c "$out_as" >/dev/null 2>&1 || { echo "FAIL [as/raw-runnable]: emitted cmd failed: $out_as"; fail=1; }
[ -f "$repo_as/out.txt" ] || { echo "FAIL [as/raw-runnable-side-effect]: expected $repo_as/out.txt"; fail=1; }

[ "$fail" -eq 0 ] && echo "PASS: all resolution cases" || echo "FAILED"
exit "$fail"
