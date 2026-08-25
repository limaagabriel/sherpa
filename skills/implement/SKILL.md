---
name: implement
description: Build layer (L3). Builds an approved plan from /shape (or the task arg as one implicit step) one step at a time, step-builder plus reviewers per step. No separate Validate phase. Triggers - "/implement", "/implement <task>", "build the plan", "implement this". Counterparts - /frame, /shape.
---

# /implement — build, with pressure per step

Build to completion. The bottom of the ceremony gradient — for a one-obvious-change task, start
here directly. Pressure lives per step (acceptance + quality), not in a final gate.

## Operating rules
- **Authority:** the human owns every decision. You propose; they decide.
- **Stance:** feedback-first — open with a brief take when the human floats an approach.
- **No narration between tools.** One short sentence only when the *task* changes.
- **Conventions:** conform to the project's own style — the surrounding code; evidence-only (quote file:line). The pack's `codeStyle` (when present) is resolved by the subagent via resolve-pack-value.sh.
- **Harness:** under Codex/pi, read Claude-specific tool mentions per `${CLAUDE_PLUGIN_ROOT}/protocols/harness/codex.md` / `pi.md`.
- **Never push.** Commit only when the human asks. The step-builder owns one commit per step — never
  add a manual commit on top.

## Steps
1. **Get context.** Plan in context → build its steps. **No plan** → treat the `<task>` arg as one
   implicit step. If the task is large enough to want a plan, offer `/shape` first in
   one declinable line. **A persisted frame, pitch, or plan file path given as the arg** — read it
   back and consume it exactly as an in-context artifact.
2. **Build.** Follow `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/implement.md`: one step at a time, exactly one
   in progress. Per step — the driver asks any step-scoped question first, shaped per
   `${CLAUDE_PLUGIN_ROOT}/protocols/questions.md`, then dispatches `step-builder` with
   `task` + `Goal` + `Interfaces` + `Acceptance criteria` + `configPath` when announced (the step-builder
   resolves its own `knowledge`/`implement.knowledge`, `implement.codeStyle`, and `implement.validate` via
   resolve-pack-value.sh, the same self-resolved way). Before dispatching that step's reviewer(s), the
   driver itself resolves `implement.review` via resolve-pack-value.sh and, when it resolves to non-empty
   content, follows its instructions to shape that dispatch instead of the default —
   model tier and post-build review both follow whether the step is mechanical, per
   `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/implement.md` § Mechanical steps.
3. **Verdicts.** Handle verdicts per
   `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/implement.md` § Verdicts — UNMET/FIX
   relay-once-then-terminal, BLOCK stops, MET+PASS continues; surface verbatim per
   `${CLAUDE_PLUGIN_ROOT}/protocols/prose.md` § Verbatim is a quote, not a frame.
4. **Verify.** After the last step lands `MET`+`PASS`, run the plan's Block 3 verification once
   per `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/implement.md` § Plan-level verification —
   skip when no plan was in context.

## Done when
Every step committed, no open `BLOCK`, plan-level verification run when applicable. Present the
per-step results; offer `/persist` if wanted.
