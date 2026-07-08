#!/usr/bin/env bash
# Self-check for resolve-project-pack.sh path resolution. Runs the real resolver
# against temp fixtures and asserts the emitted SessionStart payload. No framework.
set -u

here=$(cd "$(dirname "$0")" && pwd)
resolver="$here/resolve-project-pack.sh"

command -v yq >/dev/null 2>&1 || { echo "SKIP: yq not installed"; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not installed"; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail=0
run() { printf '{"cwd":"%s"}' "$1" | bash "$resolver"; }
ctx() { run "$1" | jq -r '.hookSpecificOutput.additionalContext // ""'; }
msg() { run "$1" | jq -r '.systemMessage // ""'; }

assert_contains() {
  case "$2" in
    *"$3"*) ;;
    *) echo "FAIL [$1]: expected to contain:"; echo "  $3"; echo "got:"; echo "  $2"; fail=1 ;;
  esac
}
assert_not_contains() {
  case "$2" in
    *"$3"*) echo "FAIL [$1]: expected NOT to contain:"; echo "  $3"; echo "got:"; echo "  $2"; fail=1 ;;
  esac
}

# (a) project-local .codex/sherpa.yaml — relative command resolves against the proximate base
repo="$tmp/repo"
mkdir -p "$repo/.codex"
cat >"$repo/.codex/sherpa.yaml" <<'YAML'
name: proj-a
detect: "exit 0"
pack:
  implement:
    codeStyleRules: cat ./rules.md
YAML
out=$(ctx "$repo")
assert_contains "a/command" "$out" "cd '$repo/.codex' && cat ./rules.md"
assert_contains "a/message" "$(msg "$repo")" "Project \"proj-a\" loaded into Sherpa from $repo/.codex/sherpa.yaml 🏔️"
assert_contains "a/primer" "$out" "check whether one of these fits"

# (b) workspace YAML under a .claude ancestor — base must walk up to <tmp>/home/.claude
ws_home="$tmp/home"
packs="$ws_home/.claude/sherpa/projects"
mkdir -p "$packs"
cat >"$packs/proj-b.yaml" <<'YAML'
name: proj-b
detect: "exit 0"
pack:
  plan:
    architectureRules: cat ./arch.md
YAML
cleancwd="$tmp/elsewhere"
mkdir -p "$cleancwd"
out=$(WORKFLOW_PACKS_DIR="$packs" ctx "$cleancwd")
assert_contains "b/base-is-.claude" "$out" "cd '$ws_home/.claude' && cat ./arch.md"

# (c) knowledge prose + absolute command passthrough — knowledge is emitted verbatim,
# never cd-wrapped; a command embedding an absolute path is still wrapped (harmless —
# cwd does not affect an absolute path).
repo_c="$tmp/repoc"
mkdir -p "$repo_c/.claude"
cat >"$repo_c/.claude/sherpa.yaml" <<'YAML'
name: proj-c
detect: "exit 0"
pack:
  knowledge: "Consult the my-skill guide before editing."
  implement:
    codeStyleRules: cat /abs/rules.md
YAML
out=$(ctx "$repo_c")
assert_contains "c/knowledge-verbatim" "$out" 'knowledge="Consult the my-skill guide before editing."'
assert_not_contains "c/knowledge-no-wrap" "$out" "&& Consult"
assert_contains "c/abs-command" "$out" "cat /abs/rules.md"

# (d) base path with a space — emitted cd must single-quote it so the consumer's
# `bash -c` does not split it into too many args.
repo_d="$tmp/repo d"
mkdir -p "$repo_d/.codex"
cat >"$repo_d/.codex/sherpa.yaml" <<'YAML'
name: proj-d
detect: "exit 0"
pack:
  implement:
    codeStyleRules: cat ./rules.md
YAML
out=$(ctx "$repo_d")
assert_contains "d/quoted-base" "$out" "cd '$repo_d/.codex' && cat ./rules.md"
# the emitted command must actually run (cd succeeds, no "too many arguments")
( cd "$repo_d/.codex" && echo hi >rules.md )
emitted=$(printf '%s' "$out" | sed -n "s/.*implement.codeStyleRules=\"\\(cd '[^\"]*\\)\".*/\\1/p")
bash -c "$emitted" >/dev/null 2>&1 || { echo "FAIL [d/runnable]: emitted cmd failed: $emitted"; fail=1; }

# (f) project-local .pi/sherpa.yaml — relative command resolves against the proximate base
repo_f="$tmp/repof"
mkdir -p "$repo_f/.pi"
cat >"$repo_f/.pi/sherpa.yaml" <<'YAML'
name: proj-f
detect: "exit 0"
pack:
  implement:
    codeStyleRules: cat ./rules.md
