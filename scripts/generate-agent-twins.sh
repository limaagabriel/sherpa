#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
agents_dir="$repo_root/agents"
codex_dir="$repo_root/.codex/agents"
pi_dir="$repo_root/.pi/agents"

extract_frontmatter() {
  awk '/^---$/{c++; next} c==1' "$1"
}

fm_get() {
  printf '%s\n' "$1" | yq eval ".$2" -
}

guard_no_triple_quote() {
  local role="$1" field="$2" value="$3"

  [[ "$value" == *"'''"* ]] || return 0

  echo "generate-agent-twins: $role.$field contains ''' which would break the TOML '''...''' block" >&2
  exit 1
}

guard_yaml_plain_scalar() {
  local role="$1" field="$2" value="$3"

  if [[ "$value" == *$'\n'* || "$value" == *": "* || "$value" == *" #"* ]]; then
    echo "generate-agent-twins: $role.$field is unsafe as a YAML plain scalar (newline, ': ', or ' #')" >&2
    exit 1
  fi

  case "$value" in
    -*|\?*|:*|\#*|\&*|\**|\!*|\|*|\>*|\'*|\"*|%*|@*|\`*)
      echo "generate-agent-twins: $role.$field starts with a YAML indicator character unsafe as a plain scalar" >&2
      exit 1
      ;;
  esac
}

write_codex_twin() {
  local name="$1" fm="$2"
  local description model effort sandbox header body

  description="$(fm_get "$fm" description)"
  model="$(fm_get "$fm" codexModel)"
  effort="$(fm_get "$fm" codexReasoningEffort)"
  sandbox="$(fm_get "$fm" codexSandbox)"
  header="$(fm_get "$fm" codexHeaderComment)"
  body="$(fm_get "$fm" codexBody)"

  guard_no_triple_quote "$name" description "$description"
  guard_no_triple_quote "$name" codexBody "$body"

  {
    printf '%s\n' "$header"
    printf 'name = "%s"\n' "$name"
    printf "description = '''%s'''\n" "$description"
    printf 'model = "%s"\n' "$model"
    printf 'model_reasoning_effort = "%s"\n' "$effort"
    printf 'sandbox_mode = "%s"\n' "$sandbox"
    printf "developer_instructions = '''\n"
    printf '%s\n' "$body"
    printf "'''\n"
  } > "$codex_dir/$name.toml"
}

write_pi_twin() {
  local name="$1" fm="$2"
  local description tools gist

  description="$(fm_get "$fm" description)"
  tools="$(fm_get "$fm" piTools)"
  gist="$(fm_get "$fm" piGist)"

  guard_yaml_plain_scalar "$name" description "$description"
  guard_yaml_plain_scalar "$name" piTools "$tools"

  {
    printf '%s\n' "---"
    printf 'name: %s\n' "$name"
    printf 'package: sherpa\n'
    printf 'description: %s\n' "$description"
    printf 'tools: %s\n' "$tools"
    printf 'systemPromptMode: replace\n'
    printf 'inheritProjectContext: true\n'
    printf 'inheritSkills: false\n'
    printf '%s\n' "---"
    printf '\n'
    printf "You are sherpa's %s. Read your full role definition, invariants, and output contract from the canonical sherpa package file \`agents/%s.md\` and follow it exactly.\n" "$name" "$name"
    printf '\n'
    printf 'Resolve the sherpa package root (the dir containing `agents/`) in this order:\n'
    printf '1. `$SHERPA_PLUGIN_ROOT` (exported by the pi extension) when set.\n'
    printf '2. Else `~/.pi/agent/npm/node_modules/sherpa`.\n'
    printf '3. Else `~/.pi/agent/git/*/*/sherpa`.\n'
    printf '\n'
    printf '%s\n' "$gist"
  } > "$pi_dir/$name.md"
}

generate_twin() {
  local file="$1" name fm

  name="$(basename "$file" .md)"
  [ "$name" = "README" ] && return 0

  fm="$(extract_frontmatter "$file")"
  write_codex_twin "$name" "$fm"
  write_pi_twin "$name" "$fm"
}

for file in "$agents_dir"/*.md; do
  generate_twin "$file"
done
