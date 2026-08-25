# Frame (macro layer)

Bind the problem before any solution (Pólya 1945) — restate it as a contract, discover, surface open
questions. Driven by `/frame`. Its artifact is **the frame** — problem contract + discovery +
open questions. It binds no `Outcome` — that happens once `/shape` plans the picked candidate
(`protocols/workflow/phases/shape.md` § Plan). Binding an end-state before discovery completes
anchors scouting to one direction.

## Problem contract
One sentence, five bound slots:

> **`<who>` cannot `<capability>` because `<obstacle>`; costs `<consequence>`; solved-signal is
> `<observable>`.**

| Slot | Rule |
|---|---|
| **Who** | The concrete affected party. At least one named consumer, never a generic "the user". |
| **Capability** | What the party is trying to do and can't. Stated as their goal, never as the feature that would grant it. |
| **Obstacle** | What actually blocks it, in the system's present-tense behavior. The root cause, not the absence of a fix. |
| **Costs** | What breaks or is wasted if unsolved. Must not restate the obstacle. |
| **Solved-signal** | What an observer would see flip. Never the mechanism producing it. |

## Vocabulary test
`frame-reviewer` applies this to the solved-signal: every noun AND verb in it must already appear
in Who / Capability / Obstacle, or be observable before any change is made. A noun that only
exists once a particular solution is built is **mechanism leakage** — rewrite the slot. A verb
naming HOW the change happens (self-heals, auto-retries, caches, migrates) is leakage exactly as a
noun is — it bakes in one mechanism over equally valid alternatives.

> Fail: "no tracked file references the old skill name" — "old skill name" presumes the rename;
> it exists only if one particular solution is built.
> Fail: "deploy failures self-heal without on-call intervention" — "self-heal" names a mechanism
> (auto-remediation), not an observable outcome; faster diagnosis or better logging solve the same
> contract without it.
> Pass: "a macro-layer run produces discovery that still supports more than one direction" —
> every noun (macro-layer run, discovery, direction) is observable today.

## Vantage test
Frame owns the problem only (`protocols/layers.md` — "in frame the problem is unbound"); every
open question must earn its place by being about the problem, not a rehearsal of the solution.
Classify each candidate open question:
- **Problem/scope** — a genuine ambiguity in who / capability / obstacle / costs / solved-signal,
  or the task's boundary. Stays in the frame's normal **open questions** section.
- **Solution-shaped** — a tradeoff whose answer picks a mechanism, a technology, or an
  implementation angle. Does NOT belong in open questions; becomes one line in a new
  **## Vantage seeds** section instead, for `/shape` to pick up when it derives candidate
  directions.

> Problem/scope: "which system is the source of truth for X?" — the answer fills a slot
> (obstacle/costs) about the problem itself; it stays an open question.
> Solution-shaped: "should X be cached or recomputed?" — the answer picks a mechanism, not a fact
> about the problem; it routes to Vantage seeds instead.

## Vantage seeds
A section of one-line solution-shaped tradeoffs surfaced while framing but deliberately left
unresolved (§ Vantage test) — resolving them would bind a solution, which is `/shape`'s job, not
frame's. `/shape`'s vantage derivation reads these first when generating candidate directions.

## Don't
- Bind an `Outcome` — that's `/shape`'s § Plan job, once a candidate is picked
  (`protocols/workflow/phases/shape.md` § Plan).
- Name a mechanism — noun or verb — in any slot, including the solved-signal.
- Defer a framing question to `/shape`. If it's about the problem, resolve it here.
- Put a solution-shaped question in open questions — route it to Vantage seeds instead (§ Vantage
  test).
