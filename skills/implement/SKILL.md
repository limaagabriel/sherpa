---
name: implement
description: Build layer. Builds an approved plan from /shape (or a bare task arg drafted into one step and gated on human approval) one step at a time, step-builder plus a quality-reviewer per step. No separate Validate phase. Triggers - "/implement", "/implement <task>", "build the plan", "implement this". Counterparts - /frame, /shape.
---
<!-- shared:skill-rules -->- **Authority:** the human decides at the human gates each skill lists; the driver decides and
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
<!-- /shared -->

# /implement — build, with pressure per step

Build to completion. Match the layer to how clear the task is — for a one-obvious-change task,
start here directly. Pressure lives per step (acceptance + quality), not in a final gate.

## Operating rules
- **Never push.** The step-builder makes exactly one commit per step; the driver adds none.

## Steps
1. **Get context.** Plan in context → build its steps. **A persisted plan file path given as the
   arg** — read it back and consume it exactly as an in-context artifact (already approved
   elsewhere, no gate needed here). **No plan, bare `<task>` arg** — this is /implement's own human
   gate: draft ONE step (`Goal` + `Acceptance criteria`, the same shape a `/shape`-produced step
   would have — see `/shape`'s own `## Human gates`), present it, and wait for explicit approval
   before dispatching `step-builder`. If it's large enough to want a plan instead, offer `/shape` in
   one declinable line before drafting. Once approved, proceed exactly as step 2 below. Track one
   step `in_progress` at a time (TaskCreate/TaskUpdate when available, else a plain in-message
   checklist); flip a step done only when its commit lands.
2. **Per step.**
   - Ask any step-scoped question first, per Operating rules — the step-builder never asks the user.
   - **Pre-flight STALE check.** For each of the step's `consumes` entries: if the entry does not
     start with a `<path>` in anchor form (i.e. it's `none`, or predates this format), print
     `UNANCHORED <entry>` and continue treating it as before (no gate). Otherwise run
     `git cat-file -e HEAD:<path>` to confirm the path exists; when the anchor carries a
     `::literal`, also run `git grep -q -F -e "<literal>" HEAD -- "<path>"` (pass the literal as a
     `-e` argument, never interpolated inside a quoted string, so a literal containing an
     apostrophe or shell metacharacter doesn't break the check or become an injection vector). Any
     miss — path absent, or literal absent when required — makes the anchor stale; see verdict e.
   - Dispatch `step-builder` with the step's `task` + `Goal` + `Interfaces` + `Acceptance criteria`
     + `UNCOMMITTED BEFORE STEP` (`git status --short` run before this step's dispatch) + `configPath`
     when announced. A **mechanical step** — its Change is entirely one of: pure codegen (a
     mechanical transform, no design judgment), docs-only (prose/comments, no behavior change),
     config-only (a config/manifest value, no code-path change), or pure wiring (connecting two
     already-built pieces, no new logic) — dispatches `step-builder` at model haiku; any non-trivial
     logic, even small, makes it normal and dispatches at the default model. When in doubt, normal.
   - On `BUILT`, dispatch `quality-reviewer` over the step's commit range for every step alike
     (mechanical and normal), briefed with the step's `Acceptance criteria` and `Interfaces`, the
     current step index, and the remaining steps' goals (so it can tell whether a failure is covered
     by a later step). Its output always carries `PASS|FIX|BLOCK` plus one `ACCEPTANCE: MET|UNMET`
     line per acceptance criterion and one `PRODUCES: MET|UNMET` line per declared `produces` entry.
3. **Verdicts.**
   a. An `ACCEPTANCE: UNMET` line, or a quality `FIX` → relay to the step-builder to fold into its
      commit; re-check once. Still failing after that → stop: one framing line naming what it
      blocks, then the finding quoted exactly.
   b. `BLOCK` → stop the same way: one framing line, then the finding quoted exactly.
   c. Every `ACCEPTANCE: MET` + `PASS` → next step.
   d. Any reviewer output containing `recommend /shape revisit` → stop, surface the same way, offer
      `/shape` in one declinable line.
   e. `STALE <anchor>` (a pre-dispatch miss from the pre-flight check above) → stop the same way:
      one framing line naming what it blocks, then the finding quoted exactly; no `step-builder`
      dispatch happens for that step.
4. **Verify.** Once every step is committed with no open `BLOCK`, run the plan's Block 3 "how it's
   verified" once — execute whatever part of the test plan is re-runnable as-is; treat anything that
   needs a human to observe the end state as a manual checklist item. Never fabricate a pass for
   something you didn't actually check. Then also run the plan goal statement's own `done when`
   check (the goal statement has the shape `<Outcome> for <consumers> because <motivation>; done
   when <verification>` per `/shape`). If that check is textually the same command/check as one
   already run for Block 3, don't run it twice — run it once and print a note saying so, e.g. "same
   check as Block 3, ran once." A `done when` check that is manual (per `/shape`'s own "manual only
   with a stated reason" allowance) routes to the same manual-checklist-item handling used above.
   Print the goal check's result as `GOAL: <check> → pass|fail`. A failure here — whether from
   Block 3's check or the goal's `done when` check — is terminal, same handling as `BLOCK`. Skip
   entirely when no plan was in context (a bare-task /implement run has no plan goal statement to
   check).

## Done when
Every step committed, no open `BLOCK` or `STALE`, plan-level verification run when applicable, goal
done-when run. Present the per-step results; offer `/persist` if wanted.
