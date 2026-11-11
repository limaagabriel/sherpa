#!/usr/bin/env bash
# Usage: source scripts/lib/frontmatter.sh
# Purpose: read an agent file's YAML frontmatter and guard values before they are written
#   into twins. Defines extract_frontmatter <file>, fm_get <role> <fm> <field>,
#   guard_no_triple_quote <role> <field> <value> and guard_yaml_plain_scalar <role> <field>
#   <value>. fm_get and the guards print "build-twins: ..." to stderr and exit 1 on bad input.
#   Needs yq. Sourced only; never run directly.

extract_frontmatter() {
  awk '/^---$/{c++; next} c==1' "$1"
}

fm_get() {
  local role="$1" fm="$2" field="$3" value
  value="$(printf '%s\n' "$fm" | yq eval ".$field" -)"
  if [[ "$value" == "null" ]]; then
    echo "build-twins: $role is missing required frontmatter field '$field'" >&2
    exit 1
  fi
  printf '%s\n' "$value"
}

guard_no_triple_quote() {
  local role="$1" field="$2" value="$3"

  [[ "$value" == *"'''"* ]] || return 0

  echo "build-twins: $role.$field contains ''' which would break the TOML '''...''' block" >&2
  exit 1
}

guard_yaml_plain_scalar() {
  local role="$1" field="$2" value="$3"

  if [[ "$value" == *$'\n'* || "$value" == *": "* || "$value" == *" #"* ]]; then
    echo "build-twins: $role.$field is unsafe as a YAML plain scalar (newline, ': ', or ' #')" >&2
    exit 1
  fi

  case "$value" in
    -*|\?*|:*|\#*|\&*|\**|\!*|\|*|\>*|\'*|\"*|%*|@*|\`*)
      echo "build-twins: $role.$field starts with a YAML indicator character unsafe as a plain scalar" >&2
      exit 1
      ;;
  esac
}
