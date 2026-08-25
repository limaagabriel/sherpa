#!/usr/bin/env bash
# Generic project-pack resolver for sherpa's SessionStart hook.
#
# Reads the hook payload (JSON) on stdin, scans for per-project YAML configs, and
# runs each config's `detect` command. On the first match it emits a SessionStart
# additionalContext ordered as: the layer-selection primer, then a bare `WORKFLOW_PACK:`
# announcement carrying only `name=<name> configPath=<path>` (nothing from the config's
# `pack` map is eagerly inlined — every value there, `knowledge` and command keys
# alike, is resolved lazily by the consuming layer skill via scripts/resolve-pack-value.sh
# and scripts/resolve-pack-basedir.sh, given `configPath`), and a user-facing
# `systemMessage` naming the loaded pack. On no match it emits a `systemMessage` saying
# the engine runs generic (so the user knows no project knowledge loaded).
#
# `context` (the config's top-level prose, formerly `sessionInstructions`) is never
# read or emitted by this script — using-sherpa's SKILL.md HARD GATE fully owns its
# delivery via lazy resolution (scripts/resolve-pack-value.sh <configPath> context),
# triggered off the `WORKFLOW_PACK:` line's configPath. This keeps `context` off the
# hook-truncation-sensitive path entirely, at the cost of a required lazy fetch by
# the consuming skill.
#
# Config candidates, highest precedence first:
#   <cwd>/.sherpa/sherpa.yaml|.yml       project-local, engine-neutral, shareable in-repo (single file)
#   <cwd>/.claude/sherpa.yaml|.yml       project-local, engine-specific, shareable in-repo (single file)
#   <cwd>/.codex/sherpa.yaml|.yml        project-local, engine-specific, shareable in-repo (single file)
#   <cwd>/.pi/sherpa.yaml|.yml           project-local, engine-specific, shareable in-repo (single file)
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
# the detection); it's required for workspace configs (one dir shared by many projects).
# Config schema (camelCase): name, detect (a command; exit 0 = match; optional for project-local),
#   context, pack:{knowledge, frame:{knowledge}, shape:{knowledge},
#   decompose:{knowledge,architecture}, implement:{knowledge,codeStyle,validate}}.
# See packs/README.md.
#
# Nothing under `pack` (neither `knowledge`, bare or section-prefixed e.g.
# decompose.knowledge, nor the command keys architecture/codeStyle/validate)
# is read or inlined by this script anymore — the `WORKFLOW_PACK:` line carries only
# `name=` and `configPath=`. Nor is top-level `context` (formerly `sessionInstructions`)
# read or inlined — using-sherpa's SKILL.md HARD GATE fetches it lazily off the
# `WORKFLOW_PACK:` line's configPath. A consuming layer skill fetches `knowledge` prose or
# a command key's resolved value the same way, at the point it's actually needed, by
# calling scripts/resolve-pack-value.sh <configPath> <dotted.key> [--raw] (which resolves
# relative values against scripts/resolve-pack-basedir.sh <configPath>'s output:
# project-local configs base on the proximate .sherpa/.claude/.codex/.pi dir; workspace
# configs base on the pack's own directory).
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

shopt -s nullglob
local_candidates=(
  "$cwd/.sherpa/sherpa.yaml" "$cwd/.sherpa/sherpa.yml"
  "$cwd/.claude/sherpa.yaml" "$cwd/.claude/sherpa.yml"
  "$cwd/.codex/sherpa.yaml"  "$cwd/.codex/sherpa.yml"
  "$cwd/.pi/sherpa.yaml"     "$cwd/.pi/sherpa.yml"
)
candidates=("${local_candidates[@]}")
for _pd in "${packs_dirs[@]}"; do candidates+=("$_pd"/*/project.yaml "$_pd"/*/project.yml); done

is_local() {
  local c
  for c in "${local_candidates[@]}"; do [ "$c" = "$1" ] && return 0; done
  return 1
}

for config in "${candidates[@]}"; do
  [ -f "$config" ] || continue
  detect=$(yq '.detect // ""' "$config" 2>/dev/null) || continue
  if is_local "$config"; then
    base=$(proximate_base "$config")
  else
    base=$(cd "$(dirname "$config")" 2>/dev/null && pwd) || base=$(dirname "$config")
  fi

  # Project-local configs live at a fixed path under $cwd — finding the file
  # there already proves the project is active, so `detect` is optional.
  # Workspace configs share one dir across many projects, so a real `detect`
  # is required to pick the right one.
  if [ -n "$detect" ]; then
    ( cd "$base" 2>/dev/null && CWD="$cwd" bash -c "$detect" ) >/dev/null 2>&1 || continue
  elif ! is_local "$config"; then
    continue
  fi

  # Matched. Build the WORKFLOW_PACK line from name + configPath only — nothing
  # from the pack map (knowledge or command keys) is eagerly inlined anymore;
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
