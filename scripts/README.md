# scripts

Small bash scripts that keep sherpa's packs, agents and CI working.

## Layout

`scripts/<group>/<verb>[-<noun>].sh` — the folder is the noun, the file name is the action.

- `pack/` — project and layer context for sessions and subagents
- `agents/` — generated agent files
- `ci/` — repo checks run by CI
- `hooks/` — Claude Code hook entry points (`guard-bash.sh` keeps read-only agents from changing state)
- `lib/` — sourced helpers with noun names; they define functions and are never run directly

A test sits beside its script as `test-<script name>.sh`.

## Verbs

Only these eight:

- `find` — print one path
- `load` — print context for an agent
- `list` — print entries
- `run` — execute and report pass/fail
- `build` — write generated files (`--check` only compares)
- `check` — verify the repo, write nothing
- `guard` — refuse a tool call
- `test` — test a script

## Rules

- One job per script.
- Start with a header: `# Usage:`, input, output, exit codes.
- At most 80 lines.
- Use `set -euo pipefail`, except hook entry points whose contract is "never fail" (their header says so).
