---
name: execute
description: Drive the Execute -> Validate half of the workflow against an approved plan — read SPEC/DECISIONS/PROGRESS, gate the decomposition once (step-reviewer), build each step (one builder + acceptance/quality reviewers), then validate the plan goal (plan-reviewer). Triggers - "/execute", "/execute <key>", "execute the plan". Requires a plan from /plan; /workflow chains both.
---

# /execute — Execute, Validate

Run an **approved plan** to completion and verify it met its goal. Requires `SPEC.md` (with an appended plan) under the run-state dir — produced by `/plan`.

## Operating rules
- Same Authority / Stance / no-narration / Conventions rules as `/plan`.
- **Never push.** Commit only when the human asks. The builder owns one commit per step — never add a manual commit on top.
- **Harness:** under Codex CLI, read Claude-specific tool mentions per `${CLAUDE_PLUGIN_ROOT}/protocols/harness/codex.md`.

## Gates (run in order)

1. **Load run-state.** Resolve `BASE` per `state-persistence.md` § Run-state directory; `<key>` = given arg, else current branch. Read `$BASE/<key>/{SPEC,DECISIONS,PROGRESS}.md`. No approved plan → stop, tell the human to run `/plan`. Resuming a partial run → re-enter at the earliest unfinished step (see `${CLAUDE_PLUGIN_ROOT}/skills/workflow-resume/SKILL.md`).
2. **Step gate (L2, once).** Dispatch `step-reviewer` over the full step list + plan goal + `SPEC.md` path. `DECOMPOSITION: INCOMPLETE` → surface to the human (BLOCK); do not start building until resolved.
3. **Execute (L3).** Follow `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/execute.md`: one task per step, exactly one in-progress. Per step:
   - **Model rule:** is this step pure automated codegen — run a generator, commit its output, no hand-written logic? → dispatch `builder` at model **haiku**. Otherwise → default model.
   - Dispatch `builder` with `task` + `Goal` + `Acceptance criteria` + `PRE-EXISTING DIRT` + pack `codeStyleRules`/`initialize` path (when announced).
   - On `BUILT`, run the two L3 reviewers in parallel over the step's commit range: `acceptance-reviewer` (plan perspective — pass the acceptance criteria; emits `ACCEPTANCE: MET/UNMET`) and `quality-reviewer` (quality perspective — emits `QUALITY: PASS/WARN/FIX/BLOCK`). A project pack may add extra `reviewers` alongside these two.
   - **Verdict rule:** `ACCEPTANCE: UNMET` or a mechanical quality FIX → relay to the builder to fold into its commit, then re-check once; PASS / WARN → next step. BLOCK, `UNVERIFIABLE`, or an unresolved finding → stop, wait for the human.
4. **Rewrite PROGRESS on every step transition.** Full rewrite, never appended (`state-persistence.md` § Write rules).
5. **Validate.** Follow `${CLAUDE_PLUGIN_ROOT}/protocols/workflow/phases/validate.md`: run the test plan; run the pack's `codeStyleAudit` if announced (else skip); dispatch `plan-reviewer mode=output` to confirm the plan goal holds. One final PROGRESS rewrite.

## Done when
Every step completed, PROGRESS in-flight = `none`, Validate confirms the plan goal, no unresolved BLOCK.
