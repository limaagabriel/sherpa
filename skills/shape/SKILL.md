---
name: shape
description: Shape layer. Drafts one plan directly from the problem, then reviews it three ways (structure, readiness, engineering) before the human approves. Frameless-tolerant. Triggers - "/shape", "/shape <problem>", "brainstorm directions".
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
  `bash scripts/pack/load-layer.sh <configPath> <layer>`. `configPath=none` counts as announced —
  forward it verbatim.
<!-- /shared -->
<!-- shared:unattended -->Args start with `--unattended` → read `${CLAUDE_PLUGIN_ROOT}/protocols/unattended.md` first; it overrides every ask/wait in this skill.
<!-- /shared -->

# /shape — the plan

Produce **the plan** for the problem. **Framed:** a frame in context supplies `PROBLEM` as-is;
`/shape` never re-narrows it — reopening it re-does work already critiqued. **Frameless:** run a
quick `codebase-explorer` agent first, then draft an INLINE problem statement from the task + that
codebase-explorer's evidence — the same five-slot sentence `who` cannot `capability` because
`obstacle`; costs `consequence`; done signal is `observable` — applying the no-mechanism check to
the done signal (every noun and verb in it must already appear in who/capability/obstacle, or
be observable before any change). That codebase-explorer's output feeds the inline contract, the
step budget anchoring, and then the plan draft itself — the driver drafts the plan directly from
that discovery, the same way `/frame`'s own "Draft the problem statement" step drafts the inline
contract directly from `codebase-explorer`'s discovery: no dedicated builder subagent in between.

## Inputs
- `PROBLEM` — the problem statement to draft the plan from: a frame's, as-is, or the driver's own
  inline one.
- `TARGET_DIR` — absolute path to explore. Default: current working directory.
- `DIRECTION` — optional; the human's own settled solution direction, carried verbatim. Bound only
  from the human's own words marking it settled — ask when unclear, never inferred. Forwarded to
  the plan draft; never rewrites a contract slot.
- `REVISIT` — optional; the framing line, the finding quoted exactly, and the stopped step's Goal
  that an `/implement` run emitted when it stopped, carried verbatim. Forwarded to the plan draft
  and to `structure-reviewer` as a trap to avoid, never as direction; never rewrites a contract
  slot.