YAML
out=$(ctx "$repo_f")
assert_contains "f/command" "$out" "cd '$repo_f/.pi' && cat ./rules.md"
assert_contains "f/message" "$(msg "$repo_f")" "Project \"proj-f\" loaded into Sherpa from $repo_f/.pi/sherpa.yaml 🏔️"

# (g) two-level flatten — a bare top-level `knowledge` and a nested `implement.knowledge`
# coexist in the same pack and both appear, correctly named, in the emitted line.
repo_g="$tmp/repog"
mkdir -p "$repo_g/.claude"
cat >"$repo_g/.claude/sherpa.yaml" <<'YAML'
name: proj-g
detect: "exit 0"
pack:
  knowledge: "Top-level project prose."
  implement:
    knowledge: "Implement-section prose."
    validate: /my-validate-skill
YAML
out=$(ctx "$repo_g")
assert_contains "g/top-level-knowledge" "$out" 'knowledge="Top-level project prose."'
assert_contains "g/nested-knowledge" "$out" 'implement.knowledge="Implement-section prose."'
assert_contains "g/nested-validate" "$out" "implement.validate=/my-validate-skill"
assert_not_contains "g/no-cross-leak" "$out" 'implement.knowledge="Top-level project prose."'

# (h) project-local config with NO `detect` key still matches — file presence
# at the fixed path is the detection.
repo_h="$tmp/repoh"
mkdir -p "$repo_h/.claude"
cat >"$repo_h/.claude/sherpa.yaml" <<'YAML'
name: proj-h
pack:
  knowledge: /my-project-init
YAML
assert_contains "h/local-no-detect-matches" "$(msg "$repo_h")" "Project \"proj-h\" loaded into Sherpa"

# (i) workspace config with NO `detect` key must NOT match — one shared dir
# serves many projects, so a real `detect` is required to pick the right one.
packs_i="$tmp/packs-i"
mkdir -p "$packs_i"
cat >"$packs_i/proj-i.yaml" <<'YAML'
name: proj-i
pack:
  knowledge: /my-project-init
YAML
cleancwd_i="$tmp/elsewhere-i"
mkdir -p "$cleancwd_i"
assert_not_contains "i/workspace-no-detect-skipped" "$(WORKFLOW_PACKS_DIR="$packs_i" msg "$cleancwd_i")" "proj-i"

# (j) knowledge value with spaces — quoted verbatim, never cd-wrapped
repo_j="$tmp/repoj"
mkdir -p "$repo_j/.claude"
cat >"$repo_j/.claude/sherpa.yaml" <<'YAML'
name: proj-j
detect: "exit 0"
pack:
  knowledge: "Every plan ends with a version bump."
YAML
out=$(ctx "$repo_j")
assert_contains "j/knowledge-quoted" "$out" 'knowledge="Every plan ends with a version bump."'
assert_not_contains "j/knowledge-not-wrapped" "$out" "cd '"

# (k) multi-line knowledge block scalar — collapses to one line, trailing
# whitespace trimmed, still quoted, still not cd-wrapped
repo_k="$tmp/repok"
mkdir -p "$repo_k/.claude"
cat >"$repo_k/.claude/sherpa.yaml" <<'YAML'
name: proj-k
detect: "exit 0"
pack:
  knowledge: |
    Line one of prose.
    Line two of prose.
YAML
out=$(ctx "$repo_k")
assert_contains "k/knowledge-collapsed" "$out" 'knowledge="Line one of prose. Line two of prose."'
assert_not_contains "k/knowledge-not-wrapped" "$out" "cd '"

# (l) knowledge value with an embedded double quote — escaped, not left bare
repo_l="$tmp/repol"
mkdir -p "$repo_l/.claude"
cat >"$repo_l/.claude/sherpa.yaml" <<'YAML'
name: proj-l
detect: "exit 0"
pack:
  knowledge: 'Follow the "boy scout rule".'
YAML
out=$(ctx "$repo_l")
assert_contains "l/knowledge-escaped-quote" "$out" 'knowledge="Follow the \"boy scout rule\"."'
assert_not_contains "l/knowledge-not-wrapped" "$out" "cd '"

# (e) no pack matches — primer must still be force-loaded via additionalContext
nomatch="$tmp/nomatch"
mkdir -p "$nomatch"
out=$(ctx "$nomatch")
assert_contains "e/primer" "$out" "check whether one of these fits"

[ "$fail" -eq 0 ] && echo "PASS: all resolution cases" || echo "FAILED"
exit "$fail"
