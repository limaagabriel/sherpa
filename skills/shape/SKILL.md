---
name: shape
description: Shape layer (L2). Fans out candidates only when wave 1's mainline candidate fails, or a materially different direction is worth it; picks one, then plans it. Frameless-tolerant. Triggers - "/shape", "/shape <problem>", "brainstorm directions".
---

# /shape — pitch, then plan

Produce **the pitch, then the plan** for the problem. **Framed:** a frame in context supplies
`PROBLEM` as-is; `/shape` never re-narrows it — reopening it re-does work already critiqued.
**Frameless:** run a quick `scout` agent first, then draft an INLINE problem contract from the
task + that scout's evidence — the same five-slot sentence `who` cannot `capability` because
`obstacle`; costs `consequence`; solved-signal is `observable` — applying the vocabulary test to
the solved-signal (every noun and verb in it must already appear in who/capability/obstacle, or
be observable before any change). That scout's output feeds the inline contract and the appetite
anchoring ONLY — it never reaches a `shape-builder`'s brief; every builder reads the codebase
itself, and a shared pre-run evidence base would anchor every branch to the same read.

## Inputs
- `PROBLEM` — the problem contract to fan out on: a frame's, as-is, or the driver's own inline one.
- `TARGET_DIR` — absolute path to explore. Default: current working directory.
- `DIRECTION` — optional; the human's own settled solution direction, carried verbatim. Bound only
  from the human's own words marking it settled — ask when unclear, never inferred. Forwarded to
  mainline only; never rewrites a contract slot.

