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
  codeStyleRules: cat ./rules.md
YAML
out=$(ctx "$repo")
assert_contains "a/command" "$out" "cd '$repo/.codex' && cat ./rules.md"
assert_contains "a/message" "$(msg "$repo")" "Project \"proj-a\" loaded into Sherpa from $repo/.codex/sherpa.yaml 🏔️"

# (b) workspace YAML under a .claude ancestor — base must walk up to <tmp>/home/.claude
ws_home="$tmp/home"
packs="$ws_home/.claude/sherpa/projects"
mkdir -p "$packs"
cat >"$packs/proj-b.yaml" <<'YAML'
name: proj-b
detect: "exit 0"
pack:
  architectureRules: cat ./arch.md
YAML
cleancwd="$tmp/elsewhere"
mkdir -p "$cleancwd"
out=$(WORKFLOW_PACKS_DIR="$packs" ctx "$cleancwd")
assert_contains "b/base-is-.claude" "$out" "cd '$ws_home/.claude' && cat ./arch.md"

# (c) absolute + slash-skill passthrough — left untouched, never cd-wrapped
repo_c="$tmp/repoc"
mkdir -p "$repo_c/.claude"
cat >"$repo_c/.claude/sherpa.yaml" <<'YAML'
name: proj-c
detect: "exit 0"
pack:
  codeStyleAudit: /my-style-audit
  codeStyleRules: cat /abs/rules.md
YAML
# slash-skill (value starts with /) stays unwrapped; a command embedding an
# absolute path is still wrapped (harmless — cwd does not affect an absolute path).
out=$(ctx "$repo_c")
assert_contains "c/slash-skill" "$out" "codeStyleAudit=/my-style-audit"
assert_not_contains "c/skill-no-wrap" "$out" "&& /my-style-audit"
assert_contains "c/abs-command" "$out" "cat /abs/rules.md"

# (d) base path with a space — emitted cd must single-quote it so the consumer's
# `bash -c` does not split it into too many args.
repo_d="$tmp/repo d"
mkdir -p "$repo_d/.codex"
cat >"$repo_d/.codex/sherpa.yaml" <<'YAML'
name: proj-d
detect: "exit 0"
pack:
  codeStyleRules: cat ./rules.md
YAML
out=$(ctx "$repo_d")
assert_contains "d/quoted-base" "$out" "cd '$repo_d/.codex' && cat ./rules.md"
# the emitted command must actually run (cd succeeds, no "too many arguments")
( cd "$repo_d/.codex" && echo hi >rules.md )
emitted=$(printf '%s' "$out" | sed -n "s/.*codeStyleRules=\"\\(cd '[^\"]*\\)\".*/\\1/p")
bash -c "$emitted" >/dev/null 2>&1 || { echo "FAIL [d/runnable]: emitted cmd failed: $emitted"; fail=1; }

[ "$fail" -eq 0 ] && echo "PASS: all resolution cases" || echo "FAILED"
exit "$fail"
