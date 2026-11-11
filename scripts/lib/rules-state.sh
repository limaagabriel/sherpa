#!/usr/bin/env bash
# Usage: source scripts/lib/rules-state.sh
# Purpose: part 2 of the awk program render_file runs (see rules-render.sh): the BEGIN block
#   (loads the `## <block>` sections of the source file given as awk variable `src`, sets the
#   parser state) and update_marker_state. Defines AWK_STATE (program text, data only).
#   Sourced only; never run directly.

AWK_STATE='    BEGIN {
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
      in_marker = 0
      seen_fm_open = 0
    }

    # Updates in_marker from the open/close shared-marker tokens found in
    # line, in the order they appear. Previously-inlined block content can
    # contain a bare fence line (the block source should avoid this, but a
    # stale on-disk file may still have one); while inside an open marker
    # span, that fence line must not toggle in_fence below, or the segment
    # gets flushed before its close marker is ever seen, producing a
    # misleading "no matching close marker" error.
    function update_marker_state(line,    remaining, pos_open, pos_close) {
      remaining = line
      while (length(remaining) > 0) {
        pos_open = index(remaining, "<!-- shared:")
        pos_close = index(remaining, "<!-- /shared -->")
        if (pos_open == 0 && pos_close == 0) break
        if (pos_open > 0 && (pos_close == 0 || pos_open < pos_close)) {
          match(remaining, /<!-- shared:[A-Za-z0-9_-]+ -->/)
          in_marker = 1
          remaining = substr(remaining, RSTART + RLENGTH)
        } else {
          in_marker = 0
          remaining = substr(remaining, pos_close + length("<!-- /shared -->"))
        }
      }
    }
'
