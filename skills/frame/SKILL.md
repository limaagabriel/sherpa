---
name: frame
description: Macro layer (L1). Turns a fuzzy task into the frame — scout, problem contract, open questions, no solution bound. Writes nothing to disk. Triggers - "/frame <task>", "frame this", "what's the shape of X". Counterparts - /shape, /decompose, /implement.
---

# /frame — discover, then bind the problem

Produce **the frame** for `<task>`: the right problem, well-framed, with discovery and the open
questions named. The top of the ceremony gradient — use it when the task is fuzzy. A task with a
clear goal and a known approach may skip straight to `/decompose`; a clear problem with no chosen
direction goes to `/shape` instead
(`${CLAUDE_PLUGIN_ROOT}/protocols/layers.md` § A ceremony gradient).

The frame lives **in context** (printed, not on disk). Persisting it is the opt-in `/persist`
skill — never automatic.

## Operating rules
- **Authority:** the human owns every decision. You propose; they decide.
- **Stance:** feedback-first — open with a brief take when the human floats an approach.
- **No narration between tools.** One short sentence only when the *task* changes.
- **Conventions:** conform to the project's own style — the surrounding code; evidence-only (quote file:line). The pack's `codeStyle` (when present) is resolved by the subagent via resolve-pack-value.sh.
- **Harness:** under Codex/pi, read Claude-specific tool mentions per `${CLAUDE_PLUGIN_ROOT}/protocols/harness/codex.md` / `pi.md`.
- **Pack forwarding:** when a `configPath` is announced, forward it directly to `frame-reviewer`. The subagent resolves its own `knowledge` (cross-cutting) and `frame.knowledge` (frame-layer, additive) via resolve-pack-value.sh, per its own agent doc.

## Steps
1. **Discover.** Follow `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/discover.md`: `/scout`
   first, before any framing exists; bind discoverable slots evidence-first; **ask
   preference/framing questions the moment they arise** (one at a time, brainstorming-style),
   shaped per `${CLAUDE_PLUGIN_ROOT}/protocols/questions.md` — don't defer.
   **Pitch in context?** Its `solution` field's precedent citations are already-bound discovery and
   its `rabbit holes` are a known constraint — scout only the surface it doesn't cover.
2. **Compose the frame** = *problem contract + discovery + open questions + Vantage seeds*
   (`${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/frame.md` § Problem contract). Apply
   § Vocabulary test to the solved-signal before presenting. Classify each residual question per
   § Vantage test: problem/scope stays in open questions; solution-shaped becomes one line in
   **Vantage seeds** instead. Open questions hold only what the user left open or a tradeoff not
   yet resolvable — most were settled live in step 1; Vantage seeds hold the solution-shaped
   residue, left for `/shape` to pick up.
3. **Premortem (silent)** (Klein 2007). Imagine this frame already caused a failure; name the
   most likely reason. Fold the answer into discovery or open questions, or Vantage seeds when
   the answer is solution-shaped (§ Vantage test); don't present it as an inline hedge.
4. **Present** the frame in sections scaled to complexity; confirm after each; revise on feedback.
   The open questions section presented here never includes a solution-shaped question — that
   material lives in Vantage seeds instead.
5. **Critique.** Dispatch `frame-reviewer` (one shot) over the composed frame, forwarding the
   verbatim task-initiating request alongside it — the request the reviewer needs to judge
   fidelity, not just form. `HOLES` → name what it blocks, in the reader's terms, then surface
   verbatim (`${CLAUDE_PLUGIN_ROOT}/protocols/prose.md` § Verbatim is a quote, not a frame) and
   fix what you can; a hole only the human can close → wait.

## Done when
The frame is composed, presented, and critiqued. Hand off to `/shape` (it reads the frame from
context), or offer `/persist` if the user wants it on disk.
