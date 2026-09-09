# Shared rules

Source of truth for rule blocks duplicated (with drift) across skills and agents.
`scripts/inline-shared-rules.sh` stamps each `## <block>` section below into the files mapped to
it in `BLOCK_FILE_MAP`, between `<!-- shared:<block> -->` / `<!-- /shared -->` markers. Edit here,
then re-run that script — never hand-edit the marker region in a target file. The block is **not**
fenced in target files — the inliner writes the close marker on its own line, so a block ending in
a bare fence line (` ``` ` alone) no longer merges with it. Never wrap a `<!-- shared:<block> -->`
/ `<!-- /shared -->` marker pair in a surrounding ` ``` ` fence in a target file: the parser treats
fenced regions as opaque, so a wrapped marker silently stops being inlined — `--check` renders the
same opaque fence on both sides and cannot catch the drift.

## skill-rules
- **Authority:** the human decides at the human gates each skill lists; the driver decides and
  shows everything else.
- **Narrate only on task changes.** One short sentence when the *task* changes; stay silent between
  tool calls otherwise.
- **Questions:** a prose walk in three lines — *found* (what turned up, in user-observable terms),
  *which means* (why there's a choice), *so* (the hand-off) — then `AskUserQuestion`, each option's
  description one clause naming its downstream consequence (distinct from the label),
  recommended option first. A pure preference question skips the walk. Skip the introduction for a
  surface the reader already showed they know. The test for any human-facing prose: the reader
  must be able to act on it without opening the code — otherwise introduce or translate the term.
- **Harness:** under Codex/pi, read Claude-specific tool mentions per
  `${CLAUDE_PLUGIN_ROOT}/protocols/harness/codex.md` / `pi.md`.
- **Pack:** forward `configPath` to every subagent; each resolves it itself via
  `bash scripts/resolve-pack-value.sh <configPath> <layer>`.

## agent-rules
- **Allowed exactly:** Read, Grep, Glob, and Bash restricted to `git status`, `git diff`, `git log`,
  `git show`, `git blame`, `grep`, `find`, `cat`, `ls` — and nothing else.
- Your final message is the return value — compact markdown, no preamble.
- **Evidence-first.** Every claim cites a `file:line` or a concrete check.
- **Never hedge the verdict.** The verdict token stands regardless of what follows.

## reviewer-output
VERDICT: OK | GAPS
ATTACKED: <angles tried — non-empty even when OK>
GAPS:
- <quote> — <category>; <what must change>
