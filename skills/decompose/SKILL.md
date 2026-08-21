---
name: decompose
description: Step layer (L3). Binds `Outcome` at step 0, decomposes into ordered steps, gets a cold-eyes critique before any code. Reads the frame if present. Writes nothing to disk. Triggers - "/decompose", "/decompose <task>", "decompose this", "break it into steps". Counterparts - /frame, /shape, /implement.
---

# /decompose — order the steps, then pressure-test before code

Produce **the plan** (the step list) for the goal: ordered, traceable steps, critiqued before any
code. `/decompose` is L3 in the four-layer spine, running AFTER `/shape` (or directly after
`/frame`, or standalone on a task with one clear direction); it owns the plan, consumed by
`/implement` one step at a time. Skip it for a one-obvious-change task — go straight to
`/implement`.

The plan lives **in context** (printed, not on disk). Persisting is the opt-in `/persist` skill.

## Operating rules
- **Authority:** the human owns every decision. You propose; they decide.
- **Stance:** feedback-first — open with a brief take when the human floats an approach.
- **No narration between tools.** One short sentence only when the *task* changes.
- **Conventions:** conform to the project's own style — the surrounding code; evidence-only (quote file:line). The pack's `codeStyleRules` (when present) is resolved by the subagent via resolve-pack-value.sh.
- **Harness:** under Codex/pi, read Claude-specific tool mentions per `${CLAUDE_PLUGIN_ROOT}/protocols/harness/codex.md` / `pi.md`.
- **Pack forwarding:** when a `configPath` is announced, forward it to both `structure-reviewer` and `readiness-reviewer` alongside the step list. Both subagents resolve their own `knowledge` (cross-cutting) and `decompose.knowledge` (decompose-layer, additive) via resolve-pack-value.sh. Additionally, `structure-reviewer` resolves `decompose.architectureRules` via resolve-pack-value.sh (architecture constraints live in its agent doc key-list); `readiness-reviewer`'s key-list excludes architectureRules, as that cross-step concern is outside its job.

## Steps
0. **Bind the goal — `/decompose`'s step 0, the sole `Outcome` bind site.**
   Follow `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/decompose.md` § Step 0 exactly — it's
   the sole `Outcome` bind site (frame / pitch / no-frame branches).
1. **Get context.** Frame in context → use it as the goal + discovery. **No frame** → treat the
   `<task>` arg as the goal (step 0 already scouted it); don't write an open-questions section
   (that's `/frame`'s job). Offer `/frame` or `/shape` when the ceremony gradient calls for one
   (`${CLAUDE_PLUGIN_ROOT}/protocols/layers.md` § A ceremony gradient) — one declinable line, never
   forced. **A persisted frame, pitch, or plan file path given as the arg** — read it back and
   consume it exactly as an in-context artifact.
2. **Settle what blocks a step.** Resolve any open questions that block a step boundary —
   `AskUserQuestion` (shaped per `${CLAUDE_PLUGIN_ROOT}/protocols/questions.md`), or answers
   already in the conversation. Leave the rest open.
3. **Decompose + review + present.** Follow
   `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/decompose.md`: write the steps (Block 1/2/3,
   goal contracts), run the silent self-review, dispatch the adversarial decomposition review per
   `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/decompose.md` § Adversarial decomposition
   review (structure-reviewer always; readiness-reviewer when the plan's scale calls for it), then
   present and wait for **explicit** approval.

## Done when
An approved step list exists in context. Hand off to `/implement`, or offer `/persist`.
