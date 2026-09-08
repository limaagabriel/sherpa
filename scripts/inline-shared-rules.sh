#!/usr/bin/env bash
# Inlines shared-rule blocks from protocols/shared-rules.md into the target
# files listed in BLOCK_FILE_MAP, replacing the text between
# `<!-- shared:<block> -->` and `<!-- /shared -->` markers with the matching
# `## <block>` section from the source file. Markers may share a line with
# other text; fenced code blocks (``` ... ```) are opaque to the parser.
#
# Usage:
#   scripts/inline-shared-rules.sh            # inline in place (writes files)
#   scripts/inline-shared-rules.sh --check     # verify inlined content is up to date; no writes
#
# Test-mode env overrides (fixture tests only):
#   INLINE_SOURCE      - path to the shared-rules source file
#   INLINE_TEST_FILES  - space-separated list of target files, overrides BLOCK_FILE_MAP
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_file="${INLINE_SOURCE:-$repo_root/protocols/shared-rules.md}"

# Block -> file map: files to scan for <!-- shared:<block> --> markers.
# Empty for now; later plan steps populate this as files adopt shared rules.
BLOCK_FILE_MAP=(
)

files=("${BLOCK_FILE_MAP[@]}")
if [[ -n "${INLINE_TEST_FILES:-}" ]]; then
  read -r -a files <<<"$INLINE_TEST_FILES"
fi

check_mode=0
case "${1:-}" in
  "") ;;
  --check) check_mode=1 ;;
  *)
    echo "usage: inline-shared-rules.sh [--check]" >&2
    exit 1
    ;;
esac

# Renders a target file with markers inlined, printed on stdout. Exits
# nonzero with a stderr message and no output on: unclosed open marker,
# close marker with no matching open, unknown block, or a marker before the
# file's closing frontmatter `---`. Fenced code blocks are copied verbatim
# and never scanned for markers.
render_file() {
  local file="$1"
  awk -v src="$source_file" -v fname="$file" '
    function count_nl(s,    n) { n = gsub(/\n/, "\n", s); return n }

    function fail(msg) {
      print "inline-shared-rules: " msg > "/dev/stderr"
      err = 1
      exit 1
    }

    function process_segment(text, start_line,    remaining, offset, prefix_full,
                              line_no, prefix, openm, blockname, after_open,
                              closepos, old_content, result) {
      remaining = text
      result = ""
      while (match(remaining, /<!-- shared:[A-Za-z0-9_-]+ -->/) > 0) {
        offset = length(text) - length(remaining)
        prefix_full = substr(text, 1, offset + RSTART - 1)
        line_no = start_line + count_nl(prefix_full)

        if (fm_close >= 0 && line_no <= fm_close) {
          fail(fname ":" line_no ": marker appears before the closing frontmatter '"'"'---'"'"'")
        }

        prefix = substr(remaining, 1, RSTART - 1)
        openm = substr(remaining, RSTART, RLENGTH)
        blockname = openm
        sub(/^<!-- shared:/, "", blockname)
        sub(/ -->$/, "", blockname)

        after_open = substr(remaining, RSTART + RLENGTH)
        closepos = index(after_open, "<!-- /shared -->")
        if (closepos == 0) {
          fail(fname ":" line_no ": open marker for block '"'"'" blockname "'"'"' has no matching close marker")
        }

        old_content = substr(after_open, 1, closepos - 1)
        if (match(old_content, /<!-- shared:[A-Za-z0-9_-]+ -->/) > 0) {
          fail(fname ":" line_no ": open marker for block '"'"'" blockname "'"'"' has no matching close marker before the next open marker")
        }

        if (!(blockname in blocks)) {
          fail(fname ": block '"'"'" blockname "'"'"' not found in " src)
        }

        result = result prefix openm blocks[blockname] "<!-- /shared -->"
        remaining = substr(after_open, closepos + length("<!-- /shared -->"))
      }

      if (index(remaining, "<!-- /shared -->") > 0) {
        fail(fname ": close marker with no matching open marker")
      }

      result = result remaining
      return result
    }

    BEGIN {
      fm_close = -1
      err = 0

      cur_block = ""
      have_cur = 0
      src_rc = 1
      while ((src_rc = (getline srcline < src)) > 0) {
        if (srcline ~ /^## /) {
          if (have_cur) { blocks[cur_block] = cur_content }
          cur_block = substr(srcline, 4)
          cur_content = ""
          have_cur = 1
          first_of_block = 1
        } else if (have_cur) {
          if (first_of_block) { cur_content = srcline; first_of_block = 0 }
          else { cur_content = cur_content "\n" srcline }
        }
      }
      if (have_cur) { blocks[cur_block] = cur_content }
      close(src)
      for (b in blocks) {
        v = blocks[b]
        gsub(/\n+$/, "", v)
        blocks[b] = v
      }

      out = ""
      scan_buf = ""
      have_scan = 0
      scan_start = 0
      in_fence = 0
      seen_fm_open = 0
    }

    {
      if (err) next

      gsub(/\r$/, "")

      if ($0 ~ /^```/) {
        if (have_scan) {
          out = out process_segment(scan_buf, scan_start) "\n"
          have_scan = 0
          scan_buf = ""
        }
        out = out $0 "\n"
        in_fence = !in_fence
        next
      }

      if (in_fence) {
        out = out $0 "\n"
        next
      }

      if (FNR == 1 && $0 == "---") {
        seen_fm_open = 1
      } else if (seen_fm_open && fm_close == -1 && $0 == "---") {
        fm_close = FNR
      }

      if (!have_scan) { scan_start = FNR; scan_buf = $0; have_scan = 1 }
      else { scan_buf = scan_buf "\n" $0 }
    }

    END {
      if (err) exit 1
      if (have_scan) {
        out = out process_segment(scan_buf, scan_start) "\n"
      }
      if (err) exit 1
      printf "%s", out
    }
  ' "$file"
}

if [[ ${#files[@]} -eq 0 ]]; then
  # Nothing mapped yet; --check has nothing to verify, plain run has nothing to write.
  exit 0
fi

status=0
for file in "${files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "inline-shared-rules: target file not found: $file" >&2
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
      echo "inline-shared-rules: $file is out of date; run scripts/inline-shared-rules.sh to refresh" >&2
      diff <(printf '%s\n' "$current") <(printf '%s\n' "$rendered_nn") >&2 || true
      status=1
    fi
  else
    printf '%s\n' "$rendered" >"$file"
  fi
done

exit $status
