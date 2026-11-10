#!/usr/bin/env bash
# Usage: load-session.sh   (SessionStart hook; payload JSON on stdin)
# Input:  hook JSON with `.cwd`.
# Output: hook JSON with additionalContext = the layer-selection primer, a bare
#   `WORKFLOW_PACK: name=<name> configPath=<path>` line from the config found by
#   find.sh, and, when the pack has a `session.md`, a framing line plus its content
#   (capped at 4 KB) as binding rules. The shared pack (`shared_dir`) adds `SHARED SESSION
#   RULES` from its session.md before the project block; with no project match but a shared
#   file, it announces `WORKFLOW_PACK: name=shared configPath=none`. Also a `systemMessage`
#   naming the loaded pack, "shared pack only", or "running generic" on no match.
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
source "$dir/../lib/dirs.sh"
PRIMER=$(sed -n '/^---$/,/^---$/!p' "$dir/../../skills/using-sherpa/SKILL.md")

emit_result() {
  jq -n --arg msg "$1" --arg ctx "$2" \
    '{systemMessage:$msg, hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}' 2>/dev/null
  exit 0
}

# Shared pack: any shared file makes the pack announced as configPath=none; session.md
# is inlined as SHARED SESSION RULES. Reading it needs no yq.
sdir=$(shared_dir); shared_line=""; shared_block=""
for f in "$sdir/session.md" "$sdir/context.md" "$sdir"/{frame,shape,implement,analyze}/context.md; do
  [ -f "$f" ] && shared_line=$'\n\n'"WORKFLOW_PACK: name=shared configPath=none"
done
if [ -f "$sdir/session.md" ]; then
  shared_block=$'\n\n'"SHARED SESSION RULES — from $sdir/session.md. Project session rules, when present, override them on conflict."$'\n'"$(print_capped "$sdir/session.md" 4096)"
fi

command -v yq >/dev/null 2>&1 || emit_result \
  "🏔️ sherpa: yq not found — project packs disabled (install yq v4+). Layer primer still loaded." \
  "$PRIMER$shared_line$shared_block"

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

  ctx="$PRIMER"$'\n\n'"$line$shared_block"
  if [ -f "$base/session.md" ]; then
    session=$(print_capped "$base/session.md" 4096)
    ctx="$ctx"$'\n\n'"PROJECT SESSION RULES — from $base/session.md. Follow them before any other tool, skill, or answer."$'\n'"$session"
  fi
  emit_result "Project \"$name\" loaded into Sherpa from $config 🏔️" "$ctx"
fi

[ -z "$shared_line" ] || emit_result "🏔️ sherpa: no project pack matched this repo — shared pack only." "$PRIMER$shared_line$shared_block"
emit_result "🏔️ sherpa: no project pack matched this repo — running generic (no project-specific knowledge loaded)." "$PRIMER"
