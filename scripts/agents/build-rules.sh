#!/usr/bin/env bash
# Usage: build-rules.sh [--check]
# Input:  protocols/shared-rules.md and the files in BLOCK_FILE_MAP (scripts/lib/rules-targets.sh).
#   Test-mode env overrides (fixture tests only): INLINE_SOURCE (source file),
#   INLINE_TEST_FILES (space-separated target files, overrides BLOCK_FILE_MAP).
# Output: replaces the text between `<!-- shared:<block> -->` and `<!-- /shared -->` markers with
#   the matching `## <block>` section of the source. Markers may share a line with other text;
#   fenced code blocks are opaque. --check writes nothing and reports files that are out of date.
# Exit:   0 up to date or written; 1 usage error, parse error, missing target, or --check drift.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source_file="${INLINE_SOURCE:-$repo_root/protocols/shared-rules.md}"
for lib in rules-targets rules-segment rules-state rules-render; do
  source "$repo_root/scripts/lib/$lib.sh"
done

files=("${BLOCK_FILE_MAP[@]}")
if [[ -n "${INLINE_TEST_FILES:-}" ]]; then
  read -r -a files <<<"$INLINE_TEST_FILES"
fi

check_mode=0
case "${1:-}" in
  "") ;;
  --check) check_mode=1 ;;
  *)
    echo "usage: build-rules.sh [--check]" >&2
    exit 1
    ;;
esac

if [[ ${#files[@]} -eq 0 ]]; then
  # Nothing mapped yet; --check has nothing to verify, plain run has nothing to write.
  exit 0
fi

status=0
for file in "${files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "build-rules: target file not found: $file" >&2
    status=1
    continue
  fi

  if ! rendered="$(render_file "$file")"; then
    status=1
    continue
  fi

  if [[ $check_mode -eq 1 ]]; then
    current="$(cat "$file")"
    rendered_nn="${rendered%$'\n'}"
    if [[ "$rendered_nn" != "$current" ]]; then
      echo "build-rules: $file is out of date; run scripts/agents/build-rules.sh to refresh" >&2
      diff <(printf '%s\n' "$current") <(printf '%s\n' "$rendered_nn") >&2 || true
      status=1
    fi
  else
    printf '%s\n' "$rendered" >"$file"
  fi
done

exit $status
