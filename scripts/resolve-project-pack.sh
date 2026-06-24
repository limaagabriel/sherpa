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
#   <cwd>/.claude/sherpa.yaml|.yml      project-local, shareable in-repo (single file)
#   <cwd>/.codex/sherpa.yaml|.yml       project-local, shareable in-repo (single file)
#   ${WORKFLOW_PACKS_DIR:-$HOME/.claude/sherpa/projects}/*.yaml|*.yml  workspace (many)
# First config whose detect matches wins, so a project-local pack overrides the workspace.
# Config schema (camelCase): name, detect (a command; exit 0 = match),
#   sessionInstructions, pack:{initialize,reviewers,codeStyleAudit,codeStyleRules,architectureRules,projectStatePath}.
# See packs/README.md.
#
# Never errors out: a failing SessionStart hook must not block the session.

input=$(cat 2>/dev/null) || exit 0
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
[ -n "$cwd" ] || exit 0

command -v yq >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

packs_dir="${WORKFLOW_PACKS_DIR:-$HOME/.claude/sherpa/projects}"

shopt -s nullglob
candidates=(
  "$cwd/.claude/sherpa.yaml" "$cwd/.claude/sherpa.yml"
  "$cwd/.codex/sherpa.yaml"  "$cwd/.codex/sherpa.yml"
  "$packs_dir"/*.yaml "$packs_dir"/*.yml
)

for config in "${candidates[@]}"; do
  [ -f "$config" ] || continue
  detect=$(yq '.detect // ""' "$config" 2>/dev/null) || continue
  [ -n "$detect" ] || continue

  CWD="$cwd" bash -c "$detect" >/dev/null 2>&1 || continue

  # Matched. Build the WORKFLOW_PACK line from name + the pack map.
  name=$(yq '.name // ""' "$config" 2>/dev/null)
  line="WORKFLOW_PACK: name=$name"
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    key="${entry%%=*}"
    val="${entry#*=}"
    case "$val" in
      *" "*) line="$line $key=\"$val\"" ;;
      *)     line="$line $key=$val" ;;
    esac
  done < <(yq '.pack // {} | to_entries | .[] | .key + "=" + (.value | tostring | sub("\n"; " "))' "$config" 2>/dev/null)

  instructions=$(yq '.sessionInstructions // ""' "$config" 2>/dev/null)
  ctx="$line"
  [ -n "$instructions" ] && ctx="$line"$'\n'"$instructions"

  jq -n --arg ctx "$ctx" --arg msg "🏔️ sherpa: loaded project pack '$name' ($config)" \
    '{systemMessage:$msg, hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}' 2>/dev/null
  exit 0
done

# No pack matched — tell the user no project-specific knowledge was loaded.
jq -n --arg msg "🏔️ sherpa: no project pack matched this repo — running generic (no project-specific knowledge loaded)." \
  '{systemMessage:$msg}' 2>/dev/null
exit 0
