#!/usr/bin/env bash
# Usage: load-session.sh   (SessionStart hook; payload JSON on stdin)
# Input:  hook JSON with `.cwd`.
# Output: hook JSON with additionalContext = the layer-selection primer, a bare
#   `WORKFLOW_PACK: name=<name> configPath=<path>` line from the config found by
#   find.sh, and, when the pack has a `session.md`, a framing line plus its content
#   (capped at 4 KB) as binding rules. Also a `systemMessage` naming the loaded pack,
#   or "running generic" on no match.
# Exit:   always 0 — this hook never fails, so it does not use `set -e`. Missing jq
#   exits silently; missing yq still emits the primer plus a warning. Pi's
#   .pi/extensions/sherpa.ts forwards this. Other pack values are fetched lazily by
#   skills via load-layer.sh — never read or inlined here.

input=$(cat 2>/dev/null) || exit 0
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
[ -n "$cwd" ] || exit 0

command -v jq >/dev/null 2>&1 || exit 0

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$dir/../lib/text.sh"
PRIMER=$(sed -n '/^---$/,/^---$/!p' "$dir/../../skills/using-sherpa/SKILL.md")

emit_result() {
  jq -n --arg msg "$1" --arg ctx "$2" \
    '{systemMessage:$msg, hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}' 2>/dev/null
  exit 0
}

command -v yq >/dev/null 2>&1 || emit_result \
  "🏔️ sherpa: yq not found — project packs disabled (install yq v4+). Layer primer still loaded." \
  "$PRIMER"

if config=$(bash "$dir/find.sh" "$cwd" 2>/dev/null); then
  base=$(cd "$(dirname "$config")" 2>/dev/null && pwd) || base=$(dirname "$config")
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
    session=$(print_capped "$base/session.md" 4096)
    ctx="$ctx"$'\n\n'"PROJECT SESSION RULES — from $base/session.md. Follow them before any other tool, skill, or answer."$'\n'"$session"
  fi
  emit_result "Project \"$name\" loaded into Sherpa from $config 🏔️" "$ctx"
fi

emit_result "🏔️ sherpa: no project pack matched this repo — running generic (no project-specific knowledge loaded)." "$PRIMER"
