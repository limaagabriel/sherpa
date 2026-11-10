#!/usr/bin/env bash
# Usage: list.sh <configPath> <step|end> [run|skill]
# Input:  configPath (project.yaml); reads guardrails.yaml beside it:
#   guardrails: [{name, run | skill, args?, when: step|end|both (default both)}]
# Output: one line per entry matching the phase (and kind, if given):
#   name<TAB>kind<TAB>value   (kind = run|skill; value = the command, or the skill
#   name plus " <args>" when args is set). Values must be a single line.
# Exit:   0 ok or nothing to do (configPath "none", or no guardrails.yaml);
#   2 cannot run: usage error, unknown phase/kind/when, yq missing, malformed YAML,
#   an entry without name, with a multi-line value, or with both/neither of run/skill.
set -euo pipefail

die() { echo "list.sh: $*" >&2; exit 2; }

config=${1:-}; phase=${2:-}; want=${3:-}
[ -n "$config" ] || die "usage: list.sh <configPath> <step|end> [run|skill]"
case "$phase" in step|end) ;; *) die "unknown phase: '$phase' (expected step or end)" ;; esac
case "$want" in ""|run|skill) ;; *) die "unknown kind: '$want' (expected run or skill)" ;; esac
[ "$config" != none ] || exit 0

file="$(dirname "$config")/guardrails.yaml"
[ -f "$file" ] || exit 0
command -v yq >/dev/null 2>&1 || die "yq not found — cannot read $file (install yq v4+)"

get() { yq -r ".guardrails[$1].$2 // \"\"" "$file" 2>/dev/null || die "malformed YAML: $file"; }

count=$(yq '.guardrails | length' "$file" 2>/dev/null) || die "malformed YAML: $file"
for ((i = 0; i < count; i++)); do
  name=$(get $i name); run=$(get $i run); skill=$(get $i skill)
  when=$(get $i when); args=$(get $i args)
  [ -n "$name" ] || die "entry $i in $file has no name"
  case "$name$run$skill$args" in *$'\n'*) die "'$name': values must be a single line" ;; esac
  if [ -n "$run" ] && [ -n "$skill" ]; then die "'$name' has both run and skill"; fi
  if [ -z "$run" ] && [ -z "$skill" ]; then die "'$name' has neither run nor skill"; fi
  case "${when:-both}" in step|end|both) ;; *) die "'$name' has unknown when: $when" ;; esac
  case "${when:-both}" in both|"$phase") ;; *) continue ;; esac
  if [ -n "$run" ]; then kind=run; value=$run; else kind=skill; value="$skill${args:+ $args}"; fi
  [ -z "$want" ] || [ "$want" = "$kind" ] || continue
  printf '%s\t%s\t%s\n' "$name" "$kind" "$value"
done
