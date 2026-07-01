# Discover

Scout the codebase BEFORE asking the user anything. Feeds the spec (and seeds `/implement`'s
per-step step-builder dispatches when a plan exists).

## Steps
- `/scout <task> [TARGET_DIR] [breadth]` — breadth follows surface: `quick` (local),
  `medium`/`very thorough` (cross-cutting).
- Draft the **goal contract** (`phases/plan.md` § Goal contract) from request + scout:
  `<Outcome> for <consumers> because <motivation>; done when <verification>`. Its **unbound
  slots are your clarification questions** — a slot you can't fill *is* a hole.
- **Bind each unbound slot evidence-first** — scout answers "who calls it", "what's the column
  max"; don't ask what a 30-second `Explore` settles. **Never assume** a preference.
- **Ask as it arises.** When a slot needs a user preference/decision (not a discoverable fact),
  surface it right then via `AskUserQuestion` — one at a time, in the moment, brainstorming-style.
  Don't batch them to the end. A genuine framing choice is a question, never an assumption.
- **Residual → open questions.** Anything the user chooses to leave open, or a tradeoff not yet
  resolvable, becomes a line in the spec's **open questions** section — not a forced decision.

## Brief (one line each)
`Scout` (key file:line landmarks + precedent) · `Goal` (the goal contract) · `Constraints` ·
`Non-goals` · `Assumptions` · `Open questions`.
