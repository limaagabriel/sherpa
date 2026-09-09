---
name: shape
description: Shape layer. Fans out candidates only when wave 1's direct-approach candidate fails one of four named checks (solved, bounded, traced, trap-free); picks one, then plans it. Frameless-tolerant. Triggers - "/shape", "/shape <problem>", "brainstorm directions".
---
<!-- shared:skill-rules -->- **Authority:** the human decides at the human gates each skill lists; the driver decides and
  shows everything else.
- **Narrate only on task changes.** One short sentence when the *task* changes; stay silent between
  tool calls otherwise.
- **Questions:** a prose walk in three lines — *found* (what turned up, in user-observable terms),
  *which means* (why there's a choice), *so* (the hand-off) — then `AskUserQuestion`, each option's
  description one clause naming its downstream consequence (distinct from the label),
  recommended option first. A pure preference question skips the walk. Skip the introduction for a
  surface the reader already showed they know. The test for any human-facing prose: the reader
  must be able to act on it without opening the code — otherwise introduce or translate the term.
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
1. **Establish `PROBLEM`.**
   1. **Frame in context** — read its contract as-is.
   2. **No frame** — run the quick scout, draft the inline contract. Then dispatch
      `frame-reviewer` (one shot) against the just-drafted contract, the verbatim
      task-initiating request, and `configPath` — the same single-pass critique `/frame` runs
      before presenting, since no `/frame` ran here to supply it. `OK` → proceed. `GAPS` the
      driver can close itself (e.g. reword a mechanism-leaking word) → fix and re-check once.
      `GAPS` only the human can close (e.g. a genuine missing question) → one framing line
      naming what it blocks, then the finding quoted exactly, and wait.

   Bind `DIRECTION` when the human has one (ask when unclear). Then STATE the step budget —
   anchored on the discovery in hand (frame's, or the frameless quick scout): name what it covers
   and what it leaves out; the human may change it — before any builder call is spent.
2. **Wave 1 — direct approach only.** Dispatch one `shape-builder` with `PREMISE: direct approach`, `COUNT=1`,
   `PROBLEM`, `TARGET_DIR`, step budget, plus `DIRECTION` when bound. Then one `shape-reviewer` over
   it: it closes with `ACCEPT | EXPAND` and one line of reason, checking exactly these four things:
   1. **Not solved** — a beat or outline step doesn't connect end to end.
   2. **Not bounded** — the candidate doesn't fit the step budget, or states no no-gos.
   3. **Untraced step** — an outline step doesn't trace to any problem-statement slot.
   4. **Disqualifying trap** — a concrete, quotable problem with the candidate (hidden cost, false
      economy, won't scale, premature abstraction, rebuild of working code, or any other named,
      quoted reason).

   `ACCEPT` when none of the four fire. `EXPAND` when any one does. Then, on `EXPAND`:
   1. **`DIRECTION` bound** — do not enter wave 2 yet; ask the human (question shape per Operating
      rules) to amend `DIRECTION` and re-run wave 1 with it, drop `DIRECTION` and expand undirected
      (step 3), or stop.
   2. **No `DIRECTION`** — go to step 3.

   On `ACCEPT`, skip to step 4.
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
   field carries the value stated in step 1, verbatim — never re-asked here. Pick the candidate:
   1. **`TIE: no`, or wave 1's `ACCEPT`** — auto-pick, no wait.
   2. **`TIE: yes`** — surface the top two as ONE solution open question and wait (human gate 1);
      that pick belongs to the human alone.

   An auto-pick here is not final — the proposal is still presented, and remains rejectable, at
   plan approval (human gate 3, step 6).
5. **Plan.** Settle only what blocks drafting a step boundary. A problem or scope question:
   1. **A frame is in context** — stays `/frame`'s job and is left open, not answered here;
      reopening it here would re-narrow a contract already critiqued.
   2. **Frameless** — no `/frame` exists to hand the question to, so `/shape` answers a problem
      question needed for its own problem statement, when nothing else can answer it.

   Bind the goal statement —
   `<Outcome> for <consumers> because <motivation>; done when <verification>` — from the picked
   candidate's solution field: Outcome an observable end-state, every noun bound; `for` names ≥2
   consumers or a stated concrete value; `because` must not restate the Outcome; `done when` names
   a re-runnable check, manual only with a stated reason. Draft:
   - **Block 1** — the plan goal statement, a before/after table, a step budget note comparing the
     dispatched step budget to the plan's final step count.
   - **Block 2** — one block per step: **Goal** (a step goal statement, traces to the plan goal);
     **Change** (the concrete delta, this step only); **Interfaces** —
     `consumes: <path[::literal] — what is relied on>; produces: <path[::literal] — what later
     steps rely on>`. Anchor grammar: `<literal>` must occur verbatim in `<path>` at HEAD
     (checkable with `git grep -F`), OR be created by an earlier step's own `produces` entry (not
     yet at HEAD, but will be by the time this step runs). Multi-file work: list one anchor per
     file (`path1::lit1`, `path2::lit2`, ...), or use a path-only anchor (`path` with no
     `::literal`) when no single literal captures it. No file behind the entry at all (a
     convention, a decision, a design constraint): `none — <prose>`. **Acceptance criteria** —
     `done = <X>, confirmed by <re-runnable check>`, manual only with a stated reason; **Risk** —
     the one real risk that would sink this step, or `none — <why>`.
   - **Block 3** — why this approach (the next-best alternative and why it lost), how it's
     verified (end state + test plan).
   Silent self-review before presenting: placeholder scan, consistency, scope, earns-its-keep,
   premortem (imagine this plan already failed; name the most likely reason, fold it in),
   interface closure (every `consumes` produced by an earlier step, every `produces` has a
   consumer or a stated reason), risk substance (no boilerplate `none`).
6. **Adversarial plan review, then plan approval.** Dispatch `structure-reviewer` and
   `readiness-reviewer` via Agent, in parallel, always. `structure-reviewer` gets the plan goal,
   the full step list (each Goal + Interfaces), the problem statement, the proposal's
   no-gos/rabbit holes, and `configPath`. `readiness-reviewer` gets the full step list (each
   step's Goal, Interfaces, Acceptance criteria, Risk) and `configPath`. Both `OK` → present.
   Either `GAPS` → fix what you can; a hole only the human can close (human gate 2) → one
   framing line naming what it blocks, then the finding quoted exactly, and wait. Present the
   plan (proposal included), then wait for **explicit** approval (human gate 3) — "approved",
   "go", "lgtm"; a question or critique is not approval. Rejecting here ends the run, even when
   the proposal was auto-picked in step 4.

## Human gates
Exactly three points wait on the human; everything else is the driver deciding and showing its
work (see `Authority` above).
1. **Tie pick** (step 4) — `shape-reviewer` returns `TIE: yes`; only the human picks between the
   top two.
2. **Plan-review GAPS only the human can close** (step 6) — a `structure-reviewer` or
   `readiness-reviewer` finding the driver can't fix on its own.
3. **Plan approval** (step 6) — explicit "approved"/"go"/"lgtm"; the proposal stays rejectable
   here even after an earlier auto-pick.

The step budget (step 1) is stated up front, and the human may change it at any point — but that
is not a fourth gate; there's no formal wait on it.

## Output
The candidate roster, then the proposal and plan together, presented once at plan approval. Nothing
on disk; persisting either artifact is `/persist`'s job.

## Done when
An approved plan exists in context, or the human rejected at any human gate before a plan was
approved. Hand off to `/implement`, or offer `/persist`.
