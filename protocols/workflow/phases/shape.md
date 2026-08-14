# Shape (shape layer)

Fan out N candidates from the frame's problem contract, skeleton each to Shape Up's three
properties, critique across the pool, hand the human a pitch to pick from. Driven by `/shape`.
Artifact: **the pitch** — the picked skeleton, precedent, and rejected candidates with why they
lost. Changes nothing on disk.

## Boundaries
`/shape` does not re-narrow the problem — `/frame`'s job, and reopening it re-does work L1 already
critiqued. `/shape` requires a frame in context: with none it has no vantage axis at all (see
Vantages), so the driver offers `/frame` in one declinable line rather than guessing a contract.
`protocols/layers.md` records `/shape` as the one layer that requires its upstream artifact.

## Appetite
A STEP BUDGET, not a time budget. Shape Up: *"a time budget for a standard team size."* Translated
into sherpa's terms: *fixed time, variable scope* becomes **fixed step count, variable scope**. The
human sets it; `shape-reviewer` checks each skeleton against it. Sherpa has no cycles or resource
contention, so time isn't the scarce thing — what's scarce is how much work the human accepts built
before seeing it land.

## Vantages
Derived per-run from the frame's problem contract — NO SHIPPED LIST. One `shape-builder` per
falsifiable slot, N=3, each holding one premise and returning candidates that hold ONLY IF it's
false:

| Slot | Premise the builder holds false |
|---|---|
| **obstacle** | `<obstacle>` is what actually blocks the capability |
| **capability** | `<capability>` is what the party actually needs |
| **costs** | `<consequence>` is what's actually at stake if unsolved |

`Who` and `solved-signal` are OFF LIMITS — negating either re-opens L1's bound artifact rather than
exploring within it. This replaces a fixed taxonomy of engineering "concerns" (architecture,
ergonomics, ops, cost): a concern is an EVALUATION axis, so all N builders would describe the SAME
candidate scored N ways, and the critic's collapse record would then merge them back. A premise,
unlike a concern, changes what a candidate CAN BE — not how it's judged.

## Skeleton
Every candidate carries one, bound to Shape Up part 1's three properties:

- **rough** — 3-6 beats, NO acceptance criteria, NO interfaces. Shape Up: *"Everyone can tell by
  looking at it that it's unfinished. They can see the open spaces where their contributions will
  go."* Those spaces are `/decompose`'s to fill.
  > Fail: "beat 3 — add `validateEmail(input): boolean`, false on missing '@'" — that's an
  > interface plus acceptance criteria; the beat is "validate the email," nothing further.
- **solved** — the beats connect end-to-end. Shape Up: *"All the main elements of the solution are
  there at the macro level and they connect together."*
  > Fail: "beat 4 — persist the result somehow" — "somehow" is an unsolved handoff; the candidate
  > dies here, at L2, not at L4 with commits already landed.
- **bounded** — appetite in steps + explicit no-gos. Shape Up: *"It tells the team where to stop."*
  > Fail: "extend to cover every provider users might eventually want" — no step ceiling, no
  > no-go list; the candidate has no stopping point.

A skeleton detailed enough to build from makes `/decompose` dead weight — the failure **rough** prevents.

## Pitch
Five fields, per Shape Up: **problem**, **constraints**,
**solution**, **rabbit holes**, **limitations** — carrying the picked skeleton, its precedent
citations, and the rejected candidates with why they lost. Every candidate ID the shortlist, the
traps, or the collapse record uses is resolved by a roster line before the pitch uses it
(`protocols/prose.md` § The referent rule). The pitch is composed by the driver from
`shape-reviewer`'s return value, never that return value forwarded
as the emission (`protocols/prose.md` § Compose, don't relay). Consumed by `/decompose` at its step
0, where `Outcome` binds. The human picks; the driver NEVER auto-selects — a synthesized direction
nobody approved becomes the premise of everything downstream. Rejecting the whole shortlist is a
valid outcome, not a failure.

## Critique
One `shape-reviewer` dispatch over the pooled candidates, judging ACROSS them: solved, bounded, and
collapse (which candidates are secretly one angle). Its ceiling is resolution: it sees only beats,
so a judgment needing acceptance criteria or interfaces is out of reach — that's
`decompose-reviewer`'s, at L3. Both reviewers may look at order; they read it at different
resolutions, and `shape-reviewer`'s stops where exact steps begin — beat adjacency IS coarse
ordering, not an axis it's barred from.

**Isolation invariant** — builders run concurrently, never seeing each other's output or a
sibling's summary; branches that see each other anchor each other and the fan-out collapses to one
wider thought. **Builder/critic split** — the agent that produced a candidate is never the one
that judges it.

## Don't
- Re-narrow the problem — `/frame`'s job, already critiqued.
- Ship a fixed vantage taxonomy — vantages derive from the frame's slots, per run.
- Let a builder see another builder's output or the pool so far.
- Hand a skeleton acceptance criteria or interfaces — `/decompose`'s to fill, not `/shape`'s.
- Auto-select a candidate, or state the critique ceiling as "must not judge ordering."
