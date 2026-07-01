---
name: spec
description: Macro layer (L1). Turn a fuzzy task into a spec — restate intent, scout the code, ask open questions as they arise, compose the spec (refined intent + discovery + open questions), present it, and get a cold-eyes critique. Writes nothing to disk. Triggers - "/spec <task>", "spec this", "what's the shape of X". Counterparts - /plan, /implement.
Layer: macro
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
- **Conventions:** guard clauses, SRP, short functions, no inline comments, evidence-only (quote file:line).
- **Harness:** under Codex/pi, read Claude-specific tool mentions per `${CLAUDE_PLUGIN_ROOT}/protocols/harness/codex.md` / `pi.md`.

## Steps
1. **Refine intent.** Restate the goal in one sentence as a goal contract draft
   (`${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/plan.md` § Goal contract). Show the user your read; let them correct it.
2. **Discover.** Follow `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/discover.md`: `/scout` first; bind discoverable slots
   evidence-first; **ask preference/framing questions the moment they arise** (one at a time,
   brainstorming-style) — don't defer.
3. **Compose** the spec = *refined intent + discovery + open questions*. Open questions hold only
   what the user left open or a tradeoff not yet resolvable — most were settled live in step 2.
4. **Present** the spec in sections scaled to complexity; confirm after each; revise on feedback.
5. **Critique.** Dispatch `spec-reviewer` (one shot) over the composed spec. `HOLES` → surface
   verbatim and fix what you can; a hole only the human can close → wait.

## Done when
A spec is composed, presented, and critiqued. Hand off to `/plan` (it reads the spec from context),
or offer `/persist` if the user wants it on disk.
