#!/usr/bin/env bash
# Generic project-pack resolver for sherpa's SessionStart hook.
#
# Reads the hook payload (JSON) on stdin, scans for per-project YAML configs, and
# runs each config's `detect` command. On the first match it emits a SessionStart
# additionalContext carrying the `WORKFLOW_PACK:` announcement (built from the
# config's `pack` map) plus the config's `sessionInstructions`, and a user-facing
# `systemMessage` naming the loaded pack. On no match it emits a `systemMessage`
# saying the engine runs generic (so the user knows no project knowledge loaded).
#
# Config candidates, highest precedence first:
#   <cwd>/.sherpa/sherpa.yaml|.yml       project-local, engine-neutral, shareable in-repo (single file)
#   <cwd>/.claude/sherpa.yaml|.yml       project-local, engine-specific, shareable in-repo (single file)
#   <cwd>/.codex/sherpa.yaml|.yml        project-local, engine-specific, shareable in-repo (single file)
#   <cwd>/.pi/sherpa.yaml|.yml           project-local, engine-specific, shareable in-repo (single file)
#   ${WORKFLOW_PACKS_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/sherpa/projects}/*.yaml|*.yml  workspace (many)
# When WORKFLOW_PACKS_DIR is unset, $HOME/.claude/sherpa/projects is also scanned as a
# legacy read-fallback workspace dir, after the XDG path.
# First config whose detect matches wins, so a project-local pack overrides the workspace.
# `detect` is optional for project-local configs (file presence at that fixed path is
# the detection); it's required for workspace configs (one dir shared by many projects).
# Config schema (camelCase): name, detect (a command; exit 0 = match; optional for project-local),
#   sessionInstructions, pack:{knowledge, frame:{knowledge}, plan:{knowledge,architectureRules},
#   implement:{knowledge,codeStyleRules,validate}}.
# See packs/README.md.
#
# `knowledge` (bare or section-prefixed, e.g. plan.knowledge) is inline prose, emitted
# verbatim (embedded `"` and `\` escaped when the value needs quoting): single-line
# values pass through as-is; multi-line YAML block scalars collapse to one line via
# `sub("\n";" ")` with trailing whitespace trimmed.
# Command keys (architectureRules, codeStyleRules, validate) are shell commands: relative
# values resolve against the config's proximate .sherpa/.claude/.codex/.pi dir (detect runs from it;
# command values are pre-wrapped `cd <base> && ...`). /- and ~-prefixed command values are
# left as-is.
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

if [ -n "${WORKFLOW_PACKS_DIR:-}" ]; then
  packs_dirs=("$WORKFLOW_PACKS_DIR")
else
  packs_dirs=("${XDG_CONFIG_HOME:-$HOME/.config}/sherpa/projects" "$HOME/.claude/sherpa/projects")
fi

proximate_base() {
  local dir
  dir=$(cd "$(dirname "$1")" 2>/dev/null && pwd) || { dirname "$1"; return; }
  local d="$dir"
  while [ "$d" != "/" ]; do
    case "$(basename "$d")" in
      .sherpa|.claude|.codex|.pi) printf '%s' "$d"; return ;;
    esac
    d=$(dirname "$d")
  done
  printf '%s' "$dir"
}

resolve_pack_value() {
  local val="$1" base="$2"
  case "$val" in
    /*) printf '%s' "$val" ;;
    *) printf "cd '%s' && %s" "$base" "$val" ;;
  esac
}

shopt -s nullglob
local_candidates=(
  "$cwd/.sherpa/sherpa.yaml" "$cwd/.sherpa/sherpa.yml"
  "$cwd/.claude/sherpa.yaml" "$cwd/.claude/sherpa.yml"
  "$cwd/.codex/sherpa.yaml"  "$cwd/.codex/sherpa.yml"
  "$cwd/.pi/sherpa.yaml"     "$cwd/.pi/sherpa.yml"
)
candidates=("${local_candidates[@]}")
for _pd in "${packs_dirs[@]}"; do candidates+=("$_pd"/*.yaml "$_pd"/*.yml); done

is_local() {
  local c
  for c in "${local_candidates[@]}"; do [ "$c" = "$1" ] && return 0; done
  return 1
}

for config in "${candidates[@]}"; do
  [ -f "$config" ] || continue
  detect=$(yq '.detect // ""' "$config" 2>/dev/null) || continue
  base=$(proximate_base "$config")

  # Project-local configs live at a fixed path under $cwd — finding the file
  # there already proves the project is active, so `detect` is optional.
  # Workspace configs share one dir across many projects, so a real `detect`
  # is required to pick the right one.
  if [ -n "$detect" ]; then
    ( cd "$base" 2>/dev/null && CWD="$cwd" bash -c "$detect" ) >/dev/null 2>&1 || continue
  elif ! is_local "$config"; then
    continue
  fi

  # Matched. Build the WORKFLOW_PACK line from name + the pack map.
  name=$(yq '.name // ""' "$config" 2>/dev/null)
  line="WORKFLOW_PACK: name=$name"
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    key="${entry%%=*}"
    raw="${entry#*=}"
    case "${key##*.}" in
      knowledge) val="$raw" ;;
      *)         val=$(resolve_pack_value "$raw" "$base") ;;
    esac
    case "$val" in
      *" "*)
        esc="${val//\\/\\\\}"
        esc="${esc//\"/\\\"}"
        line="$line $key=\"$esc\"" ;;
      *) line="$line $key=$val" ;;
    esac
  done < <(yq '.pack // {} | to_entries | .[] | .key as $k | .value | (
      (select(tag == "!!map") | to_entries | .[] | ($k + "." + .key) + "=" + (.value | tostring | sub("\n"; " ") | sub(" +$"; ""))),
      (select(tag != "!!map") | ($k + "=" + (. | tostring | sub("\n"; " ") | sub(" +$"; ""))))
    )' "$config" 2>/dev/null)

  instructions=$(yq '.sessionInstructions // ""' "$config" 2>/dev/null)
  ctx="$PRIMER"$'\n\n'"$line"
  [ -n "$instructions" ] && ctx="$ctx"$'\n'"$instructions"

  emit_result "Project \"$name\" loaded into Sherpa from $config 🏔️" "$ctx"
done

# No pack matched — tell the user no project-specific knowledge was loaded,
# but still force-load the layer-selection primer.
emit_result "🏔️ sherpa: no project pack matched this repo — running generic (no project-specific knowledge loaded)." "$PRIMER"
