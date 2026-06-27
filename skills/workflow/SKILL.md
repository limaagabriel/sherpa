---
name: workflow
description: Run the full Discover -> Analyze -> Plan -> Execute -> Validate workflow for a task end to end. Thin orchestrator that runs /plan, then on approval runs /execute. Use when you want the whole loop in one go. Triggers - "/workflow <task>", "run the full workflow", "plan and implement X". For just one half, call /plan or /execute directly.
Layer: cross-cutting
---

# /workflow — the full loop

End-to-end Discover -> Validate for `<task>`. This skill is intentionally thin:
it chains the two halves and lets the approval gate sit between them.

## Steps

1. **Plan.** Invoke the `/plan` skill with `<task>`. It scouts, analyzes,
   presents a Plan proposal, and **waits for explicit approval** — that gate is
   the human's, do not auto-advance past it.
2. **Execute.** Once the human approves, invoke the `/execute` skill (same
   run-state `<key>`). It reads the approved plan and runs Execute -> Validate.

Each half persists its own run-state, so you can stop after `/plan` and resume
with `/execute` in a later session — `/workflow` is just the convenience of
running both without re-typing the task.

Authority, Stance, Conventions, and "never push" rules are inherited from
`/plan` and `/execute` — see those skills.
