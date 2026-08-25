---
name: shape
description: Shape layer (L2). Fans out N candidates from a problem contract, critiques the pool, picks one, then plans it. Frameless-tolerant - runs its own scout when no frame exists. Triggers - "/shape", "/shape <problem>", "brainstorm directions". Counterparts - /frame, /implement, /persist.
---

# /shape — fan out candidate directions, pick, then plan

Produce **the pitch, then the plan** for the problem: N coarse step lists, skeletoned, critiqued,
one picked, then turned into an ordered, critiqued step list ready to build.
`/shape` is L2 in sherpa's three-layer spine (`${CLAUDE_PLUGIN_ROOT}/protocols/layers.md`). With a
frame in context it runs AFTER `/frame` and reads that
frame's problem contract as-is; with none, it runs its own quick discovery and moves straight to
Vantages (§ Boundaries below) — a task whose problem is already clear but whose solution isn't
should reach `/shape` directly, no `/frame` detour. It owns both artifacts end to end and hands
the approved plan straight to `/implement`, one step at a time. Lives **in context** (printed, not
on disk); persisting either artifact is the opt-in `/persist` skill.

## Boundaries
`/shape` no longer hard-requires a frame; it now tolerates two paths depending on what's unbound.
**Framed:** a frame in context supplies `PROBLEM` as-is; `/shape` does not re-narrow it —
reopening the problem re-does work L1 already critiqued. **Frameless:** with no frame, run a quick
`/scout` first, then draft an INLINE problem contract from the task + that scout's evidence
(`${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/shape.md` § Boundaries;
`${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/frame.md` § Problem contract) — the same contract
format `/frame` itself uses, applying its § Vocabulary test to the solved-signal. Appetite is
asked once this inline contract exists, after the quick scout and before wave 1's mainline
dispatch (§ Procedure).

**Scout-evidence wall.** That quick scout's output feeds the inline contract and the appetite
anchoring ONLY — it never reaches a `shape-builder`'s brief. Forwarding it there would hand every
builder the same pre-run read of the codebase, the exact anchoring the isolation invariant already
bars between builders (`${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/shape.md` § Critique —
Isolation invariant); the wall extends that invariant to the driver's own pre-dispatch evidence,
not just to a sibling builder's output. This is the one exception to "no `/scout` dispatch" below
— the wall, not a ban on running it, keeps it safe.

## Inputs
- `PROBLEM` — the problem contract to fan out on. A frame's problem contract when one is in
  context (used as-is), or the driver's own inline contract on the frameless path (§ Boundaries).
  Vantages derive from it per run; no shipped list
  (`${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/shape.md` § Vantages).
- `TARGET_DIR` — absolute path to explore. Default: current working directory.
- `COUNT` — candidates per builder. Default 3, except a wave-1 `mainline` dispatch, always
  `COUNT=1` (§ Procedure).
- Appetite — a step budget the human sets once, before wave 1's mainline dispatch, anchored on
  whichever discovery exists by then — the frame's, or the frameless path's quick scout
  (`${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/shape.md` § Appetite).

## Operating rules
- **Authority:** the human owns every decision. You propose; they decide.
- **Stance:** feedback-first — open with a brief take when the human floats an approach.
- **No narration between tools.** One short sentence only when the *task* changes.
- **Conventions:** the project's own style — the surrounding code; evidence-only (quote file:line). The pack's `codeStyle` (when present) is resolved by the subagent via resolve-pack-value.sh.
- **Harness:** under Codex/pi, read Claude-specific tool mentions per `${CLAUDE_PLUGIN_ROOT}/protocols/harness/codex.md` / `pi.md`.
- **Pack forwarding:** when a `configPath` is announced, forward it to `shape-reviewer`,
  `structure-reviewer`, and `readiness-reviewer` — all three now dispatch inside this one `/shape`
  run (§ Procedure). `shape.knowledge` is not the only key this run touches: each subagent resolves
  its own via resolve-pack-value.sh, per its own agent doc — `shape-reviewer` resolves `knowledge`
  (cross-cutting) and `shape.knowledge` (additive); `structure-reviewer` resolves `knowledge`,
  `decompose.knowledge`, and `decompose.architecture`; `readiness-reviewer` resolves `knowledge`
  and `decompose.knowledge` only, never architecture — a cross-step concern outside its per-step
  scope. No new `shape.architecture` key exists; the plan-tail reviewers keep the `decompose.*`
  keys their own agent docs already name, unchanged by where they're dispatched from.