## Operating rules
- **Authority:** the human owns every decision. You propose; they decide.
- **No narration between tools.** One short sentence only when the *task* changes.
- **Questions:** a prose walk in three lines — *found* (what turned up, in user-observable terms),
  *which means* (why there's a choice), *so* (the hand-off) — then `AskUserQuestion`, each option's
  description one clause naming its downstream consequence (never a restatement of the label),
  recommended option first. A pure preference question gets no walk. Skip the introduction for a
  surface the reader already showed they know. The test for any human-facing prose: could the
  reader act on it without opening the code? If not, introduce or translate the term.
- **Pack:** forward `configPath` to every subagent; each resolves it itself via
  `bash scripts/resolve-pack-value.sh <configPath> shape`.
- **Isolation:** builders never see another builder's output, or the driver's own scout — enforced
  by you, not the builder.
- **Harness:** under Codex/pi, read Claude-specific tool mentions per
  `protocols/harness/codex.md` / `pi.md`.

## Procedure
1. **Establish `PROBLEM`.** Frame in context → read its contract as-is. No frame → run the quick
   scout, draft the inline contract. Bind `DIRECTION` when the human has one (ask when unclear).
   Then STATE the appetite — a step budget anchored on the discovery in hand (frame's, or the
   frameless quick scout): name what it covers and what it leaves out; the human may change it —
   before any builder call is spent.
2. **Wave 1 — mainline only.** Dispatch one `shape-builder` with `PREMISE: mainline`, `COUNT=1`,
   `PROBLEM`, `TARGET_DIR`, appetite, plus `DIRECTION` when bound. Then one `shape-reviewer` over
   it: it leads with `WAVE1: ACCEPT | FAN-OUT` and one line of reason. `ACCEPT` when the candidate
   is solved (beats connect end to end), bounded (fits the appetite, names no-gos), every beat
   traces to a contract slot, and no trap disqualifies it. `FAN-OUT` when any of those fails, or
   the reviewer judges the problem admits a materially different direction worth the extra calls.
   `ACCEPT` → skip to step 4. **`FAN-OUT` with `DIRECTION` bound** — do not enter wave 2 yet; ask
   the human (question shape per Operating rules) to amend `DIRECTION` and re-run wave 1 with it,
   drop `DIRECTION` and fan out undirected (step 3), or stop. **`FAN-OUT` with no `DIRECTION`** →
   step 3.
3. **Wave 2 — full pool, only on an undirected `FAN-OUT`.** Dispatch three falsifying
   `shape-builder`s (premise = obstacle / capability / costs held false; `who` and solved-signal
   off limits to them) plus `mainline` re-dispatched fresh at `COUNT=3` — one message, concurrent,
   four calls, each briefed with only its own premise, `PROBLEM`, `TARGET_DIR`, `COUNT`, appetite,
   never a sibling's output or wave 1's own. When the frame carries `## Vantage seeds` (one-line
   solution-shaped tradeoffs it left open), brief each falsifying builder with them too — seeds
   inform what a builder explores, they never add a fifth dispatch. Assign each pooled candidate a
   stable ID. One `shape-reviewer` call over the full pool, reusing those IDs, never told wave 1's
   verdict — returns a ranked shortlist of 2-4, each candidate's `traps`, the collapse record, and
   `CONTESTED: yes | no`.
4. **Pitch.** Compose it — never relay `shape-reviewer`'s return value verbatim as the emission.
   Roster first: every ID the shortlist, traps, or collapse record refers to gets one line binding
   it to a short plain-words name plus what it does, before that ID appears anywhere else. Then
   the five fields: problem, appetite, solution, rabbit holes, no-gos — carrying the picked
   skeleton, its precedent, and the rejected candidates with why they lost. The pitch's `appetite`
   field carries the value stated in step 1, verbatim — never re-asked here. `CONTESTED: no`, or
   wave 1's `ACCEPT` — auto-pick, no wait. `CONTESTED: yes` — surface the top two as ONE solution
   open question and wait; that pick belongs to the human alone. Rejecting the pitch ends the run
   here.
5. **Plan.** Settle only what blocks drafting a step boundary; a problem or scope question stays
   `/frame`'s job and is left open, not answered here. Bind the goal contract —
   `<Outcome> for <consumers> because <motivation>; done when <verification>` — from the picked
   candidate's solution field: Outcome an observable end-state, every noun bound; `for` names ≥2
   consumers or a stated concrete value; `because` must not restate the Outcome; `done when` names
   a re-runnable check, manual only with a stated reason. Draft:
   - **Block 1** — the plan goal contract, a before/after table, an appetite note comparing the
     dispatched appetite to the plan's final step count.
   - **Block 2** — one block per step: **Goal** (a step goal contract, traces to the plan goal);
     **Change** (the concrete delta, this step only); **Interfaces** —
     `consumes: <exact signatures relied on>; produces: <exact names/types later steps rely on>`,
     `none` on either side when it doesn't apply; **Acceptance criteria** —
     `done = <X>, confirmed by <re-runnable check>`, manual only with a stated reason; **Risk** —
     the one real risk that would sink this step, or `none — <why>`.
   - **Block 3** — why this approach (the next-best alternative and why it lost), how it's
     verified (end state + test plan).
   Silent self-review before presenting: placeholder scan, consistency, scope, earns-its-keep,
   premortem (imagine this plan already failed; name the most likely reason, fold it in),
   interface closure (every `consumes` produced by an earlier step, every `produces` has a
   consumer or a stated reason), risk substance (no boilerplate `none`).
6. **Adversarial plan review, then the one approval.** Dispatch `structure-reviewer` and
   `readiness-reviewer` via Agent, in parallel, always. `structure-reviewer` gets the plan goal,
   the full step list (each Goal + Interfaces), the problem contract, the pitch's
   no-gos/rabbit holes, and `configPath`. `readiness-reviewer` gets the full step list (each
   step's Goal, Interfaces, Acceptance criteria, Risk) and `configPath`. Both `SOLID` → present.
   Either `HOLES` → fix what you can; a hole only the human can close → one framing line naming
   what it blocks, then the finding quoted exactly, and wait. Present the plan, then wait for
   **explicit** approval — "approved", "go", "lgtm"; a question or critique is not approval.

## Output
The candidate roster, then the pitch, then — once approved — the plan proposal. Nothing on disk;
persisting either artifact is `/persist`'s job.

## Done when
An approved plan exists in context, or the human rejected the pitch before one was drafted. Hand
off to `/implement`, or offer `/persist`.
