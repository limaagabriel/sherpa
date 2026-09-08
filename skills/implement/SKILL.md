---
name: implement
description: Build layer. Builds an approved plan from /shape (or the task arg as one implicit step) one step at a time, step-builder plus reviewers per step. No separate Validate phase. Triggers - "/implement", "/implement <task>", "build the plan", "implement this". Counterparts - /frame, /shape.
---

# /implement — build, with pressure per step

Build to completion. Match the layer to how clear the task is — for a one-obvious-change task,
start here directly. Pressure lives per step (acceptance + quality), not in a final gate.

## Operating rules
- **Authority:** the human owns every decision. You propose; they decide.
- **No narration between tools.** One short sentence only when the *task* changes.
- **Questions:** a prose walk in three lines — *found* (what turned up, in user-observable terms),
  *which means* (why there's a choice), *so* (the hand-off) — then `AskUserQuestion`, each option's
  description one clause naming its downstream consequence, recommended option first. A pure
  preference question gets no walk. Skip the introduction for a surface the reader already showed
  they know. The test for any human-facing prose: could the reader act on it without opening the
  code? If not, introduce or translate the term.
- **Harness:** under Codex/pi, read Claude-specific tool mentions per
  `${CLAUDE_PLUGIN_ROOT}/protocols/harness/codex.md` / `pi.md`.
- **Pack:** forward `configPath` to `step-builder`, `acceptance-reviewer`, and `quality-reviewer`;
  each resolves it itself via `bash scripts/resolve-pack-value.sh <configPath> implement`.
- **Never push.** Commit only when the human asks. The step-builder owns one commit per step — never
  add a manual commit on top.

## Steps
1. **Get context.** Plan in context → build its steps. **No plan** → treat the `<task>` arg as one
   implicit step; if it's large enough to want a plan, offer `/shape` first in one declinable line.
   **A persisted plan file path given as the arg** — read it back and consume it exactly as an
   in-context artifact. Track one step `in_progress` at a time (TaskCreate/TaskUpdate when
   available, else a plain in-message checklist); flip a step done only when its commit lands.
2. **Per step.**
   - Ask any step-scoped question first, per Operating rules — the step-builder never asks the user.
   - Dispatch `step-builder` with the step's `task` + `Goal` + `Interfaces` + `Acceptance criteria`
     + `UNCOMMITTED BEFORE STEP` (`git status --short` run before this step's dispatch) + `configPath`
     when announced.
   - **Mechanical step** — its Change is entirely one of: pure codegen (a mechanical transform, no
     design judgment), docs-only (prose/comments, no behavior change), config-only (a
     config/manifest value, no code-path change), or pure wiring (connecting two already-built
     pieces, no new logic). Any non-trivial logic, even small, makes it normal — when in doubt,
     normal. A mechanical step dispatches `step-builder` at model haiku and, on `BUILT`,
     `quality-reviewer` alone — briefed also with the step's `Acceptance criteria` and `Interfaces`,
     and asked to append one `ACCEPTANCE: MET | UNMET <criterion> — <evidence>` line per acceptance
     criterion and one `PRODUCES: MET | UNMET <entry> — <evidence>` line per declared `produces`
     entry.
   - **Normal step** — on `BUILT`, dispatch `acceptance-reviewer` and `quality-reviewer` in parallel
     over the step's commit range; `quality-reviewer` also gets the current step index and the
     remaining steps' goals, so it can tell whether a failure is covered by a later step.
3. **Verdicts.**
   - `UNMET`, or a quality `FIX` → relay to the step-builder to fold into its commit; re-check once.
     Still failing after that → stop: one framing line naming what it blocks, then the finding
     quoted exactly.
   - `BLOCK` → stop the same way: one framing line, then the finding quoted exactly.
   - `MET` + `PASS` → next step.
   - Any reviewer output containing `recommend /shape revisit` → stop, surface the same way, offer
     `/shape` in one declinable line.
4. **Verify.** Once every step is committed with no open `BLOCK`, run the plan's Block 3 "how it's
   verified" once — execute whatever part of the test plan is re-runnable as-is; treat anything that
   needs a human to observe the end state as a manual checklist item. Never fabricate a pass for
   something you didn't actually check. A failure here is terminal, same handling as `BLOCK`. Skip
   entirely when no plan was in context.

## Done when
Every step committed, no open `BLOCK`, plan-level verification run when applicable. Present the
per-step results; offer `/persist` if wanted.
