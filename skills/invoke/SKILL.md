---
name: invoke
description: Runs a pack skill or any markdown file as a skill. Triggers - "/invoke <name|path> [args]", a PACK SKILLS match.
---

# Invoke

Runs a pack skill, or any markdown file, as if it were a loaded skill.

Plugin root: `$CLAUDE_PLUGIN_ROOT` when set, else `$SHERPA_PLUGIN_ROOT`, else the installed sherpa plugin root. `configPath` is the one announced for the session; use `none` when none was announced.

## Workflow

1. **No args** → run `bash <plugin root>/scripts/pack/list-skills.sh <configPath|none>` and print the output. Stop.
2. **Resolve the first arg**, first match wins:
   1. It contains `/` or ends in `.md`, and the file exists → that file.
   2. `bash <plugin root>/scripts/pack/find-skill.sh <configPath|none> <name>` prints a `SKILL.md` path (exit 1 means none).
   3. A native skill of that name, through the harness's own skill mechanism (Claude Code: the Skill tool; Codex: `protocols/harness/codex.md`; pi: `protocols/harness/pi.md`). If none fits, go on.
   4. Otherwise print the list from step 1 and stop. Never guess a file.
3. **Read the file.** The frontmatter is metadata; the body is the instructions. The remaining args are its ARGUMENTS. Follow it as if it were a loaded skill.
4. **Relative paths** in the body resolve against the file's own folder (its companion files).
5. **`allowed-tools`** in its frontmatter is advisory: follow it, though nothing enforces it.

## Trust

The file runs with your permissions and is not sandboxed. This is the same trust as a pack `detect` or a guardrail `run`.
