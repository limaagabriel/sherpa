# Plan

Present a **Plan proposal**, then wait for approval. It adapts to task shape (bug / refactor / feature / multi-step) but always carries the three blocks below — even a one-line fix gets the full shape.

## Plan proposal format

### Block 1 — Plan at a glance
- The **plan goal** as a goal contract (§ Goal contract) — the north star every step traces to.
- A **before / after table** — current → target, one row per affected area. The user reads this to confirm the plan closes the gap before reading any step. Works for every shape: bug (buggy → correct), refactor (current → target structure), feature (absent → present), docs/rename/config (old → new).

### Block 2 — Steps
Each step is its own block (a single-step task still gets one block — don't collapse to prose). Every step carries:
- **Goal** — a step goal contract (§ Goal contract). It must trace up to the plan goal; a step whose Outcome doesn't advance the north star is dead weight.
- **Change** — the concrete delta. Bugs: root cause + fix. Multi-step: this step only.
- **Example** — a small illustration of what the step *produces* (before→after snippet, or sample input→output). This is what makes a dead step visible — the user sees the result, not just a description.
- **Acceptance criteria** — `done = <X>, confirmed by <re-runnable automated check>` (test/command). Manual observation only when the step states why no automated check is possible.

### Block 3 — Why & how
- **Why this approach** — the next-best alternative and why it lost. Bugs: confirming evidence (file:line, repro, log) that localizes the root cause. Features/refactors: the architectural trade-off.
- **How it's verified** — observable end state + test plan. Required before any logic change. Docs/renames/config: the manual check that confirms success.

## Goal contract

Every goal — the one **plan goal** and each **step goal** — is one sentence with four bound slots:

> **`<Outcome>` for `<consumers>` because `<motivation>`; done when `<verification>`.**

| Slot | Rule |
|---|---|
| **Outcome** | An observable end-**state**, every noun bound. Not an action ("decompose", "refactor"); not a vague reference ("the relevant X"). |
| **For** | Who consumes the result. Every new abstraction (extracted method, class, param, indirection) names **≥2 consumers or a stated concrete value** — a single-caller extraction with no named reuse earns nothing. |
| **Because** | The parent intent served. Must not restate the Outcome. |
| **done when** | `confirmed by <re-runnable automated check>` (test/command); manual observation only with a stated reason it can't be automated — same bar as § Acceptance criteria format. |

**Two layers.** The plan goal is the north star; each step goal is the local driver (gated by `step-reviewer` before building begins) and must trace up to it. The fill-in form makes an empty slot visible — and an unbound slot is a Discover question, not something to assume (see `phases/discover.md`).

## Draft from the chosen framing
Build the proposal from the **chosen framing** the Analyze panel produced (`phases/analyze.md`) — the decomposition is already diverged and judged; don't re-open it here. Record the chosen shape and why the rivals lost in Block-3 — `plan-reviewer`'s Unsound why-lost lens attacks that rationale next.

## Self-review (silent, before presenting)
Run on your draft before showing it. Fix inline; surface nothing. The dead-plan net — runs every plan.
1. **Placeholder scan** — any TBD/TODO/vague requirement? Catch semantic ones too: an unbound noun-phrase in any Outcome ("the relevant X"). Bind it or send to Discover.
2. **Internal consistency** — do steps contradict? Do they actually sum to the after-state?
3. **Scope** — one plan's worth, or does it need decomposition?
4. **Ambiguity** — could a step read two ways? Pick one, make it explicit.
5. **Dead-plan smell test** — does before/after close the brief's `Goal` gap? Does every step trace up? A step that doesn't → cut or justify.
6. **Earns-its-keep** — every abstraction's `For` names ≥2 consumers or a value; every `Because` says what breaks if absent (not a restated Outcome). Fails either → ceremony; fix or cut.

## Acceptance criteria format
`done = <X>, confirmed by <re-runnable automated check>` (test/command) — a decidable pass/fail, re-runnable without a human. Manual observation only when the step states why no automated check is possible.

## Adversarial goal review (plan-reviewer, mode=briefing)
After the silent self-review, before presenting, dispatch `plan-reviewer` `mode=briefing` via Agent. Forward the plan goal, the full step list (each goal in contract form), the brief (or `SPEC.md` path), and the proposal's Block-3 "Why this approach" (next-best alternative + why it lost). When the active pack announced an `architectureRules` command, run it (via Bash) and forward its stdout — the project's architectural guidelines. It attacks both layers + step→plan traceability + decision content: unbound Outcome, ceremony `For`, circular `Because`, unverifiable done-when, orphan step, plan-goal↛brief gap, rationale orphan, step too coarse, unsound why-lost, architecture-rule violation, unstated load-bearing assumption. Handle per `protocols/adversarial/verdict-handling.md`. A hole only the human can close → BLOCK: bind via `AskUserQuestion`, then re-attack (fresh Agent call). Self-review grades your own goal; this is the independent eyes it can't be.

## Approval
Wait for explicit approval before any Execute action.

**What counts:** an affirmative on *this* proposal — "approved", "go", "ship it", "lgtm", "proceed", "do it". Nothing else. A question, critique, change request, or curious reaction ("why this step?") is **not** approval. When in doubt, you are not approved.

**Answering doesn't advance the gate.** Replying to a question leaves you waiting. Don't read your own answer, or the user's acknowledgement of it, as go-ahead. If the answer changed the proposal, re-present and re-await. The gate clears only on an explicit approve-signal that post-dates the latest version.

Default is **normal mode** — assume normal unless the user explicitly declares inline ("approved inline"). You may ask about inline preference, but the answer is never required: silence on the mode question = normal (mode-axis only, never a plan-approval signal). When several architectures fit the brief and a wrong pick is costly, the Analyze panel (`phases/analyze.md`) already diverged on it. Reference patterns with file:line.

## On approval
Append the Plan at a glance + before/after table + steps to `SPEC.md` — see `phases/state-persistence.md`.

## Don't
- Skip approval, even for small fixes.
- Treat a question, critique, or your own answer as approval — only an explicit affirmative on the current proposal clears the gate.
- Default to inline on silence — silence on the mode question = normal.
- Reference a file before verifying it exists.
- Present without the silent self-review and the plan-reviewer briefing pass.
- Bind an unbound goal slot by assumption — evidence-first, ask preferences (see `phases/discover.md`).