- **Explicit invocation only.** Never auto-fire; OFFER `/shape <problem>` in one declinable line
  instead.
- **Agent-call math** (derived from `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/shape.md`
  § Critique and § Plan — Adversarial plan review): the **SUFFICIENT** path — wave 1's mainline
  candidate clears the evidence bar, wave 2 never fires — costs **4 agent calls** total: 1
  `shape-builder` (mainline, `COUNT=1`) + 1 `shape-reviewer` (wave 1) + 1 `structure-reviewer` + 1
  `readiness-reviewer` (plan tail). The **INSUFFICIENT** path — wave 2 fires — costs **9**: those
  same 4, plus wave 2's 4 `shape-builder` calls (mainline re-dispatched fresh at `COUNT=3`, plus
  the three falsifying builders, concurrent) + 1 more `shape-reviewer` call over the full pool.
- **No `/scout` dispatch to a builder** — each `shape-builder` reads the codebase itself; a shared
  evidence base would anchor the branches, the failure mode the fan-out exists to avoid. The
  frameless path's own quick `/scout` (§ Boundaries) is the driver's, never forwarded into a
  builder's brief — the scout-evidence wall.

## Procedure
1. **Establish `PROBLEM`, then ask appetite.** Frame in context → read its problem contract as-is,
   move straight to step 2. No frame → run a quick `/scout`, draft the inline problem contract from
   the task + that scout's evidence, applying the § Vocabulary test to the solved-signal
   (§ Boundaries) — remember the scout-evidence wall: that scout's output stops here, never
   forwarded to a builder. Either way, ASK the appetite next, shaped per
   `${CLAUDE_PLUGIN_ROOT}/protocols/questions.md`, anchored on whichever discovery now exists
   (`${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/shape.md` § Appetite) — before any builder
   call is spent.
2. **Wave 1 — mainline only.** Dispatch one `mainline` `shape-builder` at `COUNT=1`: `PROBLEM`,
   `TARGET_DIR`, the appetite — nothing else. Then dispatch `shape-reviewer` over that single
   candidate. It renders `EVIDENCE: SUFFICIENT | INSUFFICIENT` first
   (`${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/shape.md` § Critique — the SUFFICIENT bar).
   **`SUFFICIENT`** — the output degrades to that one candidate's own solved/bounded/necessity
   judgment; skip step 3, go straight to step 4. **`INSUFFICIENT`** — continue to step 3.
3. **Wave 2 — full pool (only on `INSUFFICIENT`).** Dispatch the three falsifying `shape-builder`s
   (one per obstacle/capability/costs vantage, `who`/solved-signal off limits to them) plus
   `mainline` RE-DISPATCHED fresh at `COUNT=3` — wave 1's `COUNT=1` candidate is discarded, not
   reused as a pool slot — four builder calls, ONE message, concurrent.
   THE ISOLATION INVARIANT IS YOURS TO ENFORCE, not the builder's
   (`${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/shape.md` § Critique — Isolation invariant):
   brief each with only its own premise, `TARGET_DIR`, `COUNT`, and the appetite — never a
   sibling's output, never wave 1's own mainline output. Assign each pooled candidate a stable ID,
   then dispatch one `shape-reviewer` call over the full pool — briefed to reuse those IDs
   verbatim, and NEVER told wave 1's `EVIDENCE` verdict or which candidate was mainline's original
   reuse/mirror finding. Returns a ranked shortlist of 2-4, `traps`, the collapse record, and a
   `CONTESTED: yes | no` token.
