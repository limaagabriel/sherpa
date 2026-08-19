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
A STEP BUDGET, not a time budget. Shape Up (Singer 2019): *"a time budget for a standard team size."* Translated
into sherpa's terms: *fixed time, variable scope* becomes **fixed step count, variable scope**. The
human sets it; `shape-reviewer` checks each skeleton against it. Sherpa has no cycles or resource
contention, so time isn't the scarce thing — what's scarce is how much work the human accepts built
before seeing it land.

The driver ASKS the appetite — it never just shows a number. The question is shaped per
`protocols/questions.md`. The options are qualitative levels — `tight`, `balanced`, `comfortable`
— each shown WITH a step count alongside. The level is what the human picks; the count is the
translation, not the unit they reason in.

The counts offered are anchored on the frame's discovery — the surfaces the frame already names,
never invented. `/shape` cannot dispatch `/scout` (`skills/shape/SKILL.md` § Operating rules) and a frame is
always in context (`protocols/layers.md` § A ceremony gradient), so the frame's discovery is the only legitimate
source for the numbers. Discovery anchors the RANGE offered; the human's pick is a budget, not a
prediction — the line that keeps appetite from becoming an estimate.

Each count is DEFENSIBLE, not derived by formula: the driver names which discovered surfaces that
level's budget would cover and which it would leave out. The count is defended by naming its
coverage, not computed by tallying landmarks — a landmark count is not a step count, and a
mechanical tally would ship a rule that is precise and wrong.

Each option's description is one clause naming what that budget buys and cuts — the downstream
consequence, never a restatement of the label (`protocols/questions.md` § The options). No default
appetite: the human always chooses.

> Fail: `tight` / `balanced` / `comfortable` offered with no counts attached — a level label with
> no per-problem anchoring is theater; `tight` must mean something different on a small problem
> than on a large one, or the words carry nothing.

## Vantages
Derived per-run from the frame's problem contract — NO SHIPPED LIST (Sobek 1999). One `shape-builder` per
falsifiable slot, N=3, each holding one premise and returning candidates that hold ONLY IF it's
false:

| Slot | Premise the builder holds false |
|---|---|
| **obstacle** | `<obstacle>` is what actually blocks the capability |
| **capability** | `<capability>` is what the party actually needs |
| **costs** | `<consequence>` is what's actually at stake if unsolved |

Alongside those three sits a fourth, fixed **mainline** dispatch, outside the table above. Where
each falsifying builder holds one slot of the problem contract false, mainline holds every slot
TRUE and generates the candidate that solves the frame's stated obstacle directly — the one
direction the three falsifying builders are barred from returning, precisely because their premise
requires them not to. Mainline is not optional and not itself falsifiable: it does not get a row in
the table above, because a row would claim it holds something false, and it holds everything true.
That is why it is prose here, not a table entry. Total per run: four `shape-builder` dispatches,
always — 3 falsifying + 1 mainline.

`Who` and `solved-signal` are OFF LIMITS for the three falsifying builders — negating either
re-opens L1's bound artifact rather than exploring within it. Mainline holds `who` and
solved-signal true by definition too, so this restriction is moot for it, not violated by it. This
replaces a fixed taxonomy of engineering "concerns" (architecture, ergonomics, ops, cost): a concern
is an EVALUATION axis, so all N builders would describe the SAME candidate scored N ways, and the
critic's collapse record would then merge them back. A premise, unlike a concern, changes what a
candidate CAN BE — not how it's judged.

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
Five fields, per Shape Up: **problem**, **appetite**, **solution**, **rabbit holes**, **no-gos**
— carrying the picked skeleton, its precedent citations, and the rejected candidates with why
they lost. Every candidate ID the shortlist, the
traps, or the collapse record uses is resolved by a roster line before the pitch uses it
(`protocols/prose.md` § The referent rule). The pitch is composed by the driver from
`shape-reviewer`'s return value, never that return value forwarded
as the emission (`protocols/prose.md` § Compose, don't relay). Consumed by `/decompose` at its step
0, where `Outcome` binds. The human picks; the driver NEVER auto-selects — a synthesized direction
nobody approved becomes the premise of everything downstream. Rejecting the whole shortlist is a
valid outcome, not a failure.

The appetite the human set at dispatch (§ Appetite) — never a candidate skeleton's own restatement
of it — is written verbatim into the pitch's `appetite` field: `balanced — N steps.` Each candidate
skeleton also states an appetite (`agents/shape-builder.md` output contract) — what rides in the
pitch's `appetite` field is the dispatched value, never a candidate's echo of it.

## Critique
One `shape-reviewer` dispatch over the pooled candidates, judging ACROSS them: solved, bounded, and
collapse (which candidates are secretly one angle). Its ceiling is resolution: it sees only beats,
so a judgment needing acceptance criteria or interfaces is out of reach — that's
`structure-reviewer`'s, at L3. Both reviewers may look at order; they read it at different
resolutions, and `shape-reviewer`'s stops where exact steps begin — beat adjacency IS coarse
ordering, not an axis it's barred from.

**Isolation invariant** (Nemeth 2001) — builders run concurrently, never seeing each other's output or a
sibling's summary; branches that see each other anchor each other and the fan-out collapses to one
wider thought. **Builder/critic split** — the agent that produced a candidate is never the one
that judges it.

Mainline's candidates are one vantage among four in the pool — the falsifying three plus mainline —
judged exactly like the others: solved, bounded, collapse. Mainline is never a default the human
falls back to just because it exists — `shape-reviewer` must not rank its candidates above a
stronger falsifying candidate merely for being the "safe" choice.

## Don't
- Re-narrow the problem — `/frame`'s job, already critiqued.
- Ship a fixed vantage taxonomy — vantages derive from the frame's slots, per run.
- Let a builder see another builder's output or the pool so far.
- Hand a skeleton acceptance criteria or interfaces — `/decompose`'s to fill, not `/shape`'s.
- Auto-select a candidate, or state the critique ceiling as "must not judge ordering."
- Silently reconcile a candidate's stated appetite with the dispatched value — a deviation is
  a trap the critic names.
