#!/usr/bin/env bash
# Usage: guard-write.sh   (Claude Code PreToolUse hook, matcher Write|Edit; hook JSON on stdin)
# Input:  hook JSON (agent_type, tool_input.file_path); ${CLAUDE_PLUGIN_ROOT}/agents/<name>.md.
#         Guarded = agent_type "sherpa:<name>" whose agent file has `codexSandbox: read-only`
#         (same detection as guard-bash.sh).
# Output: for a guarded caller, a permissionDecision "deny" JSON unless the resolved target is
#         inside ${TMPDIR:-/tmp}/sherpa-*/ (the handoff dir, see protocols/handoff.md); nothing
#         for everyone else. Fails closed: no jq, no/unparsable file_path, or a realpath failure.
# Exit:   always 0 — a hook entry point whose contract is "never fail", so no set -e.
input=$(cat)
agent=""

deny() {  # <reason>
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}
block() { deny "sherpa: $agent is read-only; it may write only inside its HANDOFF dir (a sherpa-* dir under the temp dir), see protocols/handoff.md. Blocked: $1"; }  # <why>
guarded() {  # <agent_type> -> sets $agent when it is sherpa:<name> and read-only
  [[ $1 =~ ^sherpa:([A-Za-z0-9_-]+)$ ]] || return 1
  local n=${BASH_REMATCH[1]}
  grep -qx 'codexSandbox: read-only' "${CLAUDE_PLUGIN_ROOT:-/nonexistent}/agents/$n.md" 2>/dev/null || return 1
  agent=$n
}

# Without jq, or when jq cannot parse the input, the agent is read by regex and every write of a
# guarded caller is denied.
re='"agent_type"[[:space:]]*:[[:space:]]*"(sherpa:[A-Za-z0-9_-]+)"'
if ! command -v jq >/dev/null 2>&1 || ! jq -e . >/dev/null 2>&1 <<<"$input"; then
  if [[ $input =~ $re ]] && guarded "${BASH_REMATCH[1]}"; then
    block "every write, because the sherpa read-only guard needs jq and parsable input"
  fi
  exit 0
fi
guarded "$(printf '%s' "$input" | jq -r '.agent_type // empty' 2>/dev/null)" || exit 0

path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[[ $path == /* ]] || block "a missing or relative file path"
base=$(realpath -m -- "${TMPDIR:-/tmp}" 2>/dev/null) && [ -n "$base" ] || block "an unresolvable temp dir"
target=$(realpath -m -- "$path" 2>/dev/null) && [ -n "$target" ] || block "an unresolvable file path"

# Both sides are resolved (symlinks, `..`), so the target must sit strictly inside a direct child
# `sherpa-<suffix>` of the temp dir: `${base}/sherpa-x/<file>`; the dir itself does not pass.
prefix=${base%/}/
rest=${target#"$prefix"}
[[ $rest != "$target" && $rest =~ ^sherpa-[^/]+/.+ ]] || block "a path outside the handoff dir"
exit 0
