---
name: shape
description: Shape layer. Fans out candidates only when wave 1's direct-approach candidate fails, or a materially different direction is worth it; picks one, then plans it. Frameless-tolerant. Triggers - "/shape", "/shape <problem>", "brainstorm directions".
---
<!-- shared:skill-rules -->- **Authority:** the human decides at the human gates each skill lists; the driver decides and
  shows everything else.
- **No narration between tools.** One short sentence only when the *task* changes.
- **Questions:** a prose walk in three lines — *found* (what turned up, in user-observable terms),
  *which means* (why there's a choice), *so* (the hand-off) — then `AskUserQuestion`, each option's
  description one clause naming its downstream consequence (never a restatement of the label),
  recommended option first. A pure preference question gets no walk. Skip the introduction for a
  surface the reader already showed they know. The test for any human-facing prose: could the
  reader act on it without opening the code? If not, introduce or translate the term.
- **Harness:** under Codex/pi, read Claude-specific tool mentions per
  `${CLAUDE_PLUGIN_ROOT}/protocols/harness/codex.md` / `pi.md`.
- **Pack:** forward `configPath` to every subagent; each resolves it itself via
  `bash scripts/resolve-pack-value.sh <configPath> <layer>`.
<!-- /shared -->

# /shape — proposal, then plan

Produce **the proposal, then the plan** for the problem. **Framed:** a frame in context supplies
`PROBLEM` as-is; `/shape` never re-narrows it — reopening it re-does work already critiqued.
**Frameless:** run a quick `scout` agent first, then draft an INLINE problem statement from the
task + that scout's evidence — the same five-slot sentence `who` cannot `capability` because
`obstacle`; costs `consequence`; done signal is `observable` — applying the no-mechanism check to
the done signal (every noun and verb in it must already appear in who/capability/obstacle, or
be observable before any change). That scout's output feeds the inline contract and the step budget
anchoring ONLY — it never reaches a `shape-builder`'s brief; every builder reads the codebase
itself, and a shared pre-run evidence base would anchor every branch to the same read.

## Inputs
- `PROBLEM` — the problem statement to fan out on: a frame's, as-is, or the driver's own inline one.
- `TARGET_DIR` — absolute path to explore. Default: current working directory.
- `DIRECTION` — optional; the human's own settled solution direction, carried verbatim. Bound only
  from the human's own words marking it settled — ask when unclear, never inferred. Forwarded to
  the direct approach only; never rewrites a contract slot.

## Operating rules
- **Isolation:** builders never see another builder's output, or the driver's own scout — enforced
  by you, not the builder.

## Procedure
1. **Establish `PROBLEM`.** Frame in context → read its contract as-is. No frame → run the quick
   scout, draft the inline contract. Bind `DIRECTION` when the human has one (ask when unclear).
   Then STATE the step budget — anchored on the discovery in hand (frame's, or the
   frameless quick scout): name what it covers and what it leaves out; the human may change it —
   before any builder call is spent.
2. **Wave 1 — direct approach only.** Dispatch one `shape-builder` with `PREMISE: direct approach`, `COUNT=1`,
   `PROBLEM`, `TARGET_DIR`, step budget, plus `DIRECTION` when bound. Then one `shape-reviewer` over
   it: it leads with `ACCEPT | EXPAND` and one line of reason. `ACCEPT` when the candidate
   is solved (outline steps connect end to end), bounded (fits the step budget, names no-gos), every outline step
   traces to a contract slot, and no trap disqualifies it. `EXPAND` when any of those fails, or
   the reviewer judges the problem admits a materially different direction worth the extra calls.
   `ACCEPT` → skip to step 4. **`EXPAND` with `DIRECTION` bound** — do not enter wave 2 yet; ask
   the human (question shape per Operating rules) to amend `DIRECTION` and re-run wave 1 with it,
   drop `DIRECTION` and expand undirected (step 3), or stop. **`EXPAND` with no `DIRECTION`** →
   step 3.
3. **Wave 2 — full pool, only on an undirected `EXPAND`.** Dispatch three falsifying
   `shape-builder`s (premise = obstacle / capability / costs held false; `who` and done signal
   off limits to them) plus the direct approach re-dispatched fresh at `COUNT=3` — one message, concurrent,
   four calls, each briefed with only its own premise, `PROBLEM`, `TARGET_DIR`, `COUNT`, step budget,
   never a sibling's output or wave 1's own. When the frame carries `## design questions (for /shape)` (one-line
   solution-shaped tradeoffs it left open), brief each falsifying builder with them too — design questions
   inform what a builder explores, they never add a fifth dispatch. Assign each pooled candidate a
   stable ID. One `shape-reviewer` call over the full pool, reusing those IDs, never told wave 1's
   verdict — returns a ranked shortlist of 2-4, each candidate's `traps`, the merge notes, and
   `TIE: yes | no`.
4. **Proposal.** Compose it — never relay `shape-reviewer`'s return value verbatim as the emission.
   Roster first: every ID the shortlist, traps, or merge notes refers to gets one line binding
   it to a short plain-words name plus what it does, before that ID appears anywhere else. Then
   the five fields: problem, step budget, solution, rabbit holes, no-gos — carrying the picked
   skeleton, its precedent, and the rejected candidates with why they lost. The proposal's `step budget`
   field carries the value stated in step 1, verbatim — never re-asked here. `TIE: no`, or
   wave 1's `ACCEPT` — auto-pick, no wait. `TIE: yes` — surface the top two as ONE solution
   open question and wait; that pick belongs to the human alone. Rejecting the proposal ends the run
   here.
5. **Plan.** Settle only what blocks drafting a step boundary; a problem or scope question stays
   `/frame`'s job and is left open, not answered here. Bind the goal statement —
   `<Outcome> for <consumers> because <motivation>; done when <verification>` — from the picked
   candidate's solution field: Outcome an observable end-state, every noun bound; `for` names ≥2
   consumers or a stated concrete value; `because` must not restate the Outcome; `done when` names
   a re-runnable check, manual only with a stated reason. Draft:
   - **Block 1** — the plan goal statement, a before/after table, a step budget note comparing the
     dispatched step budget to the plan's final step count.
   - **Block 2** — one block per step: **Goal** (a step goal statement, traces to the plan goal);
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
   the full step list (each Goal + Interfaces), the problem statement, the proposal's
   no-gos/rabbit holes, and `configPath`. `readiness-reviewer` gets the full step list (each
   step's Goal, Interfaces, Acceptance criteria, Risk) and `configPath`. Both `OK` → present.
   Either `GAPS` → fix what you can; a hole only the human can close → one framing line naming
   what it blocks, then the finding quoted exactly, and wait. Present the plan, then wait for
   **explicit** approval — "approved", "go", "lgtm"; a question or critique is not approval.

## Output
The candidate roster, then the proposal, then — once approved — the plan. Nothing on disk;
persisting either artifact is `/persist`'s job.

## Done when
An approved plan exists in context, or the human rejected the proposal before one was drafted. Hand
off to `/implement`, or offer `/persist`.