4. **Compose the pitch, then get the pick.** Compose — never forward `shape-reviewer`'s return
   value as the emission (`${CLAUDE_PLUGIN_ROOT}/protocols/prose.md` § Compose, don't relay).
   `CONTESTED: no`, or wave 1's `SUFFICIENT` degenerate case — auto-pick the winner, no wait.
   `CONTESTED: yes` — surface the top-2 as ONE solution open question in the pitch and wait for the
   human's resolution; that pick belongs to them alone. Rejecting the pitch outright — the
   auto-pick, or both contested candidates — is a valid outcome; it ends the run here, before any
   plan is drafted. **Emit the pitch** — see `## Output`.
5. **Plan the pick.** Once a candidate is picked, follow
   `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/shape.md` § Plan in the same run — this is not
   a hand-off to a separate layer: bind `Outcome` from the picked candidate's `solution` field,
   bind `for`/`because`/`done when` as normal, settle only what blocks drafting a step boundary, then
   draft the plan proposal's three blocks (plan at a glance, steps, why & how). Run the silent
   self-review (placeholder scan, consistency, scope, earns-its-keep, premortem, interface
   closure, risk substance).
6. **Adversarial plan review, then the one approval.** Dispatch `structure-reviewer` and
   `readiness-reviewer` via Agent, in parallel, always — no gate on plan size or reversibility
   (`${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/shape.md` § Adversarial plan review).
   `structure-reviewer` gets the plan goal + full step list (each goal contract, each `Interfaces`)
   + the frame path, or the inline contract when frameless, + the pitch's `no-gos`/`rabbit holes`
   when carried + `configPath`. `readiness-reviewer` gets the full step list with each step's Goal,
   Interfaces, Acceptance criteria, Blast contract, and Risk + `configPath`. Both `SOLID` →
   present. Either `HOLES` → fix what you can; a hole only the human can close → name what it
   blocks, then surface verbatim
   (`${CLAUDE_PLUGIN_ROOT}/protocols/prose.md` § Verbatim is a quote, not a frame) and wait. Present
   the plan, then wait for **explicit** approval — "approved", "go", "ship it", "lgtm"; a question,
   critique, or your own answer is not approval. This is the run's ONE approval point — the plan,
   never a separate approval of the pitch's pick.

## Output
**The candidate roster, then the pitch, then — once approved — the plan proposal.**

1. **Roster.** Every candidate ID the shortlist, the traps, or the collapse record refers to gets
   one roster line first — its ID bound to a short plain-words name plus what it does — because a
   pool-internal ID carries no meaning outside the dispatch bookkeeping that produced it
   (`${CLAUDE_PLUGIN_ROOT}/protocols/prose.md` § The referent rule). No ID appears before its
   roster line.
2. **The pitch** — five fields per
   `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/shape.md` § Pitch (problem, appetite, solution,
   rabbit holes, no-gos), carrying the picked skeleton, its precedent, and the rejected candidates
   with why they lost. Rejecting it outright ends the run here.
3. **The plan proposal** — once a candidate is picked, the three blocks per
   `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/shape.md` § Plan proposal format: Block 1 (plan
   goal as a goal contract, before/after table, appetite note comparing the dispatched appetite to
   the plan's final step count), Block 2 (one block per step — Goal, Change, Interfaces, Example,
   Acceptance criteria, Blast contract, Risk), Block 3 (why this approach, how it's verified) —
   presented only after the silent self-review and both `structure-reviewer` and
   `readiness-reviewer` return `SOLID` (or their holes are fixed).

Nothing on disk either way; persisting the pitch or the plan is `/persist`'s job.

## Done when
An approved plan exists in context, or the human rejected the pitch before one was drafted. Hand
off to `/implement` (it consumes the plan one step at a time), or offer `/persist` if the human
wants either artifact saved.
