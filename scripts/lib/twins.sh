#!/usr/bin/env bash
# Usage: source scripts/lib/twins.sh   (after scripts/lib/frontmatter.sh)
# Purpose: write one agent's Codex and pi twins. Defines write_codex_twin <name> <fm>,
#   write_pi_twin <name> <fm> and generate_twin <agent file>. The entry script sets the
#   variables codex_dir and pi_dir (output dirs). Sourced only; never run directly.

write_codex_twin() {
  local name="$1" fm="$2"
  local description model effort sandbox header body

  description="$(fm_get "$name" "$fm" description)"
  model="$(fm_get "$name" "$fm" codexModel)"
  effort="$(fm_get "$name" "$fm" codexReasoningEffort)"
  sandbox="$(fm_get "$name" "$fm" codexSandbox)"
  header="$(fm_get "$name" "$fm" codexHeaderComment)"
  body="$(fm_get "$name" "$fm" codexBody)"

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
  local description tools thinking gist

  description="$(fm_get "$name" "$fm" description)"
  tools="$(fm_get "$name" "$fm" piTools)"
  thinking="$(fm_get "$name" "$fm" piThinking)"
  gist="$(fm_get "$name" "$fm" piGist)"

  guard_yaml_plain_scalar "$name" description "$description"
  guard_yaml_plain_scalar "$name" piTools "$tools"

  {
    printf '%s\n' "---"
    printf 'name: %s\n' "$name"
    printf 'package: sherpa\n'
    printf 'description: %s\n' "$description"
    printf 'tools: %s\n' "$tools"
    printf 'thinking: %s\n' "$thinking"
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

  fm="$(extract_frontmatter "$file")"
  write_codex_twin "$name" "$fm"
  write_pi_twin "$name" "$fm"
}
