---
name: plan
description: Step layer (L2). Decompose a goal into ordered, traceable steps, then get a cold-eyes critique of the decomposition before any code. Reads the spec from context if present; standalone, takes a <task> and does a light scout. Writes nothing to disk. Triggers - "/plan", "/plan <task>", "decompose this", "break it into steps". Skip /spec and start here when the goal is already clear. Counterparts - /spec (intent+discovery), /implement (build).
Layer: step
---

# /plan — decompose into steps

Produce an **approved plan** (the step list) for the goal. The middle of the ceremony gradient.
Entry point for a medium task whose goal is clear but wants decomposition + step-critique. Skip
it for a one-obvious-change task (go straight to `/implement`).

The plan lives **in context** (printed, not on disk). Persisting is the opt-in `/persist` skill.

## Operating rules
- Same Authority / Stance / no-narration / Conventions / Harness rules as `/spec`.

## Steps
1. **Get context.** Spec in context → use it as the goal + discovery. **No spec** → treat the
   `<task>` arg as the goal, run a quick `/scout`; do not refine intent or write open questions
   (that's `/spec`). If the task is genuinely fuzzy, offer `/spec` first in one declinable line.
2. **Settle what blocks a step.** Resolve any open questions that block a step boundary —
   `AskUserQuestion`, or answers already in the conversation. Leave the rest open.
3. **Decompose + review + present.** Follow `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/plan.md`: write the steps
   (Block 1/2/3, goal contracts), run the silent self-review, dispatch `plan-reviewer` (one shot)
   over the step list, then present and wait for **explicit** approval.

## Done when
An approved step list exists in context. Hand off to `/implement`, or offer `/persist`.
