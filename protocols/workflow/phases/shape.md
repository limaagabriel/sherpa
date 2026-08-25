# Shape (shape layer)

Fan out N candidates from the frame's problem contract, skeleton each to Shape Up's three
properties, critique across the pool, hand the human a pitch to pick from. Driven by `/shape`.
Artifact: **the pitch** — the picked skeleton, precedent, and rejected candidates with why they
lost. Changes nothing on disk.

## Boundaries
When a frame is already in context, `/shape` does not re-narrow the problem — `/frame`'s job, and
reopening it re-does work L1 already critiqued; it reads the frame's problem contract as-is and
moves straight to Vantages.

**Frameless path.** `/shape` no longer hard-requires a frame. The layer discriminator is what's
unbound — problem, solution, or nothing (`protocols/layers.md` § A ceremony gradient) — so a task
whose problem is already clear but whose solution isn't should reach `/shape` directly, with no
`/frame` detour. With no frame in context: run a quick `/scout` first, then draft an INLINE problem
contract from the task + that scout's evidence (`protocols/workflow/phases/frame.md` § Problem
contract), applying its § Vocabulary test to the solved-signal — the same contract format `/frame`
itself uses, so `/shape` is not inventing a second one. This inline contract supplies the vantage
axis Vantages derives from (obstacle / capability / costs);
everywhere else this doc reads "the frame's problem contract," the inline contract stands in for it
when there is no frame. Appetite is asked once this inline contract exists — after the quick scout,
before wave 1's mainline dispatch (§ Appetite).

**Scout-evidence wall.** That quick scout's output feeds the inline contract and the appetite
anchoring ONLY — never any builder's brief. Forwarding it there would hand every `shape-builder` the
same pre-run read of the codebase, the exact anchoring the isolation invariant already bars between
builders (§ Critique — Isolation invariant, Nemeth 2001); the wall extends that same invariant to
the driver's own pre-dispatch evidence, not just to a sibling builder's output.

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

The counts offered are anchored on discovery — the surfaces already named, never invented — from
whichever source produced it: the frame's discovery when a frame is in context, or, on the
frameless path (§ Boundaries), the quick scout run for the inline contract. Either source anchors
the RANGE offered the same way; the human's pick is a budget, not a prediction — the line that keeps
appetite from becoming an estimate.

**Frameless anchor and timing.** On the frameless path the quick scout IS the discovery appetite
anchors on — there is nothing else to anchor on until it runs. The driver asks appetite AFTER that
scout completes and BEFORE wave 1's mainline dispatch: never earlier, when there are no discovered
surfaces yet to name; never later, once a builder call has already been spent with no budget set.
This is the same slot the framed path already uses — frameless just makes explicit what the framed
path gets for free, since the frame's discovery exists before `/shape` even starts.

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
> Fail: appetite asked before the frameless path's quick scout runs — nothing discovered yet means
> nothing to anchor the counts on, and an unanchored range is theater exactly as a missing count is.

## Vantages
Derived per-run from the frame's problem contract — NO SHIPPED LIST (Sobek 1999) — plus the
frame's `## Vantage seeds` (`protocols/workflow/phases/frame.md` § Vantage seeds), when the frame
carries any: one-line solution-shaped tradeoffs frame surfaced but deliberately left unresolved,
because binding them would pick a mechanism rather than state a fact about the problem. Vantage
seeds are read ALONGSIDE the obstacle/capability/costs slots below as additional derivation
material — a fourth SOURCE feeding what each falsifying builder explores, not a fourth falsifying
slot. Four sources of vantage material, still exactly three falsifying builders + one mainline;
seeds inform what a builder explores, they never add a fifth dispatch.

One `shape-builder` per falsifiable slot, N=3, each holding one premise and returning candidates that hold ONLY IF it's
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
That is why it is prose here, not a table entry.

**Two waves, not one flat dispatch of four** (`agents/shape-builder.md` § Inputs — `COUNT`;
`agents/shape-reviewer.md` § Wave model):
- **Wave 1** — `mainline` alone, `COUNT=1`: one direct-solve candidate, checked first against its
  own `reuse-hit`/`mirror-hit` findings, before paying for the other three builders at all. One
  builder call, paid every run.
