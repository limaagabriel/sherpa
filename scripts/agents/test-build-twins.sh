#!/usr/bin/env bash
# Usage: test-build-twins.sh
# Input:  none; runs build-twins.sh on a fixture agent in a temp dir. No framework.
# Output: "PASS: all twin cases" or FAIL lines plus "FAILED".
# Exit:   0 when every case passes, 1 otherwise (0 with SKIP when yq is missing).
set -u
here=$(cd "$(dirname "$0")" && pwd)
command -v yq >/dev/null 2>&1 || { echo "SKIP: yq not installed"; exit 0; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
# Helpers from lib/assert.sh: assert_eq (exact output), assert_exit (exit code).
source "$here/../lib/assert.sh"

mkdir -p "$tmp/agents" "$tmp/codex" "$tmp/pi"
mkagent() {  # <description>
  cat >"$tmp/agents/demo.md" <<EOT
---
name: demo
description: "$1"
codexModel: m-1
codexReasoningEffort: high
codexSandbox: read-only
codexHeaderComment: |-
  # header
codexBody: |-
  Body line.
piTools: read, grep
piThinking: high
piGist: |-
  Gist line.
---
Body.
EOT
}
build() {
  TWINS_AGENTS_DIR="$tmp/agents" TWINS_CODEX_DIR="$tmp/codex" TWINS_PI_DIR="$tmp/pi" \
    bash "$here/build-twins.sh" 2>/dev/null
}

mkagent "A demo."
build; assert_exit build-ok $? 0
assert_eq codex-twin "$(cat "$tmp/codex/demo.toml")" "# header
name = \"demo\"
description = '''A demo.'''
model = \"m-1\"
model_reasoning_effort = \"high\"
sandbox_mode = \"read-only\"
developer_instructions = '''
Body line.
'''"
assert_eq pi-head "$(head -n 10 "$tmp/pi/demo.md" | tr '\n' '|')" \
  "---|name: demo|package: sherpa|description: A demo.|tools: read, grep|thinking: high|systemPromptMode: replace|inheritProjectContext: true|inheritSkills: false|---|"
assert_eq pi-tail "$(tail -n 1 "$tmp/pi/demo.md")" "Gist line."
assert_eq pi-root-lines "$(sed -n '12,18p' "$tmp/pi/demo.md" | cut -c1-20 | tr '\n' '|')" \
  "You are sherpa's dem||Resolve the sherpa p|1. \`\$SHERPA_PLUGIN_R|2. Else \`~/.pi/agent|3. Else \`~/.pi/agent||"

mkagent "bad ''' quote"; build; assert_exit guard-triple-quote $? 1
mkagent "bad: colon"; build; assert_exit guard-plain-scalar $? 1

[ "$fail" -eq 0 ] && echo "PASS: all twin cases" || echo "FAILED"
exit "$fail"
