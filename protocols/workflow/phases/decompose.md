# Decompose (step layer, L3)

Decompose the goal into steps, present them, wait for approval. Driven by `/decompose`.
Input is the frame (in context) — or, standalone, a `<task>` + a light `/scout`.

## Step 0 — bind the goal
`Outcome` binds here, at step 0, and nowhere earlier. **Frame in context** → bind `Outcome` from
its problem contract's solved-signal (what `Outcome` must achieve); bind `for`/`because`/`done
when` as normal. **Pitch in context** → its `solution` field (`phases/shape.md` § Pitch) is a
proposed `Outcome`; bind from it. Also read the appetite from the pitch's `appetite` field
(`phases/shape.md` § Pitch); absent means none — engine defaults only. Also bind the pitch's
`no-gos` and `rabbit holes` fields (`phases/shape.md` § Pitch) as decomposition constraints — a
plan step that does one of the no-gos, or walks into a named rabbit hole, is a defect
structure-reviewer attacks (§ Adversarial decomposition review); absent (no pitch, or pitch
carried none) means no constraint from this source. **No frame** → run a quick `/scout`, then
draft a problem contract inline from request + scout evidence (`phases/frame.md` § Problem
contract), apply its §
Vocabulary test, then bind `Outcome` from it — the standalone path; don't skip the contract just
because `/frame` was skipped.

## Before decomposing
- **Settle only what blocks a step.** If the frame left open questions, resolve the ones that
  actually block a step boundary — ask via `AskUserQuestion`, shaped per `protocols/questions.md`,
  or use answers already in the conversation. Questions that don't block decomposition ride into
  `/implement`, asked by its driver before that step's dispatch; don't force them here.
- **Standalone (no frame):** decompose — step 0 already scouted and drafted the problem contract
  when none existed. Don't write an open-questions section — still `/frame`'s job.

## Plan proposal format
Always carries the three blocks — even a one-line fix gets the full shape.

### Block 1 — Plan at a glance
- The **plan goal** as a goal contract (§ Goal contract) — the north star every step traces to.
- A **before / after table** — current → target, one row per affected area.

### Block 2 — Steps
Each step is its own block. Every step carries:
- **Goal** — a step goal contract (§ Goal contract). Must trace up to the plan goal.
- **Change** — the concrete delta (this step only).
- **Interfaces** — `consumes: <exact signatures this step relies on from earlier steps>; produces:
  <exact names + param/return types later steps rely on>`. `none` on either side when that side
  doesn't apply to this step — a first step's `consumes`, a terminal step's `produces` — and `none`
  for the whole field only when the step is fully self-contained. Each step-builder sees only its
  own step; this is how it learns the names its neighbors use.
- **Example** — the *shape* of what the step produces — a before→after signature/skeleton or
  sample input→output — never a finished implementation: plan-time code is authored before any
  builder reads the target file, and a wrong prescription gets followed rather than corrected.
- **Acceptance criteria** — `done = <X>, confirmed by <re-runnable automated check>`. Manual
  observation only when the step states why no automated check is possible.
- **Blast contract** — `reversibility: one-way-door | revertible; touches: <files/symbols touched
  or silently affected beyond the listed diff>; revert: <exact command or state restore that undoes
  this step>`.
- **Risk** — the one load-bearing risk that would sink this step (mirrors shape-builder.md's
  candidate-risk field); a real risk, or none — <why> when genuinely none.

### Block 3 — Why & how
- **Why this approach** — the next-best alternative and why it lost (bugs: confirming evidence).
- **How it's verified** — observable end state + test plan.

## Goal contract
Every goal — the one **plan goal** and each **step goal** — is one sentence, four bound slots:

> **`<Outcome>` for `<consumers>` because `<motivation>`; done when `<verification>`.**

| Slot | Rule |
|---|---|
| **Outcome** | An observable end-**state**, every noun bound. Not an action; not a vague reference. |
| **For** | Who consumes it. Every new abstraction names **≥2 consumers or a stated concrete value**. |
| **Because** | The parent intent served. Must not restate the Outcome. |
| **done when** | `confirmed by <re-runnable automated check>`; manual only with a stated reason. |

## Self-review (silent, before presenting)
1. **Placeholder scan** — any TBD/vague requirement or unbound noun-phrase? Bind it.
2. **Consistency** — do steps contradict, and do they sum to the after-state?
3. **Scope** — one plan's worth?
4. **Earns-its-keep** — every abstraction's `For` names ≥2 consumers/a value; every `Because`
   says what breaks if absent. Fails either → cut or justify.
5. **Self-critique** — ask: "What am I least confident about right now?" and "What's the
   biggest thing I'm missing about this decomposition right now? What don't I realize?" Fold
   the answer in, or carry it forward as an open question — don't just note it and move on.
6. **Interface closure** — every step's `Interfaces` consumes entry is produced by an earlier
   step; every produces entry has a consumer or a stated reason. A mismatch here is cheaper to
   fix now than at the consuming step.
7. **Risk substance** — does every step's Risk name a real, specific risk, or is `none`
   justified by a stated reason? A boilerplate `none` with no reason is a hole to fix.

## Adversarial decomposition review (structure-reviewer always; readiness-reviewer when scaled)
After the silent self-review, before presenting, always dispatch `structure-reviewer` via Agent.
Also dispatch `readiness-reviewer`, in parallel with `structure-reviewer`, when the plan exceeds 3
steps OR any step's Blast contract declares `one-way-door` reversibility — readiness-reviewer's
per-step contract-completeness checks earn their cost on plans big enough to hide a bad step
contract, or steps risky enough that a contract gap is expensive to discover late. A plan of 3
steps or fewer, all revertible, skips it — structure-reviewer alone is proportionate.

Forward `structure-reviewer` the same inputs it always took: the plan goal + the full step list
(each goal in contract form, each step's `Interfaces`) + the frame path for context, or the problem
contract drafted at step 0 when no frame existed, the appetite when the pitch carried one (§ Step 0
reads it from the pitch's `appetite` field; absent means none), the pitch's `no-gos`/`rabbit holes`
when carried (§ Step 0; absent means none), pack `knowledge`/`decompose.knowledge`, and the
`decompose.architectureRules` command output when announced. When dispatched, forward
`readiness-reviewer`
the full step list, with each step's Goal, Interfaces, Acceptance criteria, Blast contract, and
Risk field, plus pack `knowledge`/`decompose.knowledge` — but not `architectureRules`; that's
cross-step context `structure-reviewer` alone consumes, and `readiness-reviewer`'s own Input
contract has no `architectureRules` input.

`structure-reviewer` attacks traceability, missing foundation, gaps, overlap, ordering, hidden
coupling, interface-mismatch; `readiness-reviewer`, when dispatched, attacks contract completeness,
over-prescription, goal-contract honesty, single-responsibility, responsibility leak, risk-field
substance, and blast-contract accuracy. Each returns `SOLID | HOLES`. Handle:
All dispatched reviewers `SOLID` → present. Any returns `HOLES` → fix what you can; a hole only the
human can close → name what it blocks, in the reader's terms, then surface verbatim
(`protocols/prose.md` § Verbatim is a quote, not a frame) and wait. These are the independent eyes
your own self-review can't be. When readiness-reviewer is not dispatched (plan below the gate), its
absence is not itself a hole — structure-reviewer `SOLID` alone is sufficient to present.

## Approval
Wait for **explicit** approval before any `/implement` action — "approved", "go", "ship it", "lgtm".
A question, critique, or your own answer is **not** approval. When in doubt, you are not approved.

## Don't
- Treat the appetite as a ceiling on the exact step list — at this layer it is advisory
  context for judging whether the plan is strong relative to what the human said the work was
  worth.
- Skip approval, even for small fixes.
- Re-refine intent beyond step 0's binding, or surface open questions (that's `/frame`'s job).
- Reference a file before verifying it exists.
- Present without the silent self-review and structure-reviewer's pass — plus readiness-reviewer's,
  when the plan's scale required dispatching it.
