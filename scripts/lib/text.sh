#!/usr/bin/env bash
# Usage: source scripts/lib/text.sh; print_capped <file> <bytes>
# Input:  a file and a byte cap.
# Output: print_capped prints the file; when it is larger than the cap, prints the
#   first <bytes> bytes, a newline, then "(<name> truncated at <N> KB — keep it short)".
# Exit:   0. Sourced only; never run directly.

print_capped() {
  local file=$1 cap=$2 size
  size=$(wc -c <"$file" 2>/dev/null) || size=0
  if [ "$size" -gt "$cap" ]; then
    head -c "$cap" "$file"
    printf '\n(%s truncated at %s KB — keep it short)\n' "$(basename "$file")" "$((cap / 1024))"
  else
    cat "$file" 2>/dev/null
  fi
}
