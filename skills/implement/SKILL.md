---
name: implement
description: Build layer (L3). Build an approved plan one step at a time — one step-builder per step + acceptance and quality reviewers, with adversarial pressure per step. Reads the plan from context if present; standalone, treats the <task> as one implicit step. No separate Validate phase. Triggers - "/implement", "/implement <task>", "build the plan", "implement this". Counterparts - /spec, /plan.
---

# /implement — build, with pressure per step

Build to completion. The bottom of the ceremony gradient — for a one-obvious-change task, start
here directly. Pressure lives per step (acceptance + quality), not in a final gate.

## Operating rules
- **Authority:** the human owns every decision. You propose; they decide.
- **Stance:** feedback-first — open with a brief take when the human floats an approach.
- **No narration between tools.** One short sentence only when the *task* changes.
- **Conventions:** conform to the project's own style — via the pack's `codeStyleRules` when announced, else the surrounding code; evidence-only (quote file:line).
- **Harness:** under Codex/pi, read Claude-specific tool mentions per `${CLAUDE_PLUGIN_ROOT}/protocols/harness/codex.md` / `pi.md`.
- **Never push.** Commit only when the human asks. The step-builder owns one commit per step — never
  add a manual commit on top.

## Steps
1. **Get context.** Plan in context → build its steps. **No plan** → treat the `<task>` arg as one
   implicit step. If the task is large enough to want decomposition, offer `/plan` first in one
   declinable line. **A persisted spec/plan file path given as the arg** — read it back and
   consume it exactly as an in-context artifact.
2. **Build.** Follow `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/implement.md`: one step at a time, exactly one
   in progress. Per step — the driver asks any step-scoped question first, shaped per
   `${CLAUDE_PLUGIN_ROOT}/protocols/questions.md`, then dispatches `step-builder` (haiku for pure
   codegen, else default) with
   `task` + `Goal` + `Interfaces` + `Acceptance criteria` + pack `knowledge` (cross-cutting) and
   `implement.knowledge` (additive) inline prose, plus `implement.codeStyleRules` and
   `implement.validate` commands, when announced.
   On `BUILT`, run `acceptance-reviewer` + `quality-reviewer` in parallel over the step's range —
   `acceptance-reviewer` also gets the step's `Interfaces`, to judge the declared `produces`
   against the built symbols; `quality-reviewer` also gets pack `knowledge`/`implement.knowledge`
   inline prose and `implement.codeStyleRules` command output when announced, plus the current
   step index + remaining step goals.
3. **Verdicts.** `UNMET` or a quality `FIX` → relay to the step-builder to fold in, re-check once;
   still `UNMET`/`FIX` after that → stop, same terminal handling as `BLOCK`, surface verbatim, no
   further looping. `MET` + `PASS` → next step. `BLOCK` → stop, surface to the human. Any reviewer
   output with `recommend /plan revisit` → stop, surface verbatim, offer `/plan` in one declinable line.

## Done when
Every step committed, no open `BLOCK`. Present the per-step results; offer `/persist` if wanted.
