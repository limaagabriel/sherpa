#!/usr/bin/env bash
# Usage: test-ticket.sh
# Input:  none; builds fixture tickets in a temp SHERPA_CONFIG_DIR. Tests the ticket writing
#   helpers and section_of in scripts/lib/inventory.sh. Needs yq.
# Output: "PASS: all ticket cases" or FAIL lines plus "FAILED".
# Exit:   0 when every case passes, 1 otherwise.
set -u
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
source "$here/../lib/assert.sh"
export SHERPA_CONFIG_DIR="$tmp"
source "$here/../lib/inventory.sh"

same() { cmp -s "$2" "$3" || { echo "FAIL [$1]: files differ: $2 vs $3"; fail=1; }; }  # <label> <a> <b>
snap() { cp -p "$1" "$1.orig"; }  # keep a copy to compare against

# --- section_of: every stage and marker name, and an unknown one
assert_eq "section frame" "$(section_of frame)" "frame|## Frame"
assert_eq "section shape" "$(section_of shape)" "plan|## Plan"
assert_eq "section plan" "$(section_of plan)" "plan|## Plan"
assert_eq "section implement" "$(section_of implement)" "implementation|## Implementation"
assert_eq "section implementation" "$(section_of implementation)" "implementation|## Implementation"
assert_eq "section analyze" "$(section_of analyze)" "analysis|## Analysis"
assert_eq "section analysis" "$(section_of analysis)" "analysis|## Analysis"
assert_eq "section last-run" "$(section_of last-run)" "last-run|## Last run"
section_of nope >/dev/null; assert_exit "section unknown" $? 1

# --- expand_path: ~ and $NAME, never run anything, no second pass
export HOME=/h EP_A=aa EP_E="" EP_X='$EP_A'
assert_eq "expand ~" "$(expand_path '~')" "/h"
assert_eq "expand ~/x" "$(expand_path '~/x/$EP_A')" "/h/x/aa"
assert_eq "expand ~user stays" "$(expand_path '~bob/x')" "~bob/x"
assert_eq "expand mid ~ stays" "$(expand_path '/a/~/b')" "/a/~/b"
assert_eq "expand braces" "$(expand_path '/p/${EP_A}b/$EP_A.c')" "/p/aab/aa.c"
assert_eq "expand empty-but-set" "$(expand_path '/p/$EP_E/q')" "/p//q"
assert_eq "expand no re-scan" "$(expand_path '$EP_X')" '$EP_A'
assert_eq "expand lone dollar" "$(expand_path 'a$')" 'a$'
assert_eq "expand dollar space" "$(expand_path '$ x')" '$ x'
assert_eq "expand positional" "$(expand_path '/p/$1/$9')" '/p/$1/$9'
assert_eq "expand unclosed brace" "$(expand_path '/p/${EP_A')" '/p/${EP_A'
assert_eq "expand cmd subst text" "$(expand_path '/p/$(touch '"$tmp"'/x)')" "/p/\$(touch $tmp/x)"
assert_eq "expand backtick text" "$(expand_path '/p/`touch '"$tmp"'/y`')" "/p/\`touch $tmp/y\`"
[ ! -e "$tmp/x" ] && [ ! -e "$tmp/y" ] || { echo "FAIL [expand ran code]"; fail=1; }
out=$(expand_path '/p/$EP_A/$EP_NOPE/$EP_NOPE2'); assert_exit "expand unset exit" $? 1
assert_eq "expand unset prints name" "$out" "EP_NOPE"
out=$(expand_path '${EP_NOPE}'); assert_eq "expand unset braces" "$out" "EP_NOPE"

# --- ticket_set / ticket_del
# body holds a "---" line, "## " lines and no front matter
printf '# Title\nwords\n---\nmore\n## Notes\n---\nend\n' >"$tmp/nofm.md"; snap "$tmp/nofm.md"
ticket_set "$tmp/nofm.md" parked frame; assert_exit "set no fm" $? 0
assert_eq "set adds block" "$(head -n 3 "$tmp/nofm.md")" $'---\nparked: frame\n---'
tail -n +4 "$tmp/nofm.md" >"$tmp/body.txt"; same "set leaves body" "$tmp/body.txt" "$tmp/nofm.md.orig"
assert_eq "get after set" "$(ticket_get "$tmp/nofm.md" parked)" "frame"
ticket_del "$tmp/nofm.md" parked; assert_exit "del last" $? 0
same "set then del" "$tmp/nofm.md" "$tmp/nofm.md.orig"

printf '# Title\nno final newline' >"$tmp/nonl.md"; snap "$tmp/nonl.md"
ticket_set "$tmp/nonl.md" parked shape; ticket_del "$tmp/nonl.md" parked
same "set then del, no final newline" "$tmp/nonl.md" "$tmp/nonl.md.orig"

