# Plan (step layer)

Decompose the goal into steps, present them, wait for approval. Driven by `/plan`.
Input is the spec (in context) — or, standalone, a `<task>` + a light `/scout`.

## Before decomposing
- **Settle only what blocks a step.** If the spec left open questions, resolve the ones that
  actually block a step boundary — ask via `AskUserQuestion`, or use answers already in the
  conversation. Questions that don't block decomposition ride into `/implement` as builder-time
  calls; don't force them here.
- **Standalone (no spec):** quick `/scout`, then decompose. Do NOT refine intent or write an
  open-questions section — that is `/spec`'s job; if it was skipped, you're working without it.

## Plan proposal format
Always carries the three blocks — even a one-line fix gets the full shape.

### Block 1 — Plan at a glance
- The **plan goal** as a goal contract (§ Goal contract) — the north star every step traces to.
- A **before / after table** — current → target, one row per affected area.

### Block 2 — Steps
Each step is its own block. Every step carries:
- **Goal** — a step goal contract (§ Goal contract). Must trace up to the plan goal.
- **Change** — the concrete delta (this step only).
- **Example** — a small before→after snippet or sample input→output of what the step produces.
- **Acceptance criteria** — `done = <X>, confirmed by <re-runnable automated check>`. Manual
  observation only when the step states why no automated check is possible.

### Block 3 — Why & how
- **Why this approach** — the next-best alternative and why it lost (bugs: confirming evidence).
- **How it's verified** — observable end state + test plan.

## Goal contract
Every goal — the one **plan goal** and each **step goal** — is one sentence, four bound slots:

> **`<Outcome>` for `<consumers>` because `<motivation>`; done when `<verification>`.**

| Slot | Rule |
|---|---|
| **Outcome** | An observable end-**state**, every noun bound. Not an action; not a vague reference. |
| **For** | Who consumes it. Every new abstraction names **≥2 consumers or a stated concrete value**. |
| **Because** | The parent intent served. Must not restate the Outcome. |
| **done when** | `confirmed by <re-runnable automated check>`; manual only with a stated reason. |

## Self-review (silent, before presenting)
1. **Placeholder scan** — any TBD/vague requirement or unbound noun-phrase? Bind it.
2. **Consistency** — do steps contradict, and do they sum to the after-state?
3. **Scope** — one plan's worth?
4. **Earns-its-keep** — every abstraction's `For` names ≥2 consumers/a value; every `Because`
   says what breaks if absent. Fails either → cut or justify.

## Adversarial decomposition review (plan-reviewer)
After the silent self-review, before presenting, dispatch `plan-reviewer` via Agent. Forward the
plan goal + the full step list (each goal in contract form) + the spec path for context. It attacks
traceability, missing foundation, gaps, overlap, ordering and returns `SOLID | HOLES`. Handle:
`SOLID` → present. `HOLES` → fix what you can; a hole only the human can close → surface verbatim
and wait. This is the independent eyes your own self-review can't be.

## Approval
Wait for **explicit** approval before any `/implement` action — "approved", "go", "ship it", "lgtm".
A question, critique, or your own answer is **not** approval. When in doubt, you are not approved.

## Don't
- Skip approval, even for small fixes.
- Re-refine intent or surface open questions (that's `/spec`).
- Reference a file before verifying it exists.
- Present without the silent self-review and the plan-reviewer pass.
