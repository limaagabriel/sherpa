# Implement

Build the plan one step at a time with a single builder + two reviewers (acceptance, quality).
No separate Validate phase — adversarial pressure lives per step.

## One step at a time
- Track one step `in_progress` at a time (TaskCreate/TaskUpdate when available; else a plain
  in-message checklist). Flip a step done only on its commit landing.
- **No plan in context?** Treat the `<task>` arg as one implicit step — build it directly.

## Per-step build
Dispatch `builder` with the step's `task` + `Goal` + `Acceptance criteria` (+ pack
`codeStyleRules`/`initialize` path when announced). Pure-codegen step → dispatch at model
haiku; else default. Each step:
- Builds in isolation — module still builds, no half-applied artifacts.
- Lands exactly one commit (real subject). The builder owns it; never add a manual commit on top.
- On `BUILT`, two L3 reviewers run in parallel over the step's commit range:
  `acceptance-reviewer` (met its criteria?) and `quality-reviewer` (clean, correct, secure, no regression).

## Verdicts (one gradation)
- `UNMET`, or a quality `FIX` → relay to the builder to fold into its commit; re-check once.
- `MET` + `PASS` → next step.
- `BLOCK` → stop, surface verbatim to the human.

## Done
Every step committed, no open `BLOCK`. Present the per-step results; offer the persist skill
if the user wants the run on disk.