## design questions (for /shape)
When the frame carries `## design questions (for /shape)` (one-line solution-shaped tradeoffs it
left open): for each one, the driver — while drafting the plan (step 2) — picks a resolution and
records that resolution plus a one-line why in the plan's Block 3, alongside the precedent/
rationale that also lands there. No frame, or a frame that carries none: no-op.

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

   **Re-verify `REVISIT`** when bound. Check each `file:line` or `path::literal` the finding cites
   against HEAD — `git cat-file -e HEAD:<path>`, and `git grep -q -F -e "<literal>" HEAD -- "<path>"`
   when a literal is cited (pass the literal as a `-e` argument, never interpolated inside a quoted
   string) — the same shape as `/implement`'s pre-flight STALE check. All cited anchors hold → print
   `REVISIT HOLDS` and carry it. Any miss → print `STALE REVISIT <finding>` in one line and continue
   as an un-revisited run. No checkable anchor at all → print `UNANCHORED REVISIT` and carry it
   marked as an unverified claim.

   Bind `DIRECTION` when the human has one (ask when unclear). Then STATE the step budget —
   anchored on the discovery in hand (frame's, or the frameless quick scout): name what it covers
   and what it leaves out; the human may change it — before drafting begins.
2. **Draft.** The driver drafts the plan's approach directly itself, using `PROBLEM`, `TARGET_DIR`,
   the step budget (stated in step 1), `DIRECTION` when bound, `REVISIT` when carried, and the
   design-questions procedure above. Dispatch `codebase-explorer` only if more codebase evidence
   is needed beyond what step 1's discovery already gathered. The draft covers: the approach and
   its precedent, its no-gos, its rabbit holes, and an outline of steps.
3. **Plan.** Settle only what blocks drafting a step boundary. A problem or scope question:
   1. **A frame is in context** — stays `/frame`'s job and is left open, not answered here;
      reopening it here would re-narrow a contract already critiqued.
   2. **Frameless** — no `/frame` exists to hand the question to, so `/shape` answers a problem
      question needed for its own problem statement, when nothing else can answer it.

   Bind the goal statement —
   `<Outcome> for <consumers> because <motivation>; done when <verification>` — from the draft's
   solution field: Outcome an observable end-state, every noun bound; `for` names ≥2 consumers or a
   stated concrete value; `because` must not restate the Outcome; `done when` names a re-runnable
   check, manual only with a stated reason. Draft:
   - **Block 1** — the plan goal statement, a before/after table, a step budget note comparing the
     dispatched step budget to the plan's final step count, and the draft's no-gos and rabbit
     holes as an explicit list.
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
   - **Block 3** — its precedent/rationale (what the draft's solution field cites), plus any
     design-question resolutions the draft made (each with its one-line why), how it's verified
     (end state + test plan).
   Silent self-review before presenting: placeholder scan, consistency, scope, earns-its-keep,
   premortem (imagine this plan already failed; name the most likely reason, fold it in),
   interface closure (every `consumes` produced by an earlier step, every `produces` has a
   consumer or a stated reason), risk substance (no boilerplate `none`), and the eight
   engineering-quality lenses (reusability, simplicity, minimality, readability, commit-history
   cleanliness, forward-looking architectural risk, architectural soundness, code style) — done
   independently of `engineering-reviewer`'s later check in step 4.
4. **Adversarial plan review, then plan approval.** Dispatch `structure-reviewer`,
   `readiness-reviewer`, and `engineering-reviewer` via Agent, in parallel, always, once.
   `structure-reviewer` gets the plan goal, the full step list (each Goal + Interfaces), the
   problem statement, the plan's no-gos/rabbit holes, and `configPath`, plus `REVISIT` when
   carried. `readiness-reviewer` gets the full step list (each step's Goal, Interfaces,
   Acceptance criteria, Risk) and `configPath`. `engineering-reviewer` gets the plan goal, the
   full step list, the problem statement, the plan's no-gos/rabbit holes, `REVISIT` when carried,
   and `configPath`, plus the `## Plan review` sections of `minimality.md`, `readability.md` and
   `architecture.md` under `${CLAUDE_PLUGIN_ROOT}/protocols/lenses/` — you read them per the
   section map in `${CLAUDE_PLUGIN_ROOT}/protocols/lenses/README.md` and inject their content,
   never paths. All three `OK` → present. Any `GAPS` → fix what you can; a hole only the
   human can close (human gate 1) → one framing line naming what it blocks, then the finding
   quoted exactly, and wait. Present the plan **Summary first**, then **Details** (Blocks 1–3).
   The **Summary** for a plan carries, in plain words and about 12 lines: one line per step saying
   what it changes, what the plan deliberately leaves alone, the one risk worth the reader's
   attention, and that approving starts `/implement`. No sherpa-internal names in it — no slot
   names, block numbers, anchors or verdict words. It only restates Details, never adds to it; a
   point you can't say plainly means Details is unclear — fix Details. A finding the human chose to
   leave open at gate 1: its framing line goes in the Summary, the quoted finding under Details.
   Then wait for **explicit** approval (human gate 2) — "approved", "go", "lgtm"; a question or
   critique is not approval. Rejecting here ends the run.

## Human gates
Exactly two points wait on the human; everything else is the driver deciding and showing its
work (see `Authority` above).
1. **Plan-review GAPS only the human can close** (step 4) — a `structure-reviewer`,
   `readiness-reviewer`, or `engineering-reviewer` finding the driver can't fix on its own.
2. **Plan approval** (step 4) — explicit "approved"/"go"/"lgtm"; the plan stays rejectable here.

The step budget (step 1) is stated up front, and the human may change it at any point — but that
is not a third gate; there's no formal wait on it.

## Output
The plan, presented once at plan approval, Summary first, then Details. Nothing in the repo;
persisting it is `/persist`'s job.

## Done when
An approved plan exists in context, or the human rejected at any human gate before a plan was
approved. Hand off to `/implement`, or offer `/persist`.
</content>