- **Wave 2** — fired only when wave 1's `shape-reviewer` call renders `EVIDENCE: INSUFFICIENT`
  (§ Critique). `mainline` is RE-DISPATCHED fresh at the default `COUNT=3` — wave 1's `COUNT=1`
  candidate is discarded, never reused as one slot of the wave-2 pool — alongside the three
  falsifying builders, each `COUNT=3`. Four builder calls, concurrent, none seeing another's
  output or wave 1's own (§ Critique — Isolation invariant).

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
  go."* Those spaces are this doc's own § Plan to fill, once a candidate is picked.
  > Fail: "beat 3 — add `validateEmail(input): boolean`, false on missing '@'" — that's an
  > interface plus acceptance criteria; the beat is "validate the email," nothing further.
- **solved** — the beats connect end-to-end. Shape Up: *"All the main elements of the solution are
  there at the macro level and they connect together."*
  > Fail: "beat 4 — persist the result somehow" — "somehow" is an unsolved handoff; the candidate
  > dies here, at L2, not at L3 with commits already landed.
- **bounded** — appetite in steps + explicit no-gos. Shape Up: *"It tells the team where to stop."*
  > Fail: "extend to cover every provider users might eventually want" — no step ceiling, no
  > no-go list; the candidate has no stopping point.

A skeleton detailed enough to build from makes § Plan's own step-authoring dead weight — the failure
**rough** prevents.

## Pitch
Five fields, per Shape Up: **problem**, **appetite**, **solution**, **rabbit holes**, **no-gos**
— carrying the picked skeleton, its precedent citations, and the rejected candidates with why
they lost. Every candidate ID the shortlist, the
traps, or the collapse record uses is resolved by a roster line before the pitch uses it
(`protocols/prose.md` § The referent rule). The pitch is composed by the driver from
`shape-reviewer`'s return value, never that return value forwarded
as the emission (`protocols/prose.md` § Compose, don't relay). Consumed by this doc's own § Plan,
where `Outcome` binds — plan-authoring is no longer a separate `/decompose` layer.

**Auto-pick, unless contested.** `shape-reviewer`'s wave-2 ranked shortlist carries a
`CONTESTED: yes | no` token (§ Critique); the driver's authority to pick the winner hinges on it,
not a blanket "human always picks":
- **`CONTESTED: no`** — the driver plans the winner automatically; the top candidate's margin over
  the rest is not close enough to need arbitration.
- **`CONTESTED: yes`** — the driver does NOT pick. The top-2 candidates surface as ONE solution
  open question in the pitch for the human to decide between — a synthesized direction nobody
  approved must not become the premise of everything downstream.
- Wave 1's `SUFFICIENT` degenerate case (§ Critique) has exactly one candidate and nothing to
  contest against — that candidate goes straight into the pitch as the winner, the same as an
  uncontested wave-2 pick.

Rejecting the pitch outright — the auto-picked winner, or both contested candidates — is always a
valid outcome, not a failure, whichever branch produced it.

The appetite the human set at dispatch (§ Appetite) — never a candidate skeleton's own restatement
of it — is written verbatim into the pitch's `appetite` field: `balanced — N steps.` Each candidate
skeleton also states an appetite (`agents/shape-builder.md` output contract) — what rides in the
pitch's `appetite` field is the dispatched value, never a candidate's echo of it.

The necessity verdict (§ Critique) rides into the pitch by way of the shortlist rationale, exactly
like solved and bounded already do.

## Critique
Up to two `shape-reviewer` dispatches, gated by evidence, not one flat dispatch over every
builder's output every run (`agents/shape-reviewer.md` § Wave model):

- **Wave 1** — one `shape-reviewer` call over the mainline-only pool (§ Vantages' wave 1, one
  builder call at `COUNT=1`). It renders `EVIDENCE: SUFFICIENT | INSUFFICIENT` first, judged
  against that candidate's `reuse-hit`/`mirror-hit` findings alone — the three falsifying builders
  have not run yet. **The SUFFICIENT bar** (`agents/shape-reviewer.md` § Output): the candidate's
  hit must be a `reuse-hit` — not merely a `mirror-hit` — citing a WORKING, already-exercised
  precedent at a specific file:line that actually satisfies a NAMED slot of the problem contract.
  A `mirror-hit` alone is mere resemblance, not a working precedent, and does not clear the bar;
  only a verified `reuse-hit` does. **SUFFICIENT** degrades the output to that one candidate's own
  solved / bounded / necessity judgment: nothing to shortlist, nothing to collapse, because the
  pool is one candidate, not a pool to rank. **INSUFFICIENT** triggers wave 2. Wave 1's cost: 1
  builder call + 1 reviewer call = **2 agent calls**, paid every run.
- **Wave 2** — fired only on a wave-1 `INSUFFICIENT`: the three falsifying builders plus
  `mainline` re-dispatched fresh at `COUNT=3` (§ Vantages) — four builder calls — pooled into one
  `shape-reviewer` call, judging ACROSS them: solved, bounded, necessity, and collapse (which
  candidates are secretly one angle). Necessity: each candidate's beats, as written, serve a named
  slot of the forwarded `PROBLEM`, judged at beat resolution — an untraced beat is a `traps` entry
  (Gotel & Finkelstein 1994). Wave 2's cost: 4 builder calls + 1 reviewer call = **5 agent calls**.

Run totals: wave 1 alone costs 2 agent calls; a run whose evidence is INSUFFICIENT continues into
wave 2 and pays 5 more, for **7 agent calls total** before the plan tail (`structure-reviewer`,
`readiness-reviewer` — separate dispatches, later in the same run, not counted here).

**Anchoring guard** — a wave-2 `shape-reviewer` call is never told wave 1's `EVIDENCE` verdict, nor
which candidate was mainline's original reuse/mirror finding (`agents/shape-reviewer.md` § Wave
model): anchoring the adversarial full-pool pass on the single-candidate pass would defeat the
point of re-dispatching at all.

