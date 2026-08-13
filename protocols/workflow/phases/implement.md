# Implement

Build the plan one step at a time with a single step-builder + two reviewers (acceptance, quality).
No separate Validate phase — adversarial pressure lives per step.

## One step at a time
- Track one step `in_progress` at a time (TaskCreate/TaskUpdate when available; else a plain
  in-message checklist). Flip a step done only on its commit landing.
- **No plan in context?** Treat the `<task>` arg as one implicit step — build it directly.

## Per-step build
- **Ask before dispatch.** Any step-scoped question the driver still needs answered is asked by
  the driver, shaped per `protocols/questions.md`, before dispatching that step's `step-builder` —
  the step-builder never asks the user.

Dispatch `step-builder` with the step's `task` + `Goal` + `Interfaces` + `Acceptance criteria`
(+ pack `knowledge`/`implement.knowledge` inline prose and
`implement.codeStyleRules`/`implement.validate` commands, when announced).
Pure-codegen step → dispatch at model haiku; else default. Each step:
- Builds in isolation — module still builds, no half-applied artifacts, unless that build failure
  is covered by a later step's goal.
- Lands exactly one commit (real subject). The step-builder owns it; never add a manual commit on top.
- On `BUILT`, two L3 reviewers run in parallel over the step's commit range:
  `acceptance-reviewer` (met its criteria? also gets the step's `Interfaces`, to judge the
  declared `produces` against the built symbols) and `quality-reviewer` (clean, correct, secure,
  no regression; also gets pack `knowledge`/`implement.knowledge` inline prose and
  `implement.codeStyleRules` command output when announced, plus the current step index +
  remaining step goals, so it can tell whether a failure is covered by a later step).

## Verdicts (one gradation)
- `UNMET`, or a quality `FIX` → relay to the step-builder to fold into its commit; re-check once.
- Still `UNMET` or `FIX` after that re-check → stop, same terminal handling as `BLOCK`: surface
  verbatim to the human, do not loop again.
- `MET` + `PASS` → next step.
- `BLOCK` → stop, surface verbatim to the human.
- Any reviewer output containing `recommend /decompose revisit` → stop, surface verbatim to the human,
  offer `/decompose` in one declinable line.

## Done
Every step committed, no open `BLOCK`. Present the per-step results; offer the persist skill
if the user wants the run on disk.
