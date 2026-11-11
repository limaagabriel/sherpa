#!/usr/bin/env bash
# Usage: source scripts/lib/rules-segment.sh scripts/lib/rules-state.sh scripts/lib/rules-render.sh
# Purpose: render_file <file> prints a target file with markers inlined, on stdout. It exits
#   nonzero with a stderr message and no output on: unclosed open marker, close marker with no
#   matching open, unknown block, or a marker before the file's closing frontmatter `---`.
#   Fenced code blocks are copied verbatim and never scanned for markers. Reads the global
#   source_file (set by the entry script) and AWK_SEGMENT / AWK_STATE from the sibling libs.
#   Defines AWK_MAIN (the per-line rule and END block) and render_file. Sourced only.

AWK_MAIN='    {
      if (err) next

      gsub(/\r$/, "")
      update_marker_state($0)

      if (!in_marker && $0 ~ /^```/) {
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
'

render_file() {
  local file="$1"
  awk -v src="$source_file" -v fname="$file" "$AWK_SEGMENT$AWK_STATE$AWK_MAIN" "$file"
}