Its ceiling is resolution: it sees only beats, so a judgment needing acceptance criteria or
interfaces is out of reach — that's `structure-reviewer`'s, at L2. Both reviewers may look at
order; they read it at different resolutions, and `shape-reviewer`'s stops where exact steps begin
— beat adjacency IS coarse ordering, not an axis it's barred from.

**Isolation invariant** (Nemeth 2001) — builders run concurrently, never seeing each other's output
or a sibling's summary; branches that see each other anchor each other and the fan-out collapses to
one wider thought. This covers wave 2's `mainline` re-dispatch too: it is a fresh, blind builder
call that must not see its own wave-1 `reuse-hit`/`mirror-hit` output — a mainline that remembers
what it found last wave is no longer an independent check, it's the same thought twice.
**Builder/critic split** — the agent that produced a candidate is never the one that judges it.

Mainline's candidates are one vantage among four in the wave-2 pool — the falsifying three plus
mainline — judged exactly like the others: solved, bounded, necessity, collapse. Mainline is never
a default the human falls back to just because it exists — `shape-reviewer` must not rank its
candidates above a stronger falsifying candidate merely for being the "safe" choice.

**`CONTESTED: yes | no`** — a NEW token this phase doc now depends on, carried on wave 2's ranked
shortlist (§ Pitch consumes it to decide who picks). `agents/shape-reviewer.md`'s current output
contract has no such field: it has a per-candidate one-line ranking rationale ("why it sits where
it sits relative to the others"), but that explains one candidate's OWN position, not whether the
pool's top two sit close enough to be worth contesting — a driver cannot reliably derive a
yes/no contest verdict by parsing rationale prose. `CONTESTED` needs its OWN explicit field;
`agents/shape-reviewer.md` does not already cover it, and adding it there is a follow-up this doc's
contract now depends on, not yet done.

## Plan
Once a candidate is picked (§ Pitch) — auto-picked, or the human's resolution of a `CONTESTED: yes`
solution open question — this phase's own terminal step turns it into a plan: bind the goal, draft
steps in the format below, run the silent self-review, then submit to adversarial review before
presenting for approval. Rejecting the pitch outright (§ Pitch) ends the run here — there's no plan
to author.

### Bind the goal
`Outcome` binds here, once the candidate is picked, and nowhere earlier. Bind it from the picked
candidate's `solution` field (§ Pitch) — auto-picked (`CONTESTED: no`, or wave 1's `SUFFICIENT`
degenerate case) or the human's pick when `CONTESTED: yes` resolved the solution open question; bind
`for`/`because`/`done when` as normal. Read the appetite already set at dispatch (§ Appetite) — it
is not re-asked here — kept only to compare against the plan's final step count when presenting
(§ Plan proposal format), never forwarded to a reviewer at this layer as judgment material. Bind the
pitch's `no-gos` and `rabbit holes` fields (§ Pitch) as plan constraints — a plan step that does one
of the no-gos, or walks into a named rabbit hole, is a defect `structure-reviewer` attacks
(§ Adversarial plan review); absent (pitch carried none) means no constraint from this source.

