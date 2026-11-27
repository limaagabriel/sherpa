---
name: implement
description: Build layer. Builds an approved plan from /shape (or a bare task arg drafted into one step and gated on human approval) one step at a time, step-builder plus a quality-reviewer per step. Triggers - "/implement", "/implement <task>", "build the plan", "implement this". Counterparts - /frame, /shape.
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
  `bash scripts/pack/load-layer.sh <configPath> <layer>`. `configPath=none` counts as announced —
  forward it verbatim.
<!-- /shared -->
<!-- shared:unattended -->Args start with `--unattended` → read `${CLAUDE_PLUGIN_ROOT}/protocols/unattended.md` first; it overrides every ask/wait in this skill.
<!-- /shared -->

# /implement — build, with pressure per step

Build to completion. Match the layer to how clear the task is — for a one-obvious-change task,
start here directly. Pressure lives per step (acceptance + quality); a Validate phase then audits the whole run.

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
   checklist); flip a step done only when it is built (its commit landed, or it is a `NO-COMMIT`
   step). Record the **run base** (`git rev-parse HEAD`) and the first `UNCOMMITTED BEFORE STEP` before any dispatch.
2. **Per step.**
   - Keep a **run ledger**, one row per step: `pre` (HEAD before dispatch), pre-flight result, final
     SHA, review rounds, lenses run, the last `ACCEPTANCE`/`PRODUCES` lines, verdict, and the
     `Guardrails:` line from the step-builder. After every fold-in re-check, replace the row's final
     SHA with the new one. Record the **full** SHA (`git rev-parse <sha>` on the step-builder's short
     one) after `BUILT` and after each re-check, so it matches `git log --format=%H`. `NO-COMMIT`
     replaces the SHA only when the step's own Change says it commits nothing (edits outside the
     repo, a regen with no diff); any other step without a commit fails the audit.
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
     by a later step). Its output always carries one `ACCEPTANCE: MET|UNMET`
     line per acceptance criterion and one `PRODUCES: MET|UNMET` line per declared `produces` entry,
     and closes with `PASS|FIX|BLOCK`.
   - **Risk-scaled lenses** (non-mechanical steps only). On `BUILT`, read the `## Deep-pass triggers`
     section of `${CLAUDE_PLUGIN_ROOT}/protocols/lenses/correctness.md` and `acceptance.md`, plus the
     "Runs only when the diff touches" list in `security.md`, and check them against the step's own
     range, `git diff <pre>..HEAD` (`pre` from the run ledger). For each lens that hits, dispatch
     `code-reviewer` in parallel with `quality-reviewer`, using /analyze's **Lens dispatch prompt**
     shape (step 4 there, same per-harness dispatch): you read `${CLAUDE_PLUGIN_ROOT}/skills/analyze/references/reviewer.md`
     and the lens file and inject their content — never paths — plus the step's `Goal` as the change
     description, the step's diff, and `configPath` when announced. Lens findings labelled `Blocking`
     join the quality `FIX` items in one fold-in brief, deduped by `file:line`, each item naming its
     source. Non-`Blocking` lens findings are printed, not acted on. The ledger records the lenses run.
   - **Skill guardrails** (every step, mechanical ones too — a guardrail is the user's rule, not a risk
     call). On `BUILT`, when `configPath` is announced, run `/invoke <skill> <args>` for each `skill` entry from
     `guardrails/list.sh <configPath> step skill`, with the step's range. A skill that
     fails (its report names any failure or blocking finding) joins the fold-in brief as a `Blocking`
     item that cannot be rebutted. The ledger records `GUARDRAIL <name>: pass|fail`.
3. **Verdicts.**
   a. An `ACCEPTANCE: UNMET` line, a quality `FIX`, a `Blocking` lens finding, or a failed skill
      guardrail → relay to the step-builder to fold into its commit; re-check once. The step-builder
      may answer a lens item with `REBUTTED <finding> — <file:line evidence>` instead of changing
      code; the re-check re-dispatches the same lenses with the rebuttals, and re-runs `/invoke` for each skill
      guardrail that failed, updating its ledger `GUARDRAIL` line. Still failing after that (a lens
      that still holds its finding counts) → stop: one framing line naming what it blocks, then
      the finding quoted exactly; offer `/shape` in one declinable line, passing the framing line,
      the quoted finding, and the step's Goal as `REVISIT`.
   b. `BLOCK` → stop the same way: one framing line, then the finding quoted exactly; offer `/shape`
      in one declinable line, passing the framing line, the quoted finding, and the step's Goal
      as `REVISIT`.
   c. Every `ACCEPTANCE: MET` + `PASS` → next step.
   d. Any reviewer output containing `recommend /shape revisit` → stop, surface the same way, offer
      `/shape` in one declinable line, passing the framing line, the quoted finding, and the step's
      Goal as `REVISIT`.
   e. `STALE <anchor>` (a pre-dispatch miss from the pre-flight check above) → stop the same way:
      one framing line naming what it blocks, then the finding quoted exactly; no `step-builder`
      dispatch happens for that step; offer `/shape` in one declinable line, passing the framing
      line, the quoted finding, and the step's Goal as `REVISIT`.
4. **Validate.** Once every step is built with no open `BLOCK`, run these in order. Any fail →
   stop: one framing line, then the quoted output; offer a one-step fix as `/implement <fix>` (its
   own approval gate) in one declinable line.
   1. **Process audit.** Every plan step has a ledger row ending `PASS` with all lines `MET`.
      `git log --reverse --format=%H <base>..HEAD` equals the ledger's final SHAs in order,
      skipping `NO-COMMIT` rows (no missing, extra or reordered commit). `git status --short` equals
      the run's first `UNCOMMITTED BEFORE STEP`. Any `Guardrails: setup error` row fails. Print the
      ledger table, then `PROCESS: pass|fail <reason>`.
   2. **Guardrails**, when `configPath` is announced. Run
      `bash <plugin root>/scripts/guardrails/run.sh <configPath> end` (exit 1 and exit 2 both fail).
      Then run `/invoke <skill> <args>` for each `skill` entry from
      `guardrails/list.sh <configPath> end skill`; a skill fails when its report names any failure or blocking finding. Print
      `GUARDRAIL <name>: pass|fail` per skill and `GUARDRAILS: pass|fail` overall.
   3. **Goal check.** Run the plan's Block 3 "how it's verified" once — execute whatever part of the
      test plan is re-runnable as-is; treat anything that needs a human to observe the end state as
      a manual checklist item. Never fabricate a pass for something you didn't actually check. Then
      also run the plan goal statement's own `done when` check (the goal statement has the shape
      `<Outcome> for <consumers> because <motivation>; done when <verification>` per `/shape`). If
      that check is textually the same command/check as one already run for Block 3, don't run it
      twice — run it once and print a note saying so, e.g. "same check as Block 3, ran once." A
      `done when` check that is manual (per `/shape`'s own "manual only with a stated reason"
      allowance) routes to the same manual-checklist-item handling used above. Print the result as
      `GOAL: <check> → pass|fail`.
   Bare-task runs do 1 and 2, skip 3 (no plan goal statement to check).

## Done when
Every step built, no open `BLOCK` or `STALE`, and Validate passed: process audit, end
guardrails, and (with a plan) the goal check. Present the per-step results; offer `/persist` if
wanted.
