---
name: spec
description: Macro layer (L1). Turn a fuzzy task into a spec — restate intent, scout the code, ask open questions as they arise, compose the spec (refined intent + discovery + open questions), present it, and get a cold-eyes critique. Writes nothing to disk. Triggers - "/spec <task>", "spec this", "what's the shape of X". Counterparts - /plan, /implement.
---

# /spec — refine intent, discover, surface the unknowns

Produce a **spec** for `<task>`: the right problem, well-framed, with discovery and the open
questions named. The top of the ceremony gradient — use it when the task is fuzzy. For a task
with a clear goal, the user may skip straight to `/plan`.

The spec lives **in context** (printed, not on disk). Persisting it is the opt-in `/persist`
skill — never automatic.

## Operating rules
- **Authority:** the human owns every decision. You propose; they decide.
- **Stance:** feedback-first — open with a brief take when the human floats an approach.
- **No narration between tools.** One short sentence only when the *task* changes.
- **Conventions:** conform to the project's own style — via the pack's `codeStyleRules` when announced, else the surrounding code; evidence-only (quote file:line).
- **Harness:** under Codex/pi, read Claude-specific tool mentions per `${CLAUDE_PLUGIN_ROOT}/protocols/harness/codex.md` / `pi.md`.
- **Pack forwarding:** forward pack `knowledge` (cross-cutting) and `spec.knowledge` (spec-layer,
  additive) inline prose text — when announced — to `spec-reviewer` alongside the spec.

## Steps
1. **Refine intent.** Restate the goal in one sentence as a goal contract draft
   (`${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/plan.md` § Goal contract). Show the user your read; let them correct it.
   **Direction record in context?** Bind `Outcome` from its `direction` field instead of drafting
   from scratch — the human already picked that direction; bind the other three slots as normal.
2. **Discover.** Follow `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/discover.md`: `/scout` first; bind discoverable slots
   evidence-first; **ask preference/framing questions the moment they arise** (one at a time,
   brainstorming-style), shaped per `${CLAUDE_PLUGIN_ROOT}/protocols/questions.md` — don't defer.
   **Direction record in context?** Its `precedent` entries are already-bound discovery and its
   `risk` is a known constraint — run `/scout` only for surface the record doesn't cover; don't
   re-derive what it already cites.
3. **Compose** the spec = *refined intent + discovery + open questions*. Open questions hold only
   what the user left open or a tradeoff not yet resolvable — most were settled live in step 2.
4. **Self-critique (silent).** Ask: "What am I least confident about right now?" and "What's
   the biggest thing I'm missing about this spec right now? What don't I realize?" Fold the
   answer into discovery or open questions; don't present it as an inline hedge.
5. **Present** the spec in sections scaled to complexity; confirm after each; revise on feedback.
6. **Critique.** Dispatch `spec-reviewer` (one shot) over the composed spec. `HOLES` → surface
   verbatim and fix what you can; a hole only the human can close → wait.

## Done when
A spec is composed, presented, and critiqued. Hand off to `/plan` (it reads the spec from context),
or offer `/persist` if the user wants it on disk.
