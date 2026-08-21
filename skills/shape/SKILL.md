---
name: shape
description: Shape layer (L2). Fans out N candidates from the frame's vantages, critiques the pool, hands a pitch to pick. Requires a frame. Triggers - "/shape", "/shape <problem>", "brainstorm directions", "what are the options". Counterparts - /frame, /decompose, /implement.
---

# /shape — fan out candidate directions, let the human pick

Produce **the pitch** for the frame's problem: N coarse step lists, skeletoned, critiqued, one
picked. `/shape` is L2 in the four-layer spine, running AFTER `/frame`; it owns the pitch,
consumed by `/decompose` at its step 0. Lives **in context** (printed, not on disk); persisting is
the opt-in `/persist` skill.

**Requires a frame.** With none in context there is no vantage axis to fan out on at all — OFFER
`/frame` in one declinable line and stop; there is no lighter fallback.

## Inputs
- `PROBLEM` — the frame's problem contract, in context. Vantages derive from it per run; no
  shipped list (`${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/shape.md` § Vantages).
- `TARGET_DIR` — absolute path to explore. Default: current working directory.
- `COUNT` — candidates per builder. Default 3.
- Appetite — a step budget the human sets before dispatch
  (`${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/shape.md` § Appetite).

## Operating rules
- **Authority:** the human owns every decision. You propose; they decide.
- **Stance:** feedback-first — open with a brief take when the human floats an approach.
- **No narration between tools.** One short sentence only when the *task* changes.
- **Conventions:** the project's own style — the surrounding code; evidence-only (quote file:line). The pack's `codeStyleRules` (when present) is resolved by the subagent via resolve-pack-value.sh.
- **Harness:** under Codex/pi, read Claude-specific tool mentions per `${CLAUDE_PLUGIN_ROOT}/protocols/harness/codex.md` / `pi.md`.
- **Pack forwarding:** when a `configPath` is announced, forward it directly to `shape-reviewer`. The subagent resolves its own `knowledge` (cross-cutting) and `shape.knowledge` (additive) via resolve-pack-value.sh, per its own agent doc.
- **Explicit invocation only, 5 agent calls per run** (4 `shape-builder` + 1 `shape-reviewer`).
  Never auto-fire; OFFER `/shape <problem>` in one declinable line instead.
- **No `/scout` dispatch** — each `shape-builder` reads the codebase itself; a shared evidence
  base would anchor the branches, the failure mode the fan-out exists to avoid.

## Procedure
1. **Derive the vantages** from the frame's obstacle / capability / costs slots, PLUS the fixed
   mainline vantage
   (`${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/shape.md` § Vantages). Show the human the
   vantages, then ASK the appetite
   (`${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/shape.md` § Appetite).
2. **Generate.** Three falsifying `shape-builder` dispatches (one per obstacle/capability/costs
   vantage) plus the one fixed `mainline` dispatch — four total — all in ONE message, concurrent.
   THE ISOLATION INVARIANT IS YOURS TO ENFORCE, not the builder's
   (`${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/shape.md` § Critique — Isolation invariant):
   brief each with only its own premise, `TARGET_DIR`, `COUNT`, and the appetite — never a
   sibling's output, never the pool so far. This applies to `mainline` too: it doesn't get to see
   the falsifying builders' output either.
3. **Critique.** The driver assigns each pooled candidate a stable ID when it pools the builders'
   output, and briefs `shape-reviewer` to reuse those IDs verbatim in the shortlist, traps, and
   collapse record. One `shape-reviewer` dispatch over the pooled candidates
   (`${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/shape.md` § Critique), with `PROBLEM` (the
   frame's problem contract — `shape-reviewer` judges `necessity` against it), `shape.knowledge`
   when a pack announced it, and the appetite — `shape-reviewer` needs it to judge `bounded`
   (`agents/shape-reviewer.md` § Inputs (from caller)). Returns the shortlist with precedent, risk, skeletons,
   traps, and the collapse record.
4. **Compose the emission** — the driver composes the pitch from `shape-reviewer`'s return value;
   forwarding that return value as the message hands the human a machine channel
   (`${CLAUDE_PLUGIN_ROOT}/protocols/prose.md` § Compose, don't relay). Then wait for the pick —
   never auto-select; rejecting the whole shortlist is a valid outcome, not a failure. **Emit the
   pitch** — see `## Output`.

## Output
**The candidate roster, then the pitch.** Every candidate ID the shortlist, the traps, or the
collapse record refers to gets one roster line first — its ID bound to a short plain-words name
plus what it does — because a pool-internal ID carries no meaning outside the dispatch bookkeeping
that produced it (`${CLAUDE_PLUGIN_ROOT}/protocols/prose.md` § The referent rule). No ID appears in
the emission before its roster line.

**The pitch** — five fields per `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/shape.md` § Pitch
(problem, appetite, solution, rabbit holes, no-gos), carrying the picked skeleton, its
precedent, and the rejected candidates with why they lost. Nothing on disk.

## Done when
A pitch exists in context (or the human rejected the shortlist). Hand off to `/decompose` (it
consumes the pitch at its step 0), or offer `/persist` if the human wants it saved.
