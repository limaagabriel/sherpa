# Frame (macro layer)

Bind the problem before any solution — restate it as a contract, discover, surface open
questions. Driven by `/frame`. Its artifact is **the frame** — problem contract + discovery +
open questions. It binds no `Outcome` — that happens at `/plan` step 0. Binding an end-state
before discovery completes anchors scouting to one direction.

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

## Don't
- Bind an `Outcome` — that's `/plan` step 0's job.
- Name a mechanism — noun or verb — in any slot, including the solved-signal.
- Defer a framing question to the plan layer. If it's about the problem, resolve it here.