### Settle blocking questions
Settle only what blocks drafting a step boundary — a question that stops a step from being
written, not a problem or scope question; those stay `/frame`'s job, unresolved here. A genuine
blocker gets resolved right then: via `AskUserQuestion`, shaped per `protocols/questions.md`, or
an answer already in the conversation. Leave the rest open.

### Plan proposal format
Always carries the three blocks — even a one-line fix gets the full shape.

#### Block 1 — Plan at a glance
- The **plan goal** as a goal contract (§ Goal contract) — the north star every step traces to.
- A **before / after table** — current → target, one row per affected area.
- An **appetite note** — one plain sentence comparing the appetite set at dispatch (§ Appetite) to
  the plan's final step count (e.g. `you picked balanced — 5 steps; this plan has 7`) — descriptive
  only, no judgment.

#### Block 2 — Steps
Each step is its own block. Every step carries:
- **Goal** — a step goal contract (§ Goal contract). Must trace up to the plan goal.
- **Change** — the concrete delta (this step only).
- **Interfaces** — `consumes: <exact signatures this step relies on from earlier steps>; produces:
  <exact names + param/return types later steps rely on>`. `none` on either side when that side
  doesn't apply to this step — a first step's `consumes`, a terminal step's `produces` — and `none`
  for the whole field only when the step is fully self-contained. Each step-builder sees only its
  own step; this is how it learns the names its neighbors use.
- **Example** — the *shape* of what the step produces — a before→after signature/skeleton or sample
  input→output — never a finished implementation: plan-time code is authored before any builder
  reads the target file, and a wrong prescription gets followed rather than corrected.
- **Acceptance criteria** — `done = <X>, confirmed by <re-runnable automated check>`. Manual
  observation only when the step states why no automated check is possible.
- **Blast contract** — `reversibility: one-way-door | revertible; touches: <files/symbols touched
  or silently affected beyond the listed diff>; revert: <exact command or state restore that undoes
  this step>`.
- **Risk** — the one load-bearing risk that would sink this step (mirrors shape-builder.md's
  candidate-risk field); a real risk, or none — <why> when genuinely none.

#### Block 3 — Why & how
- **Why this approach** — the next-best alternative and why it lost (bugs: confirming evidence).
- **How it's verified** — observable end state + test plan.

### Goal contract
Every goal — the one **plan goal** and each **step goal** — is one sentence, four bound slots (Doran 1981):

> **`<Outcome>` for `<consumers>` because `<motivation>`; done when `<verification>`.**

| Slot | Rule |
|---|---|
| **Outcome** | An observable end-**state**, every noun bound. Not an action; not a vague reference. |
| **For** | Who consumes it. Every new abstraction names **≥2 consumers or a stated concrete value**. |
| **Because** | The parent intent served. Must not restate the Outcome. |
| **done when** | `confirmed by <re-runnable automated check>`; manual only with a stated reason. |

### Self-review (silent, before presenting)
1. **Placeholder scan** — any TBD/vague requirement or unbound noun-phrase? Bind it.
2. **Consistency** — do steps contradict, and do they sum to the after-state?
3. **Scope** — one plan's worth?
4. **Earns-its-keep** — every abstraction's `For` names ≥2 consumers/a value; every `Because`
   says what breaks if absent. Fails either → cut or justify.
5. **Premortem** (Klein 2007) — imagine this plan already failed; name the most likely
   reason. Fold the answer in, or carry it forward as an open question — don't just note it and move on.