# a field the user owns stays; only ours changes
printf -- '---\nowner: gabriel\n---\n# T\n---\nbody\n## X\n' >"$tmp/own.md"; snap "$tmp/own.md"
ticket_set "$tmp/own.md" parked frame; ticket_set "$tmp/own.md" actionNeeded answers
ticket_set "$tmp/own.md" parked shape
assert_eq "overwrite" "$(ticket_get "$tmp/own.md" parked)" "shape"
assert_eq "other field kept" "$(ticket_get "$tmp/own.md" owner)" "gabriel"
assert_eq "second field" "$(ticket_get "$tmp/own.md" actionNeeded)" "answers"
ticket_del "$tmp/own.md" parked; ticket_del "$tmp/own.md" actionNeeded
same "del keeps user fm and body" "$tmp/own.md" "$tmp/own.md.orig"
ticket_del "$tmp/own.md" missing; assert_exit "del absent field" $? 0
same "del absent field no change" "$tmp/own.md" "$tmp/own.md.orig"
ticket_del "$tmp/nofm.md" parked; assert_exit "del no fm" $? 0
same "del no fm no change" "$tmp/nofm.md" "$tmp/nofm.md.orig"

# a value is stored as a string, whatever it holds
ticket_set "$tmp/nofm.md" actionNeeded 'a: "b" # c [d]'
assert_eq "odd value" "$(ticket_get "$tmp/nofm.md" actionNeeded)" 'a: "b" # c [d]'
ticket_set "$tmp/nofm.md" parked 123
assert_eq "numeric stays string" "$(yq --front-matter=extract '.parked | type' "$tmp/nofm.md")" '!!str'

# bad input leaves the file alone and does not exit the caller
printf -- '---\nparked: [oops\n---\n# T\n' >"$tmp/bad.md"; snap "$tmp/bad.md"
ticket_set "$tmp/bad.md" parked frame; assert_exit "set bad yaml" $? 1
ticket_del "$tmp/bad.md" parked; assert_exit "del bad yaml" $? 1
same "bad yaml untouched" "$tmp/bad.md" "$tmp/bad.md.orig"
ticket_set "$tmp/own.md" 'a b' x; assert_exit "set bad field" $? 1
ticket_set "$tmp/none.md" parked x; assert_exit "set missing file" $? 1
chmod 640 "$tmp/own.md"; ticket_set "$tmp/own.md" parked frame
assert_eq "mode kept" "$(stat -c %a "$tmp/own.md")" 640
assert_eq "no temp left" "$(ls -A "$tmp" | grep -c '^\.sherpa\.')" 0

# --- ticket_section_put / ticket_section_del
printf 'Sub heading\n## Not a real section\n---\nx $y \\n & / [a-z]* "q"\n' >"$tmp/c1.txt"
printf 'second\n' >"$tmp/c2.txt"
cat >"$tmp/s.md" <<'EOT'
---
owner: gabriel
---
# Fix it
What I want.

## Frame
<!-- sherpa:frame -->
old
<!-- /sherpa:frame -->

## Answers
Q1: mine
EOT
snap "$tmp/s.md"
ticket_section_put "$tmp/s.md" plan "$tmp/c1.txt"; assert_exit "put new" $? 0
ln_open=$(grep -nxF '<!-- sherpa:plan -->' "$tmp/s.md" | cut -d: -f1)
ln_ans=$(grep -nx '## Answers' "$tmp/s.md" | cut -d: -f1)
assert_eq "heading above marker" "$(sed -n "$((ln_open - 1))p" "$tmp/s.md")" "## Plan"
[ "$ln_open" -lt "$ln_ans" ] || { echo "FAIL [before answers]: $ln_open !< $ln_ans"; fail=1; }
assert_eq "blank before Answers" "$(sed -n "$((ln_ans - 1))p" "$tmp/s.md")" ""
assert_contains "content in" "$(cat "$tmp/s.md")" 'x $y \n & / [a-z]* "q"'
assert_eq "Answers kept" "$(tail -n 2 "$tmp/s.md")" $'## Answers\nQ1: mine'
assert_eq "frame kept" "$(sed -n 6,10p "$tmp/s.md")" "$(sed -n 6,10p "$tmp/s.md.orig")"
cp "$tmp/s.md" "$tmp/s.once"
ticket_section_put "$tmp/s.md" plan "$tmp/c1.txt"; assert_exit "put twice" $? 0
same "put is idempotent" "$tmp/s.md" "$tmp/s.once"
assert_eq "one plan section" "$(grep -c 'sherpa:plan -->' "$tmp/s.md")" 2
ticket_section_put "$tmp/s.md" shape "$tmp/c2.txt"  # a stage name reaches the same section
assert_eq "stage name replaces" "$(grep -c '^## Plan$' "$tmp/s.md")" 1
assert_not_contains "old content gone" "$(cat "$tmp/s.md")" "Sub heading"
assert_contains "new content in" "$(cat "$tmp/s.md")" $'<!-- sherpa:plan -->\nsecond\n<!-- /sherpa:plan -->'
ticket_section_del "$tmp/s.md" plan; assert_exit "del section" $? 0
same "put then del" "$tmp/s.md" "$tmp/s.md.orig"
ticket_section_del "$tmp/s.md" plan; assert_exit "del absent section" $? 0
same "del absent no change" "$tmp/s.md" "$tmp/s.md.orig"

