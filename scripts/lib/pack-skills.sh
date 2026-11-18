#!/usr/bin/env bash
# Usage: source scripts/lib/pack-skills.sh; pack_skills <configPath|none>
# Input:  a project config path (its dir's skills/ is scanned) or "none" (shared only).
#   Needs scripts/lib/dirs.sh and scripts/lib/frontmatter.sh sourced first.
# Output: one line per skill, sorted by name: name<TAB>SKILL.md path<TAB>description.
#   Scans $(shared_dir)/skills/*/SKILL.md, then <dirname configPath>/skills/*/SKILL.md; a
#   project skill replaces a shared one with the same dir name. The description is the
#   one-line frontmatter `description:` value, quotes stripped, empty when missing (a
#   folded or multi-line value is not supported). Does not need yq.
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
