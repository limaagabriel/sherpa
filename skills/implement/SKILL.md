---
name: implement
description: Build layer (L3). Build an approved plan one step at a time — one step-builder per step + acceptance and quality reviewers, with adversarial pressure per step. Reads the plan from context if present; standalone, treats the <task> as one implicit step. No separate Validate phase. Triggers - "/implement", "/implement <task>", "build the plan", "implement this". Counterparts - /spec, /plan.
Layer: build
---

# /implement — build, with pressure per step

Build to completion. The bottom of the ceremony gradient — for a one-obvious-change task, start
here directly. Pressure lives per step (acceptance + quality), not in a final gate.

## Operating rules
- Same Authority / Stance / no-narration / Conventions / Harness rules as `/spec`.
- **Never push.** Commit only when the human asks. The step-builder owns one commit per step — never
  add a manual commit on top.

## Steps
1. **Get context.** Plan in context → build its steps. **No plan** → treat the `<task>` arg as one
   implicit step. If the task is large enough to want decomposition, offer `/plan` first in one
   declinable line.
2. **Build.** Follow `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/implement.md`: one step at a time, exactly one
   in progress. Per step — dispatch `step-builder` (haiku for pure codegen, else default) with
   `task` + `Goal` + `Acceptance criteria` + pack `codeStyleRules`/`initialize` path when announced.
   On `BUILT`, run `acceptance-reviewer` + `quality-reviewer` in parallel over the step's range.
3. **Verdicts.** `UNMET` or a quality `FIX` → relay to the step-builder to fold in, re-check once.
   `MET` + `PASS` → next step. `BLOCK` → stop, surface to the human.

## Done when
Every step committed, no open `BLOCK`. Present the per-step results; offer `/persist` if wanted.