# a section the loop wrote earlier can be replaced; text around it stays
ticket_section_put "$tmp/s.md" frame "$tmp/c2.txt"
assert_eq "frame replaced" "$(sed -n 7,10p "$tmp/s.md")" $'## Frame\n<!-- sherpa:frame -->\nsecond\n<!-- /sherpa:frame -->'
assert_eq "answers after replace" "$(tail -n 3 "$tmp/s.md")" $'\n## Answers\nQ1: mine'
assert_eq "text before frame" "$(head -n 6 "$tmp/s.md")" "$(head -n 6 "$tmp/s.md.orig")"

# no "## Answers": append at the end, all five names, then remove them all
printf '# Plain\nwords\n\n## Notes\nmine\n' >"$tmp/p.md"; snap "$tmp/p.md"
for n in frame plan implementation analysis last-run; do
  ticket_section_put "$tmp/p.md" "$n" "$tmp/c1.txt"; assert_exit "put $n" $? 0
done
assert_eq "five sections" "$(grep -c '^<!-- sherpa:[a-z-]* -->$' "$tmp/p.md")" 5
assert_eq "blank before appended" "$(sed -n 6,7p "$tmp/p.md")" $'\n## Frame'
assert_eq "appended at end" "$(tail -n 1 "$tmp/p.md")" "<!-- /sherpa:last-run -->"
assert_eq "last-run heading" "$(grep -c '^## Last run$' "$tmp/p.md")" 1
for n in analysis frame last-run implementation plan; do
  ticket_section_del "$tmp/p.md" "$n"; assert_exit "del $n" $? 0
done
same "all five out" "$tmp/p.md" "$tmp/p.md.orig"

# a section as the only thing in an empty file
: >"$tmp/e.md"; ticket_section_put "$tmp/e.md" frame "$tmp/c2.txt"
assert_eq "empty file starts with heading" "$(head -n 1 "$tmp/e.md")" "## Frame"
ticket_section_del "$tmp/e.md" frame; assert_eq "empty file restored" "$(wc -c <"$tmp/e.md" | tr -d ' ')" 0

# bad input
ticket_section_put "$tmp/p.md" bogus "$tmp/c1.txt"; assert_exit "put unknown name" $? 1
ticket_section_del "$tmp/p.md" bogus; assert_exit "del unknown name" $? 1
ticket_section_put "$tmp/p.md" plan "$tmp/none.txt"; assert_exit "put missing content" $? 1
same "bad input untouched" "$tmp/p.md" "$tmp/p.md.orig"
printf '# T\n<!-- sherpa:plan -->\nnever closed\n' >"$tmp/u.md"; snap "$tmp/u.md"
ticket_section_put "$tmp/u.md" plan "$tmp/c2.txt"; assert_exit "put unclosed" $? 1
ticket_section_del "$tmp/u.md" plan; assert_exit "del unclosed" $? 1
same "unclosed untouched" "$tmp/u.md" "$tmp/u.md.orig"

# --- ticket_find
mkdir -p "$tmp/inventory/p/frame" "$tmp/inventory/p/shape" "$tmp/inventory/q/done"
echo '# T' >"$tmp/inventory/p/frame/LPD-1.md"; echo '# U' >"$tmp/inventory/q/done/LPD-1.md"
assert_eq "find" "$(ticket_find p LPD-1)" "$tmp/inventory/p/frame/LPD-1.md"
mv "$tmp/inventory/p/frame/LPD-1.md" "$tmp/inventory/p/shape/LPD-1.md"
assert_eq "find after move" "$(ticket_find p LPD-1)" "$tmp/inventory/p/shape/LPD-1.md"
ticket_find p NOPE >/dev/null; assert_exit "find unknown" $? 1
ticket_find p ../q/done/LPD-1 >/dev/null; assert_exit "find bad id" $? 1
ticket_find nopack LPD-1 >/dev/null; assert_exit "find unknown pack" $? 1

[ "$fail" -eq 0 ] && echo "PASS: all ticket cases" || { echo FAILED; exit 1; }
