#!/usr/bin/env bash
# Generic project-pack resolver for sherpa's SessionStart hook.
#
# Reads the hook payload (JSON) on stdin, scans for per-project YAML configs, and
# runs each config's `detect` command. On the first match it emits a SessionStart
# additionalContext ordered as: the layer-selection primer, then a bare `WORKFLOW_PACK:`
# announcement carrying only `name=<name> configPath=<path>` (nothing from the config's
# `pack` map is eagerly inlined — every value there, `knowledge` and every other
# key alike, is resolved lazily by the consuming layer skill via scripts/resolve-pack-value.sh
# and scripts/resolve-pack-basedir.sh, given `configPath`), and a user-facing
# `systemMessage` naming the loaded pack. On no match it emits a `systemMessage` saying
# the engine runs generic (so the user knows no project knowledge loaded).
#
# `session` (the config's SessionStart-hook prose, formerly `context`) is never
# read or emitted by this script — using-sherpa's SKILL.md HARD GATE fully owns its
# delivery via lazy resolution (scripts/resolve-pack-value.sh <configPath> session),
# triggered off the `WORKFLOW_PACK:` line's configPath. This keeps `session` off the
# hook-truncation-sensitive path entirely, at the cost of a required lazy fetch by
# the consuming skill.
#
# Config candidates, highest precedence first:
#   <cwd>/.sherpa/project.yaml|.yml      project-local, single canonical location (single file)
#   Workspace packs dir (many, one dir per pack: <dir>/*/project.yaml|.yml), chosen by
#   this precedence:
#     1. $SHERPA_CONFIG_DIR set   -> packs dir is $SHERPA_CONFIG_DIR/projects
#        SHERPA_CONFIG_DIR names the sherpa config ROOT, not the packs dir itself, so
#        packs resolve at $SHERPA_CONFIG_DIR/projects/<name>/project.yaml|.yml. This is
#        the var for relocating sherpa's whole config root (packs plus any future
#        non-pack config), for pack authors who don't want to live under ~/.config.
#     2. else $WORKFLOW_PACKS_DIR set -> packs dir is $WORKFLOW_PACKS_DIR (unchanged)
#        WORKFLOW_PACKS_DIR points DIRECTLY at the packs dir, no `/projects` suffix, so
#        packs resolve at $WORKFLOW_PACKS_DIR/<name>/project.yaml|.yml. This var can
#        only move the packs dir, never the root above it.
#     3. else -> ${XDG_CONFIG_HOME:-$HOME/.config}/sherpa/projects, and
#        $HOME/.claude/sherpa/projects is also scanned as a legacy read-fallback
#        workspace dir, after the XDG path, using the same per-pack layout.
# First config whose detect matches wins, so a project-local pack overrides the workspace.
# `detect` is optional for project-local configs (file presence at that fixed path is
# the detection) and must never be relied on there; it's required for workspace configs
# (one dir shared by many projects).
# Config schema (camelCase): name, detect (a command; exit 0 = match; optional for
# project-local). Every content-bearing value (session, context, and the frame/shape/
# implement section keys) is now a fixed convention path resolved by
# scripts/resolve-pack-value.sh relative to scripts/resolve-pack-basedir.sh's output —
# no YAML pointer keys are read for them anymore. See packs/README.md for the full
# 9-key convention-path table.
#
# Nothing content-bearing (neither `context`/`session` nor any frame/shape/implement
# key) is read or inlined by this script anymore — the `WORKFLOW_PACK:` line carries
# only `name=` and `configPath=`. A consuming layer skill fetches `session`, `context`,
# or any other convention key's resolved value lazily, at the point it's actually
# needed, by calling scripts/resolve-pack-value.sh <configPath> <key> (which resolves
# against scripts/resolve-pack-basedir.sh <configPath>'s output: always the config
# file's own directory, project-local or workspace alike).
#
# jq builds every JSON payload this script emits, so a missing jq means nothing can be
# emitted at all — the script exits 0 silently. yq only parses pack YAML, so a missing yq
# still emits the using-sherpa primer plus a systemMessage warning that packs are disabled.
#
# Never errors out: a failing SessionStart hook must not block the session.
#
# Assumption (not independently verified in this session): Codex's hook runtime
# consumes hookSpecificOutput.additionalContext the same way Claude Code's SessionStart
# hook does. This is inferred from Codex's explicit hooks.json wiring in
# .codex-plugin/plugin.json, paired with Claude Code's directory-convention pickup of
# the same hooks/hooks.json file — not a matching manifest declaration on the Claude
# side. No Codex harness was run here to confirm it. By contrast, Pi's consumption IS
# verified directly: .pi/extensions/sherpa.ts's resolvePackContext() reads this script's
# JSON stdout and forwards additionalContext verbatim.

