#!/usr/bin/env bash
# Usage: guard-bash.sh   (Claude Code PreToolUse hook, matcher Bash; hook JSON on stdin)
# Input:  hook JSON (agent_type, tool_input.command); ${CLAUDE_PLUGIN_ROOT}/agents/<name>.md.
#         Guarded = agent_type "sherpa:<name>" whose agent file has `codexSandbox: read-only`.
# Output: for a guarded caller running a state-changing command, a permissionDecision "deny"
#         JSON (never updatedInput); nothing for everyone else.
# Exit:   always 0 — a hook entry point whose contract is "never fail", so no set -e.
input=$(cat)
agent=""

deny() {  # <reason>
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}
block() { deny "sherpa: $agent is read-only; blocked: ${1//[^A-Za-z0-9 ._=-]/}"; }  # <what>
guarded() {  # <agent_type> -> sets $agent when it is sherpa:<name> and read-only
  [[ $1 =~ ^sherpa:([A-Za-z0-9_-]+)$ ]] || return 1
  local n=${BASH_REMATCH[1]}
  grep -qx 'codexSandbox: read-only' "${CLAUDE_PLUGIN_ROOT:-/nonexistent}/agents/$n.md" 2>/dev/null || return 1
  agent=$n
}

if ! command -v jq >/dev/null 2>&1; then
  re='"agent_type"[[:space:]]*:[[:space:]]*"(sherpa:[A-Za-z0-9_-]+)"'
  if [[ $input =~ $re ]] && guarded "${BASH_REMATCH[1]}"; then
    deny "sherpa: $agent is read-only; blocked: every command, because the sherpa read-only guard needs jq"
  fi
  exit 0
fi
guarded "$(printf '%s' "$input" | jq -r '.agent_type // empty' 2>/dev/null)" || exit 0
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$cmd" ] || exit 0

# Quoted text is removed so `grep -n "a > b"` and `awk '$1 > 5'` pass. A `sh -c "..."` or
# `eval` payload is the one place a command hides inside quotes, so there the quotes become
# separators and the inner text is scanned too.
cmd=${cmd//$'\n'/$'\001'}
scan=$(printf '%s' "$cmd" | sed -E "s/\"[^\"]*\"|'[^']*'//g")
if [[ $scan =~ (^|[^[:alnum:]_.-])(eval|(ba|z|da|)sh[[:space:]]+-[a-zA-Z]*c)([[:space:]]|$) ]]; then
  scan=$(printf '%s' "$cmd" | tr "\"'" ';;')
fi

# Any `>` left after dropping /dev/null and fd-duplication (2>&1) writes a file.
redir=$(printf '%s' "$scan" | sed -E 's/[0-9&]?>>?[[:space:]]*\/dev\/null//g; s/[0-9]?>&[0-9-]//g')
[[ $redir == *'>'* ]] && block "output redirect to a file"

# One simple command per segment; wrapper words (rtk, env, VAR=x, ...) are skipped.
read_set='^(status|diff|log|show|blame|grep|rev-parse|cat-file|ls-files|ls-tree|describe|shortlog|merge-base|rev-list|for-each-ref|name-rev)$'
list_flag='^(-a|-r|-v|-vv|-l|--list|--all|--remotes|--verbose|--show-current|--contains|--no-contains|--merged|--no-merged|--points-at|--format=.*|--sort=.*)$'
wrap='^([A-Za-z_][A-Za-z0-9_]*=.*|env|rtk|sudo|command|time|exec|nohup|nice|xargs|then|do|else|if|while|!|-.*)$'
while IFS= read -r seg; do
  read -ra w <<<"$seg"
  i=0
  while [[ ${w[i]-} =~ $wrap ]]; do i=$((i + 1)); done
  c=${w[i]-}
  c=${c##*/}
  case $c in
    rm|rmdir|mv|cp|mkdir|touch|chmod|chown|ln|tee|truncate|dd|install|patch) block "$c" ;;
    sed|perl) for a in "${w[@]:i+1}"; do [[ $a =~ ^-[pnalEsrw]*i|^--in-place ]] && block "$c -i"; done ;;
    find) for a in "${w[@]:i+1}"; do
        case $a in -delete|-exec|-execdir|-ok|-okdir) block "find $a" ;; esac
      done ;;
    git)
      j=$((i + 1))
      while [[ ${w[j]-} == -* ]]; do
        case ${w[j]} in -C|-c|--git-dir|--work-tree|--namespace) j=$((j + 2)) ;; *) j=$((j + 1)) ;; esac
      done
      sub=${w[j]-}
      if [[ -z $sub || $sub =~ $read_set ]]; then continue; fi
      [[ $sub == branch ]] || block "git $sub"
      p=""
      for a in "${w[@]:j+1}"; do
        [[ $a =~ $list_flag || $p =~ ^--(contains|no-contains|merged|no-merged|points-at)$ ]] || block "git branch $a"
        p=$a
      done ;;
  esac
done <<<"$(printf '%s' "$scan" | tr ';&|()`\001' '\n')"
exit 0
