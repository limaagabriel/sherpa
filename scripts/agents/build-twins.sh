#!/usr/bin/env bash
# Usage: build-twins.sh
# Input:  agents/*.md frontmatter (needs yq).
# Output: rewrites .codex/agents/<name>.toml and .pi/agents/<name>.md for every agent.
#   Test-mode env overrides (fixture tests only): TWINS_AGENTS_DIR, TWINS_CODEX_DIR, TWINS_PI_DIR.
# Exit:   0 on success; 1 when a required frontmatter field is missing or a guard rejects a value.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
agents_dir="${TWINS_AGENTS_DIR:-$repo_root/agents}"
codex_dir="${TWINS_CODEX_DIR:-$repo_root/.codex/agents}"
pi_dir="${TWINS_PI_DIR:-$repo_root/.pi/agents}"
source "$repo_root/scripts/lib/frontmatter.sh"
source "$repo_root/scripts/lib/twins.sh"

for file in "$agents_dir"/*.md; do
  generate_twin "$file"
done
