# Discover

Scout the codebase BEFORE asking the user anything. Feeds the frame (and seeds `/implement`'s
per-step step-builder dispatches when a plan exists).

## Steps
- `/scout <task> [TARGET_DIR] [breadth]` — breadth follows surface: `quick` (local),
  `medium`/`very thorough` (cross-cutting).
- **Pitch in context?** Its `solution` field's precedent citations are already-bound discovery and
  its `rabbit holes` are a known constraint — scout only the surface it doesn't cover.
- Draft the **problem contract** (`phases/frame.md` § Problem contract) from request + scout:
  who / capability / obstacle / costs / solved-signal. Its **unbound slots are your
  clarification questions** — a slot you can't fill *is* a hole.
- **Bind each unbound slot evidence-first** — scout answers "who calls it", "what's the column
  max"; don't ask what a 30-second `Explore` settles. **Never assume** a preference.
- **Ask as it arises.** When a slot needs a user preference/decision (not a discoverable fact),
  surface it right then via `AskUserQuestion`, shaped per `protocols/questions.md` — one at a
  time, in the moment, brainstorming-style. Don't batch them to the end. A genuine framing choice
  is a question, never an assumption.
- **Residual → open questions.** Anything the user chooses to leave open, or a tradeoff not yet
  resolvable, becomes a line in the frame's **open questions** section — not a forced decision.

## Brief (one line each)
`Scout` (key file:line landmarks + precedent) · `Problem` (the problem contract) · `Constraints` ·
`Non-goals` · `Assumptions` · `Open questions`.
