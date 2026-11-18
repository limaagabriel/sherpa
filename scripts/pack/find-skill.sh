#!/usr/bin/env bash
# Usage: find-skill.sh <configPath|none> <name>
# Input:  a project config path (or "none") and a skill dir name.
# Output: the path of that skill's SKILL.md; a project skill wins over a shared one.
# Exit:   0 on a hit, 1 when the skill does not exist, 2 on a usage error.
set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$dir/../lib/dirs.sh"
source "$dir/../lib/frontmatter.sh"
source "$dir/../lib/pack-skills.sh"

if [ "$#" -ne 2 ]; then
  echo "usage: find-skill.sh <configPath|none> <name>" >&2
  exit 2
fi
line=$(pack_skills "$1" | awk -F '\t' -v n="$2" '$1 == n { print $2; exit }')
[ -n "$line" ] || exit 1
printf '%s\n' "$line"
