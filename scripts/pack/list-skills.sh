#!/usr/bin/env bash
# Usage: list-skills.sh <configPath|none>
# Input:  a project config path, or "none" to list shared skills only.
# Output: one line per pack skill, sorted by name: name<TAB>SKILL.md path<TAB>description.
# Exit:   0 (also when there are no skills), 2 on a usage error.
set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$dir/../lib/dirs.sh"
source "$dir/../lib/frontmatter.sh"
source "$dir/../lib/pack-skills.sh"

if [ "$#" -ne 1 ]; then
  echo "usage: list-skills.sh <configPath|none>" >&2
  exit 2
fi
pack_skills "$1"
