---
name: plan
description: Drive the Discover -> Analyze -> Plan half of the workflow for a task — scout the code, bind a goal contract, clarify open decisions, then present a Plan proposal and wait for explicit approval. Persists SPEC + DECISIONS run-state for /execute to pick up. Triggers - "/plan <task>", "plan this", "plan the implementation of X". The counterpart is /execute; /workflow chains both.
---

# /plan — Discover, Analyze, Plan

Produce an **approved plan** for `<task>`, persisted so `/execute` (or a later
session) can run it. Stop at the approval gate — do NOT write code here.

## Operating rules (apply throughout)
- **Authority:** the human owns every decision — clarifications, plan approval,
  inline mode. You propose; they decide. Never self-declare inline mode.
- **Stance:** feedback-first — when the human floats an approach, open with a
  brief take (sound? risk? better option?). Push back when a better path exists.
- **No narration between tools.** One short sentence only when the *task* changes.
- **Conventions:** guard clauses, SRP, short functions, no inline comments,
  evidence-only (quote file:line). Style enforcement itself is a project-pack
  capability — see `${CLAUDE_PLUGIN_ROOT}/packs/README.md`.

## Gates (run in order — none skipped)

1. **Set up run-state.** Resolve `BASE` per `state-persistence.md` § Run-state directory — the active pack's `projectStatePath` (from the `WORKFLOW_PACK:` line) when announced, else `${WORKFLOW_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/claude-workflow}`; `<key>` = current git branch, else slug the raw task via `${CLAUDE_PLUGIN_ROOT}/scripts/run-state-key.sh`. `mkdir -p "$BASE/<key>"`. Follow `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/state-persistence.md` (incl. follow-up archiving).
2. **Discover.** Follow `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/discover.md`: scout via `/scout` BEFORE asking anything; draft the goal contract; bind discoverable slots evidence-first; `AskUserQuestion` only for genuine preferences/decisions.
3. **Analyze.** Follow `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/analyze.md`: root cause + affected deps, then the unconditional alternative-approach panel → chosen framing. On assumption-failure, return to Discover.
4. **Plan.** Follow `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/plan.md`: draft from Analyze's chosen framing, then present the Plan proposal (Plan-at-a-glance + before/after table + per-step blocks with goal contracts + Why/How), after a silent self-review and a `plan-breaker` `mode=briefing` pass (via Agent).
5. **Persist + await approval.** On the brief closing, write `SPEC.md` (Discover fields). Wait for an **explicit** affirmative on the current proposal — a question or critique is not approval. On approval: append the plan to `SPEC.md`, write `DECISIONS.md`, and record the inline-mode flag if the human declared one.

## Done when
An approved plan exists in `SPEC.md` + `DECISIONS.md` under `$BASE/<key>/`. Hand off to `/execute`.
