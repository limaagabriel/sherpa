#!/usr/bin/env bash
# Usage: source scripts/lib/rules-segment.sh
# Purpose: part 1 of the awk program render_file runs (see rules-render.sh): the helpers
#   count_nl, fail and process_segment, which inline <!-- shared:<block> --> markers in a text
#   segment. Defines AWK_SEGMENT (program text, data only). Sourced only; never run directly.

AWK_SEGMENT='    function count_nl(s,    n) { n = gsub(/\n/, "\n", s); return n }

    function fail(msg) {
      print "build-rules: " msg > "/dev/stderr"
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

        result = result prefix openm blocks[blockname] "\n<!-- /shared -->"
        remaining = substr(after_open, closepos + length("<!-- /shared -->"))
      }

      if (index(remaining, "<!-- /shared -->") > 0) {
        fail(fname ": close marker with no matching open marker")
      }

      result = result remaining
      return result
    }
'
