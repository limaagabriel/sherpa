# Discover

Scout the codebase BEFORE asking the user anything. The brief feeds Plan and seeds `/build-and-review` dispatches.

## Steps
- `/scout <task> [TARGET_DIR] [breadth]` — breadth follows surface: `quick` (local), `medium`/`very thorough` (cross-cutting).
- Draft the **goal contract** (`phases/plan.md` § Goal contract) from request + scout: `<Outcome> for <consumers> because <motivation>; done when <verification>`. Its **unbound slots are your clarification questions** — a slot you can't fill *is* a hole.
- **Bind each unbound slot evidence-first** (scout answers "who calls it", "what's the column max" — don't ask what a 30-second `Explore` settles). Escalate to `AskUserQuestion` **only** for a preference/decision, never a discoverable fact. **Never assume** a preference (a slot bound by an unverified assumption — "static names are trusted" — is exactly the failure this gate stops).
- `AskUserQuestion` loop on the unbound preference slots + holes the scout didn't close (ambiguous scope, success criteria, constraints, inputs/outputs, non-goals, untested assumptions, conflicts, edge cases). Drop holes scout already answered.
- One `AskUserQuestion` call holds ≤4 questions — batch *independent* ones, *serialize* dependent ones (an early answer can reshape what follows). Loop until the spec is closed.
- When the *goal itself* has multiple viable framings (not just constraints), that choice is an `AskUserQuestion` decision — surface it; never assume one framing.

## Brief (one line each)
`Scout` (key file:line landmarks + precedent) · `Goal` (the plan goal contract, all four slots bound) · `Constraints` · `Non-goals` · `Assumptions` · `Decisions`.

## Analyze
Find root cause and all affected dependencies before editing. For bugs, rank hypotheses with the minimum evidence to confirm the top one. If diagnosis fails, stop and reassess — don't chain workarounds (no symlinking `node_modules`, copying files, bypassing safeguards). If evidence contradicts an `Assumption`/`Decision` in the brief, or raises a question only the user can answer, return to Discover.
