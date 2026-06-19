# Output Contract

The four-block handoff every builder writes to `handoffs/<BUILD ID>.<n>.md` after committing. Coordinator and reviewers key off this file — same shape, same fields across all tiers.

## The handoff file + return line

Write the four blocks to `handoffs/<BUILD ID>.<n>.md` in the run-state dir (`mkdir -p` parent first if absent). Return to the coordinator **only** the handoff path plus a one-line verdict (`BUILD OK <short SHA>` / `BUILD FAILED <reason>`) — never paste the four blocks inline. Fill in the selected task-type's required template fields (see `protocols/invariants/task-types.md`).

## The four blocks

### EVIDENCE PACK
- Claim: <what you verified>
  Command: <verbatim shell command>
  Exit code: <0 / non-zero>
  Output excerpt: <success/failure line + ~20 lines, or log path>

(If nothing was run: `EVIDENCE PACK: none — no build/test claims` for default tier, or `EVIDENCE PACK: none` for codegen with an explanation.)

### CLAIMS
- <file:line or path> — <what changed there>

### DECISIONS
- <choice> — rationale: <why this, or why departing from precedent>

(Default tier: `grep <pattern> → <N matches / none>`. Codegen tier: `Generator: <command>; output owned by formatter/generator, no hand-authoring`.)

### DIFF SUMMARY
<2–4 sentences: what changed and why.>
Committed/amended as `<subject>` — Build-Id note `<BUILD ID>.<n>` (`<short SHA>`).
