# Implement (build layer)

Build the plan one step at a time with a single step-builder + reviewers — acceptance and quality
for normal steps, quality alone (covering both) for mechanical steps (§ Mechanical steps).
No separate Validate phase — adversarial pressure lives per step (Cohen 2006).

## One step at a time
- Track one step `in_progress` at a time (TaskCreate/TaskUpdate when available; else a plain
  in-message checklist). Flip a step done only on its commit landing.
- **No plan in context?** Treat the `<task>` arg as one implicit step — build it directly.

## Mechanical steps
A step is **mechanical** when its Change is entirely one of: pure codegen (a mechanical transform,
no design judgment), docs-only (prose/comments, no behavior change), config-only (a config/manifest
value, no code-path change), or pure wiring (connecting two already-built pieces, no new logic). A
step carrying any non-trivial logic, even small, is NOT mechanical — when in doubt, treat it as a
normal step. This is the single owner classifying steps as mechanical; no other file does.

**Model tier.** A mechanical step dispatches `step-builder` at model haiku; a normal step dispatches
at the default model. This replaces and subsumes the old "pure-codegen only" haiku rule that used
to live in § Per-step build.

**Pre-dispatch resolution.** The same `implement.review` pre-dispatch resolution (§ Per-step build)
applies here too, before the merged single-reviewer dispatch below — the driver resolves it first
and, when non-empty, follows it to shape this mechanical step's dispatch instead of the default.

**Merged review.** For a mechanical step, on `BUILT`, dispatch ONLY `quality-reviewer` — skip
`acceptance-reviewer` entirely for this step — but extend `quality-reviewer`'s brief for this
dispatch to also include the step's `Acceptance criteria` and `Interfaces` (the inputs
`acceptance-reviewer` would normally check). `quality-reviewer` emits its normal `PASS`/`FIX`/`BLOCK`
verdict AND, appended, one `ACCEPTANCE: MET | UNMET <criterion> — <evidence>` line per acceptance
criterion. It must ALSO check each declared `produces` entry against the actual built symbol — same
name, same param/return shape, actually reachable — the same way `acceptance-reviewer` normally
does, and emit one `PRODUCES: MET | UNMET <produces entry> — <evidence>` line per declared
`produces` entry (skip `produces: none`), even when a mismatch doesn't correspond to any
acceptance-criterion text — `Interfaces` and `Acceptance criteria` are separate fields
(`protocols/workflow/phases/shape.md` § Block 2) that don't map 1:1, so a renamed/reshaped/
unreachable `produces` symbol could otherwise pass silently. Verdict handling for mechanical steps:
`FIX`/`BLOCK` follow § Verdicts exactly as already stated; any `ACCEPTANCE: UNMET` or `PRODUCES:
UNMET` line feeds into § Verdicts the same way an `acceptance-reviewer` `UNMET` already does
(relay-once-then-terminal) — don't re-derive the state machine here.

**Non-mechanical steps** are entirely unaffected: dispatch both `acceptance-reviewer` and
`quality-reviewer` as today, at the default model tier.

## Per-step build
- **Ask before dispatch.** Any step-scoped question the driver still needs answered is asked by
  the driver, shaped per `protocols/questions.md`, before dispatching that step's `step-builder` —
  the step-builder never asks the user.

Dispatch `step-builder` with the step's `task` + `Goal` + `Interfaces` + `Acceptance criteria`
(+ `configPath` when announced — the step-builder resolves its own `context`/`implement.context`,
`implement.codeStyle`, and `implement.validate` via resolve-pack-value.sh, the same self-resolved way,
when announced).
Model tier and post-build review both follow whether the step is mechanical (§ Mechanical steps).
Each step:
- Builds in isolation — module still builds, no half-applied artifacts, unless that build failure
  is covered by a later step's goal.
- Lands exactly one commit (real subject). The step-builder owns it; never add a manual commit on top.
- **Before dispatching this step's reviewer(s)**, the driver itself (not any subagent) resolves
  `implement.review` — when `configPath` is announced — via `bash scripts/resolve-pack-value.sh
  <configPath> implement.review`, the same self-resolved, point-of-need way `structure-reviewer`
  (dispatched by `/shape`) already resolves `shape.context`/`shape.architecture`. It's a
  `.md` file path or array, resolved exactly like `codeStyle`/`context` (no special mode). When
  it resolves to non-empty content, the driver follows its plain-English instructions to shape
  which reviewer(s) it dispatches for this step and what extra they're briefed to check, instead
  of always falling back to the hardcoded pattern below. This mechanism never spawns a new
  subagent type — whatever gets dispatched is still `acceptance-reviewer` and/or `quality-reviewer`;
  the prose can only shape which of those run and what extra they check. Any resulting reviewer
  output still resolves to the existing `PASS`/`FIX`/`BLOCK` / `MET`/`UNMET` vocabulary, folded
  into § Verdicts unchanged — `implement.review` introduces no new verdict shape. Absent or empty
  → the driver runs its default dispatch below unchanged.
- On `BUILT`, for a normal (non-mechanical) step, two L3 reviewers run in parallel over the step's
  commit range: `acceptance-reviewer` (met its criteria? also gets the step's `Interfaces`, to
  judge the declared `produces` against the built symbols) and `quality-reviewer` (clean, correct,
  secure, no regression; also gets `configPath` when announced — the quality-reviewer resolves its own
  `context`/`implement.context` and `implement.codeStyle` via resolve-pack-value.sh — plus the current
  step index + remaining step goals, so it can tell whether a failure is covered by a later step). A mechanical
  step runs the merged single-reviewer path instead (§ Mechanical steps).

## Verdicts (one gradation)
Every verbatim surface below leads with one line naming, in the reader's terms, what it blocks
(`protocols/prose.md` § Verbatim is a quote, not a frame); the quote itself stays byte-exact.
- `UNMET`, or a quality `FIX` → relay to the step-builder to fold into its commit; re-check once.
- Still `UNMET` or `FIX` after that re-check → stop, same terminal handling as `BLOCK`: surface
  verbatim to the human, do not loop again.
- `MET` + `PASS` → next step.
- `BLOCK` → stop, surface verbatim to the human.
- Any reviewer output containing `recommend /shape revisit` → stop, surface verbatim to the human,
  offer `/shape` in one declinable line.

## Plan-level verification
- **Trigger.** Once every step is committed with no open `BLOCK`, run the plan's Block 3
  "How it's verified" (`protocols/workflow/phases/shape.md` § Block 3 — Why & how) once,
  before presenting (MAST 2025).
- **Execution.** Run whatever part of Block 3's test plan is re-runnable as-is; treat anything
  that isn't (i.e., requires a human to observe the end state) as a manual checklist item —
  inferred from what the test plan actually says, not a labeling convention Block 3 is required
  to carry. Don't fabricate a pass for something you didn't actually check.
- **Failure handling.** A failure here is terminal — same handling as `BLOCK`: surface verbatim,
  do not loop again.
- **Scope note.** This is not a resurrected separate Validate phase — it's the plan's own
  already-authored verification section, executed once, not a new independent review gate
  re-checking each step's work. Adversarial pressure still lives per-step (acceptance + quality);
  this just closes the loop on the plan's own stated end-state check.
- **Standalone note.** Skip entirely when no plan was in context (a standalone `/implement <task>`
  run built one implicit step and has no Block 3 to run).

## Done
Every step committed, no open `BLOCK`, the Plan-level verification section run (when a plan
existed). Present the per-step results plus the verification outcome; offer the persist skill if
the user wants the run on disk.
