# Discover

Scout the codebase BEFORE asking the user anything. Feeds the frame.

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
- **Residual → open questions or Vantage seeds.** Anything the user chooses to leave open, or a
  tradeoff not yet resolvable, splits per `phases/frame.md` § Vantage test: **problem/scope**
  residue (a genuine ambiguity in who/capability/obstacle/costs/solved-signal, or the task's
  boundary) becomes a line in the frame's **open questions** section — not a forced decision.
  **Solution-shaped** residue (a tradeoff whose answer picks a mechanism, technology, or
  implementation angle) becomes a line in the frame's **Vantage seeds** section instead — it isn't
  resolved here, but it isn't smuggled into open questions either.

## Brief (one line each)
`Scout` (key file:line landmarks + precedent) · `Problem` (the problem contract) · `Constraints` ·
`Non-goals` · `Assumptions` · `Open questions` · `Vantage seeds`.
