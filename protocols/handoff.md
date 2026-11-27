# Handoff

A per-run directory where a read-only agent leaves a long output as a file, so the coordinator's
context holds one line instead of the whole text. Any skill or agent may use it.

## When a coordinator uses it
- The output's main reader is another agent (a reviewer's findings that a later pass reads).
- The coordinator needs only a gist of the output.
- A verdict the coordinator must act on stays inline — never hand it off.

## Coordinator
1. Create the dir: `HANDOFF=$(mktemp -d "${TMPDIR:-/tmp}/sherpa-XXXXXX")`. Never inside the repo.
2. Pass `HANDOFF=<abs dir>` in each agent's prompt.
3. Read each file the agents name in their `WROTE` line, only when you need the content.
4. When an agent returns its content inline (see below), print one line naming it.
5. Delete the dir when the run ends: `rm -rf "$HANDOFF"`.

## Agent
- With `HANDOFF` in your prompt, write the full output to `<HANDOFF>/<agent>-<lens>.md` with the
  `Write` tool and return one line: `WROTE <path> — <≤15-word gist>`.
- Write only inside `HANDOFF`; no other path, never the repo.
- No `HANDOFF` in the prompt, or the write fails (denied or errors): return the content inline.

## Enforcement
- **Claude Code:** `scripts/hooks/guard-write.sh` denies a read-only sherpa agent any `Write` or
  `Edit` outside `${TMPDIR:-/tmp}/sherpa-*/`.
- **pi:** nothing enforces it; the agent must keep writes inside `HANDOFF`.
- **Codex:** the read-only sandbox blocks the write, so agents fall back to the inline return.
