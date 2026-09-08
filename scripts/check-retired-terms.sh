#!/usr/bin/env bash
# Fails if any retired term (scripts/retired-terms.txt) shows up in the
# tracked skill/agent/readme surface. Prints file:line:match for every hit.
#
# Env overrides (for fixture tests only):
#   REPO_ROOT   - git repo to scan (default: this repo)
#   TERMS_FILE  - retired-terms list (default: $REPO_ROOT/scripts/retired-terms.txt)
#   SCAN_PATHS  - space-separated git ls-files pathspecs (default: the real surface)
set -euo pipefail

repo_root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
terms_file="${TERMS_FILE:-$repo_root/scripts/retired-terms.txt}"
read -r -a scan_paths <<<"${SCAN_PATHS:-skills agents README.md AGENTS.md .codex/agents .pi/agents}"

if [[ ! -f "$terms_file" ]]; then
  echo "check-retired-terms: terms file not found: $terms_file" >&2
  exit 1
fi

mapfile -t files < <(cd "$repo_root" && git ls-files -- "${scan_paths[@]}" 2>/dev/null)

if [[ ${#files[@]} -eq 0 ]]; then
  exit 0
fi

found=0
while IFS= read -r term || [[ -n "$term" ]]; do
  [[ -z "$term" ]] && continue
  hits="$(cd "$repo_root" && grep -n -E -w -- "$term" "${files[@]}" 2>/dev/null || true)"
  if [[ -n "$hits" ]]; then
    printf '%s\n' "$hits"
    found=1
  fi
done < "$terms_file"

if [[ "$found" -eq 1 ]]; then
  exit 1
fi

exit 0
