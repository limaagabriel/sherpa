---
name: execute
description: Drive the Execute -> Validate half of the workflow against an already-approved plan — read SPEC/DECISIONS/PROGRESS from run-state, build each step (per-step build-and-review, or inline when the human approved inline mode), then validate the plan goal. Triggers - "/execute", "/execute <key>", "execute the plan", "run the approved plan". Requires a plan from /plan; /workflow chains both.
---

# /execute — Execute, Validate

Run an **approved plan** to completion and verify it met its goal. Requires
`SPEC.md` (with an appended plan) under the run-state dir — produced by `/plan`.

## Operating rules
- Same Authority / Stance / no-narration / Conventions rules as `/plan`.
- **Never push.** Commit only when the human asks. One commit per subtask is
  owned by the builders — never add a manual commit on top.
- **Harness:** under Codex CLI, read Claude-specific tool mentions (`AskUserQuestion`,
  Agent tool / `subagent_type`, model names) per `${CLAUDE_PLUGIN_ROOT}/protocols/harness/codex.md`.

## Gates (run in order)

1. **Load run-state.** Resolve `BASE` per `state-persistence.md` § Run-state directory — the active pack's `projectStatePath` (from the `WORKFLOW_PACK:` line) when announced, else `${WORKFLOW_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/claude-workflow}`; `<key>` = given arg, else current branch. Read `$BASE/<key>/{SPEC,DECISIONS,PROGRESS}.md`. No approved plan in `SPEC.md` → stop and tell the human to run `/plan` first. Resuming a partial run → re-enter at the earliest unfinished step (see `${CLAUDE_PLUGIN_ROOT}/skills/workflow-resume/SKILL.md`).
2. **Execute.** Follow `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/execute.md`: one task per step, exactly one in-progress; dispatch `/build-and-review` per step (forward task + Goal + Acceptance criteria, plus `mode: inline` when the human approved inline). Inline mode → build the step yourself per `${CLAUDE_PLUGIN_ROOT}/protocols/invariants/inline-mode.md`. Handle reviewer verdicts per `${CLAUDE_PLUGIN_ROOT}/protocols/adversarial/verdict-handling.md`.
3. **Rewrite PROGRESS on every step transition.** Full rewrite, never appended (`state-persistence.md` § Write rules) — the engine bundles no enforcement hook, so this skill owns it.
4. **Validate.** Follow `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/validate.md`: run the test plan; run the project pack's `codeStyleAudit` if one is announced (else skip — no engine style rules); dispatch `plan-reviewer` `mode=output` to confirm the plan goal actually holds. One final PROGRESS rewrite with results.
5. **Turn audit.** Before claiming done, run `turn-reviewer` (`${CLAUDE_PLUGIN_ROOT}/skills/turn-review/SKILL.md`) over the turn's diff + conclusions; handle the verdict per `verdict-handling.md`.

## Done when
Every step completed, PROGRESS in-flight = `none`, Validate confirms the plan goal, no unresolved BLOCK.
