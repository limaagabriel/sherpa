# Execute

Break the plan into a discrete task list, dispatch `/build-and-review` per step.

## TaskCreate / TaskUpdate
- One task per step. Exactly one `in_progress` at a time.
- Flip to `completed` only on the step's commit(s) landing.

## /build-and-review dispatch
Pass the step's `task` + `Goal` + `Acceptance criteria` (+ `mode: inline` when approved in inline mode). Each step:
- Builds in isolation — no half-applied codegen, no orphaned schema / migration artifacts.
- Surfaces a short summary.
- Ends as one commit per subtask — 1–6 subtasks per step, each landing its own `Build-Id`-noted commit. `/build-and-review` and tier workers own those commits; never add a manual commit on top.

## Verdicts
Per `protocols/adversarial/verdict-handling.md`. PASS / WARN / auto-cleared FIX → next step. BLOCK or unresolved finding → wait for my approval.
