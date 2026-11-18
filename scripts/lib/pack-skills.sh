#!/usr/bin/env bash
# Usage: source scripts/lib/pack-skills.sh; pack_skills <configPath|none>
# Input:  a project config path (its dir's skills/ is scanned) or "none" (shared only).
#   Needs scripts/lib/dirs.sh and scripts/lib/frontmatter.sh sourced first.
# Output: one line per skill, sorted by name: name<TAB>SKILL.md path<TAB>description.
#   Scans $(shared_dir)/skills/*/SKILL.md, then <dirname configPath>/skills/*/SKILL.md; a
#   project skill replaces a shared one with the same dir name. The description is the
#   one-line frontmatter `description:` value, quotes stripped, empty when missing (a
#   folded or multi-line value is not supported). Does not need yq.
#   skills_index <configPath|none> prints the session-start block: the header line
#   `PACK SKILLS — run one with /invoke <name> [args] when the request matches:`, then
#   `- <name>: <short description>` (first sentence, max 150 chars) per skill. Whole entries
#   are added only while the block stays <= 2048 bytes; dropped ones become a final
#   `(N more — /invoke with no args lists all)` line. Prints nothing when there are no skills
#   or pack_skills fails.
# Exit:   0. Sourced only; never run directly.

pack_skills() {
  local config="$1" dir file name desc
  local -A paths descs
  local roots=("$(shared_dir)/skills")
  [ "$config" = none ] || roots+=("$(dirname "$config")/skills")
  for dir in "${roots[@]}"; do
    for file in "$dir"/*/SKILL.md; do
      [ -f "$file" ] || continue
      name=$(basename "$(dirname "$file")")
      desc=$(extract_frontmatter <(tr -d "\r" <"$file") | sed -n 's/^description:[[:space:]]*//p' | head -n 1)
      desc=${desc%$'\r'}; desc=${desc//$'\t'/ }
      desc=${desc%\"}; desc=${desc#\"}; desc=${desc%\'}; desc=${desc#\'}
      case "$desc" in '>'|'|'|'>-'|'|-'|'>+'|'|+') desc= ;; esac
      paths[$name]=$file
      descs[$name]=$desc
    done
  done
  for name in "${!paths[@]}"; do
    printf '%s\t%s\t%s\n' "$name" "${paths[$name]}" "${descs[$name]}"
  done | LC_ALL=C sort -t $'\t' -k1,1
}

_bytes() { local LC_ALL=C s=$1; echo ${#s}; }

skills_index() {
  local rows name desc out total=0 i=0 more line
  local -a names descs
  rows=$(pack_skills "$1" 2>/dev/null) || return 0
  [ -n "$rows" ] || return 0
  while IFS=$'\t' read -r name _ desc; do
    desc=${desc%%. [A-Z]*}; desc=${desc%.}; desc=${desc:0:150}
    names+=("$name"); descs+=("$desc")
  done <<<"$rows"
  total=${#names[@]}
  out="PACK SKILLS — run one with /invoke <name> [args] when the request matches:"
  for ((i = 0; i < total; i++)); do
    line="- ${names[i]}${descs[i]:+: ${descs[i]}}"
    more=$((total - i - 1))
    if [ "$more" -gt 0 ]; then
      [ $(($(_bytes "$out") + $(_bytes "$line") + 1 + 52)) -le 2048 ] || break
    else
      [ $(($(_bytes "$out") + $(_bytes "$line") + 1)) -le 2048 ] || break
    fi
    out+=$'\n'"$line"
  done
  [ "$i" -ge "$total" ] || out+=$'\n'"($((total - i)) more — /invoke with no args lists all)"
  printf '%s\n' "$out"
}
