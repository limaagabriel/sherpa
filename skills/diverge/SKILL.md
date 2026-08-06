---
name: diverge
description: Macro-layer TOOL that fans out isolated divergers per concern, critiques the pool, and returns a picked Direction record. Triggers - "/diverge", "/diverge <problem>", "brainstorm directions", "what are the options".
---

# /diverge — fan out competing directions, let the human pick

`/diverge` is a macro-layer TOOL, not a layer driver — it changes nothing and owns no artifact
of its own, exactly as `/scout` doesn't. It answers "which direction should this take?" BEFORE
`/frame` frames one; its Direction record is consumed at `/plan` step 0, where `Outcome` binds.
It is not part of the three-layer spine; `/frame` still drives the macro layer's artifact.

## Inputs
- `PROBLEM` (required) — the open problem, NOT a chosen approach.
- `CONCERNS` — default four: `architecture & precedent`, `ergonomics & API surface`, `ops &
  failure modes`, `cost & simplicity`. Overridable per call — the set is a default, not a fixed
  taxonomy.
- `TARGET_DIR` — absolute path to explore. Default: current working directory.
- `COUNT` — candidates per concern. Default 3.

## Operating rules
- **Authority:** the human owns every decision. You propose; they decide.
- **Stance:** feedback-first — open with a brief take when the human floats an approach.
- **No narration between tools.** One short sentence only when the *task* changes.
- **Conventions:** conform to the project's own style — via the pack's `codeStyleRules` when
  announced, else the surrounding code; evidence-only (quote file:line).
- **Harness:** under Codex/pi, read Claude-specific tool mentions per
  `${CLAUDE_PLUGIN_ROOT}/protocols/harness/codex.md` / `pi.md`.
- **Pack forwarding:** forward pack `knowledge` (cross-cutting) and `diverge.knowledge`
  (diverge-layer, additive) inline prose — when announced — to `diverge-reviewer` as its
  `DIVERGE_KNOWLEDGE` input.
- **Explicit invocation only.** ~5 agent calls per run. Never auto-fire; when a task looks like
  it would benefit, OFFER `/diverge <problem>` in one declinable line instead.
- **No `/scout` dispatch.** Each diverger reads the codebase itself. A shared evidence base
  anchors the branches to one reading of the code, which is the failure mode the fan-out exists
  to avoid.

## Procedure
1. **State the problem.** Read `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/plan.md` §
   Goal contract so you know the shape `/plan` needs downstream — then deliberately emit NO
   goal contract. Bind nothing but the problem itself; the candidates ARE the competing
   `Outcome` fills, so binding `Outcome` here would pre-pick the answer the fan-out exists to
   find. Show the human your problem statement before dispatching.
2. **Diverge.** One `diverger` dispatch per concern, all in ONE message so they run
   concurrently. THE ISOLATION INVARIANT IS YOURS TO ENFORCE, not the diverger's: brief each
   with only `PROBLEM` / `CONCERN` / `TARGET_DIR` / `COUNT` — never another diverger's output,
   never a summary of a sibling's ideas, never the pool so far. Branches that see each other
   anchor each other and the fan-out collapses to one wider thought. Do not serialize the
   dispatches.
3. **Critique.** One `diverge-reviewer` dispatch, briefed with its three declared inputs:
   `PROBLEM`, `CANDIDATES` (the full pool from every concern at once), and
   `DIVERGE_KNOWLEDGE` when a pack announced it. It returns the ranked 2-4 shortlist with each
   candidate's ranking rationale, traps, and the collapse record. You do not score candidates
   yourself — the generator/critic split is what makes the fan-out worth its cost.
4. **Present.** The shortlist with each candidate's `precedent` and `risk` intact, the traps
   with their one-line reasons, and the collapse record so the human can see how much real
   breadth the fan-out found.
5. **Wait for the pick.** The human chooses. Never auto-select, never pick "the obvious one" on
   their behalf — a synthesized direction nobody approved becomes the premise of everything
   downstream. The human may also reject the whole shortlist; that is a valid outcome, not a
   failure.
6. **Emit the Direction record.** The handoff artifact — see `## Output`.

## Output
The **Direction record** — five fields, one line each:
- `direction` — the picked candidate, one sentence, as a proposed `Outcome` for `/plan` to bind at step 0.
- `precedent` — `file:line — what_it_exemplifies` entries carried over from the winning
  candidate.
- `risk` — the load-bearing risk.
- `rejected` — each shortlisted loser with the critic's one-line ranking rationale for why it
  lost, plus the traps with their one-line reasons.
- `confidence` — one line, justified by how much of the relevant surface the divergers actually
  covered.

Nothing on disk. `/plan` consumes this record at step 0.

## Done when
A Direction record exists in context (or the human rejected the shortlist). Hand off to
`/plan` (it consumes the record at step 0), or offer `/persist` if the human wants it saved.