input=$(cat 2>/dev/null) || exit 0
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
[ -n "$cwd" ] || exit 0

command -v jq >/dev/null 2>&1 || exit 0

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRIMER=$(sed -n '/^---$/,/^---$/!p' "$dir/../skills/using-sherpa/SKILL.md")

emit_result() {
  jq -n --arg msg "$1" --arg ctx "$2" \
    '{systemMessage:$msg, hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}' 2>/dev/null
  exit 0
}

command -v yq >/dev/null 2>&1 || emit_result \
  "🏔️ sherpa: yq not found — project packs disabled (install yq v4+). Layer primer still loaded." \
  "$PRIMER"

if [ -n "${SHERPA_CONFIG_DIR:-}" ]; then
  packs_dirs=("$SHERPA_CONFIG_DIR/projects")
elif [ -n "${WORKFLOW_PACKS_DIR:-}" ]; then
  packs_dirs=("$WORKFLOW_PACKS_DIR")
else
  packs_dirs=("${XDG_CONFIG_HOME:-$HOME/.config}/sherpa/projects" "$HOME/.claude/sherpa/projects")
fi

shopt -s nullglob
local_candidates=(
  "$cwd/.sherpa/project.yaml" "$cwd/.sherpa/project.yml"
)
candidates=("${local_candidates[@]}")
for _pd in "${packs_dirs[@]}"; do candidates+=("$_pd"/*/project.yaml "$_pd"/*/project.yml); done

for config in "${candidates[@]}"; do
  [ -f "$config" ] || continue
  detect=$(yq '.detect // ""' "$config" 2>/dev/null) || continue
  # Base dir is always the config file's own directory now — local and
  # workspace configs alike (see resolve-pack-basedir.sh).
  base=$(cd "$(dirname "$config")" 2>/dev/null && pwd) || base=$(dirname "$config")

  local_match=0
  case "$config" in
    "$cwd/.sherpa/project.yaml"|"$cwd/.sherpa/project.yml") local_match=1 ;;
  esac

  # Project-local configs live at a fixed path under $cwd — finding the file
  # there already proves the project is active, so `detect` is optional.
  # Workspace configs share one dir across many projects, so a real `detect`
  # is required to pick the right one.
  if [ -n "$detect" ]; then
    ( cd "$base" 2>/dev/null && CWD="$cwd" bash -c "$detect" ) >/dev/null 2>&1 || continue
  elif [ "$local_match" -ne 1 ]; then
    continue
  fi

  # Matched. Build the WORKFLOW_PACK line from name + configPath only — nothing
  # from the pack map (knowledge or any other key) is eagerly inlined anymore;
  # a consuming layer skill fetches those lazily via resolve-pack-value.sh.
  name=$(yq '.name // ""' "$config" 2>/dev/null)
  line="WORKFLOW_PACK: name=$name"
  case "$config" in
    *" "*)
      esc="${config//\\/\\\\}"
      esc="${esc//\"/\\\"}"
      line="$line configPath=\"$esc\"" ;;
    *) line="$line configPath=$config" ;;
  esac

  ctx="$PRIMER"$'\n\n'"$line"
  msg="Project \"$name\" loaded into Sherpa from $config 🏔️"
  emit_result "$msg" "$ctx"
done

# No pack matched — tell the user no project-specific knowledge was loaded,
# but still force-load the layer-selection primer.
emit_result "🏔️ sherpa: no project pack matched this repo — running generic (no project-specific knowledge loaded)." "$PRIMER"
