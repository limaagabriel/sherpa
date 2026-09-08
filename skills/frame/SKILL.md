---
name: frame
description: Frame layer. Turns a fuzzy task into the frame — scout, problem statement, open questions, no solution bound. Writes nothing to disk. Triggers - "/frame <task>", "frame this", "what's the shape of X". Counterparts - /shape, /implement.
---

# /frame — discover, then bind the problem

Produce **the frame** for `<task>`: the right problem, well-framed, with discovery and the open
questions named. Never binds a solution. The frame lives **in context** (printed, not on disk);
persisting it is the opt-in `/persist` skill — never automatic.

## Operating rules
- **Authority:** the human owns every decision. You propose; they decide.
- **No narration between tools.** One short sentence only when the *task* changes.
- **Questions:** a prose walk in three lines — *found* (what turned up, in user-observable terms),
  *which means* (why there's a choice), *so* (the hand-off) — then `AskUserQuestion`, each option's
  description one clause naming its downstream consequence, recommended option first. A pure
  preference question gets no walk. Skip the introduction for a surface the reader already showed
  they know. The test for any human-facing prose: could the reader act on it without opening the
  code? If not, introduce or translate the term.
- **Harness:** under Codex/pi, read Claude-specific tool mentions per
  `${CLAUDE_PLUGIN_ROOT}/protocols/harness/codex.md` / `pi.md`.
- **Pack:** forward `configPath` to `frame-reviewer` — it resolves it itself.

## Steps
1. **Discover.** Dispatch the `scout` agent (task, target dir, breadth `quick`/`medium`/`very
   thorough` scaled to surface) before asking the user anything. A `/shape` proposal already in
   context counts as bound discovery — its `solution` field's precedent citations and its
   `rabbit holes` are a known constraint; scout only the surface the proposal doesn't cover.
2. **Draft the problem statement** — one sentence, five bound slots:
   > `<who>` cannot `<capability>` because `<obstacle>`; costs `<consequence>`; done signal is
   > `<observable>`.

   | Slot | Rule |
   |---|---|
   | Who | A concrete named party, never "the user". |
   | Capability | Their goal, never the feature that grants it. |
   | Obstacle | The present-tense root cause, not the absence of a fix. |
   | Costs | What breaks if unsolved, not a restatement of the obstacle. |
   | Done signal | What an observer sees flip, never the mechanism producing it. |

   Bind each unbound slot evidence-first from the scout. A slot that needs a preference is asked
   right then, one at a time, never assumed.
3. **Compose the frame** — contract, discovery (file:line landmarks, precedent, constraints),
   open questions (problem/scope residue only), design questions (for /shape) (solution-shaped
   residue, one line each).

   **No-mechanism check.** Apply it to the done signal before presenting: every noun and verb in
   it must already appear in who/capability/obstacle, or be observable before any change is made.
   A noun that exists only once a particular solution is built, or a verb naming HOW the change
   happens (self-heals, auto-retries, caches, migrates), is mechanism leakage — rewrite the slot.
   > Fail: "no tracked file references the old skill name" — "old skill name" presumes the rename.
   > Pass: "a frame-layer run produces discovery that still supports more than one direction".

   **Design-question check.** Classify each candidate open question: one about who/capability/obstacle/
   costs/done signal, or the task's boundary, stays an open question. One whose answer picks a
   mechanism, a technology, or an implementation angle becomes one line in **design questions (for
   /shape)** instead — resolving it would bind a solution, `/shape`'s job, not frame's.
   > Problem/scope: "which system is the source of truth for X?" stays an open question.
   > Solution-shaped: "should X be cached or recomputed?" routes to design questions.
4. **Premortem (silent).** Imagine this frame already caused a failure; name the most likely
   reason. Fold the answer into discovery, open questions, or design questions — never an inline
   hedge.
5. **Present** the frame in sections scaled to complexity; confirm after each; revise on feedback.
6. **Critique.** Dispatch `frame-reviewer` (one shot) with the frame, the verbatim
   task-initiating request, and `configPath`. `GAPS` → one framing line naming what it blocks in
   the reader's terms, then the finding quoted exactly; fix what you can; a hole only the human can
   close → wait.

## Don't
- Bind an `Outcome` — that's `/shape`'s job, once a candidate is picked.
- Name a mechanism — noun or verb — in any slot, including the done signal.
- Defer a problem question to `/shape`. If it's about the problem, resolve it here.
- Put a solution-shaped question in open questions — route it to design questions instead.

## Done when
The frame is composed, presented, and critiqued. Hand off to `/shape` (it reads the frame from
context), or offer `/persist` if the user wants it on disk.