6. **Interface closure** — every step's `Interfaces` consumes entry is produced by an earlier
   step; every produces entry has a consumer or a stated reason. A mismatch here is cheaper to
   fix now than at the consuming step.
7. **Risk substance** — does every step's Risk name a real, specific risk, or is `none`
   justified by a stated reason? A boilerplate `none` with no reason is a hole to fix.

### Adversarial plan review
After the silent self-review, before presenting, always dispatch both `structure-reviewer` and
`readiness-reviewer` via Agent, in parallel — no conditional gate on plan size or reversibility.
Shape's own appetite step budget (§ Appetite) already bounds scale before a step is ever drafted, so
the scale-conditional readiness-reviewer gate a standalone `/decompose` once used here is redundant
and dropped: both reviewers run on every plan this layer produces, not only the ones that cross a
size or risk threshold.

Forward `structure-reviewer` the inputs it takes: the plan goal + the full step list (each goal in
contract form, each step's `Interfaces`) + the frame path for context, or the inline problem
contract (§ Boundaries) when no frame existed, the pitch's `no-gos`/`rabbit holes` when carried
(§ Bind the goal; absent means none), and `configPath` when announced. `structure-reviewer` resolves
its own `knowledge`/`decompose.knowledge` and `decompose.architecture` via resolve-pack-value.sh, per
its own agent doc. Appetite is never forwarded to `structure-reviewer` — it never gated anything
there. No *additional* necessity or scope check is added at this layer beyond what already runs
here — the silent self-review's scope/earns-its-keep items and `structure-reviewer`'s own
traceability attack — plus the human's own read of the plan before approving it. Forward
`readiness-reviewer` the full step list, with each step's Goal, Interfaces, Acceptance criteria,
Blast contract, and Risk field, plus `configPath` when announced. `readiness-reviewer` resolves its
own `knowledge`/`decompose.knowledge` via resolve-pack-value.sh, per its own agent doc — but does not
resolve `architecture`; that's cross-step context `structure-reviewer` alone consumes, and
`readiness-reviewer`'s own Input contract has no `architecture` input.

`structure-reviewer` attacks traceability, missing foundation, gaps, overlap, ordering (Wake 2003;
Reinertsen 2009), hidden coupling, interface-mismatch; `readiness-reviewer` attacks contract
completeness, over-prescription, goal-contract honesty, single-responsibility, responsibility leak,
risk-field substance, and blast-contract accuracy. Each returns `SOLID | HOLES`. Handle: both
`SOLID` → present. Either returns `HOLES` → fix what you can; a hole only the human can close → name
what it blocks, in the reader's terms, then surface verbatim (`protocols/prose.md` § Verbatim is a
quote, not a frame) and wait. These are the independent eyes your own self-review can't be — always
both, never one alone.

### Approval
Wait for **explicit** approval before any `/implement` action — "approved", "go", "ship it", "lgtm".
A question, critique, or your own answer is **not** approval. When in doubt, you are not approved.

## Don't
- Re-narrow the problem — `/frame`'s job, already critiqued.
- Ship a fixed vantage taxonomy — vantages derive from the frame's slots, per run.
- Let a builder see another builder's output or the pool so far.
- Hand a skeleton acceptance criteria or interfaces before a candidate is picked — § Plan fills
  those in, once picked, not the fan-out stage.
- Auto-select a candidate when the shortlist is `CONTESTED: yes` — that pick belongs to the human
  alone; auto-pick only fires on `CONTESTED: no` (§ Pitch). Or state the critique ceiling as "must
  not judge ordering."
- Silently reconcile a candidate's stated appetite with the dispatched value — a deviation is
  a trap the critic names.
- Forward the appetite to `structure-reviewer`, or treat it as a ceiling on the step list — it is a
  plain step-count comparison at presentation time (§ Plan proposal format), nothing more.
- Skip approval, even for small fixes.
- Re-refine intent beyond § Plan's own bind, or surface open questions — that's `/frame`'s job.
- Reference a file before verifying it exists.
- Present a plan without the silent self-review and both `structure-reviewer`'s and
  `readiness-reviewer`'s passes — both always run, no scale gate.
