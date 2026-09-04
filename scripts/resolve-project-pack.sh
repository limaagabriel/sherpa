#!/usr/bin/env bash
# Generic project-pack resolver for sherpa's SessionStart hook.
#
# Reads the hook payload (JSON) on stdin, scans per-project YAML configs, and runs
# each config's `detect`. On the first match it emits additionalContext = the
# layer-selection primer, a bare `WORKFLOW_PACK: name=<name> configPath=<path>` line,
# and — when the matched pack has a `session.md` — a framing line plus that file's
# content (truncated at 4 KB) labeled as binding rules. Also emits a `systemMessage`
# naming the loaded pack, or "running generic" on no match.
#
# Config candidates, highest precedence first:
#   <cwd>/.sherpa/project.yaml|.yml   project-local, single canonical location
#   Workspace packs dir (<dir>/*/project.yaml|.yml), where <dir> is $SHERPA_CONFIG_DIR/
#   projects if set, else $WORKFLOW_PACKS_DIR itself if set, else
#   ${XDG_CONFIG_HOME:-$HOME/.config}/sherpa/projects (plus the legacy
#   $HOME/.claude/sherpa/projects read-fallback dir).
# `detect` is optional for project-local configs (file presence is the detection),
# required for workspace configs. Every other content-bearing pack value is a fixed
# convention path resolved lazily by a consuming skill via scripts/resolve-pack-value.sh
# — never read or inlined here. Missing jq exits silently; missing yq still emits the
# primer plus a warning. Never errors out. Pi's .pi/extensions/sherpa.ts forwards this.

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
  if [ -f "$base/session.md" ]; then
    size=$(wc -c <"$base/session.md" 2>/dev/null) || size=0
    if [ "$size" -gt 4096 ]; then
      session=$(head -c 4096 "$base/session.md")$'\n'"(session.md truncated at 4 KB — keep it short)"
    else
      session=$(cat "$base/session.md" 2>/dev/null)
    fi
    ctx="$ctx"$'\n\n'"PROJECT SESSION RULES — from $base/session.md. Follow them before any other tool, skill, or answer."$'\n'"$session"
  fi
  msg="Project \"$name\" loaded into Sherpa from $config 🏔️"
  emit_result "$msg" "$ctx"
done

# No pack matched — tell the user no project-specific knowledge was loaded,
# but still force-load the layer-selection primer.
emit_result "🏔️ sherpa: no project pack matched this repo — running generic (no project-specific knowledge loaded)." "$PRIMER"
