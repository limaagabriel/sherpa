---
name: workflow-resume
description: Manually resume an interrupted Discover→Validate workflow run from its persisted SPEC/DECISIONS/PROGRESS state.
Layer: cross-cutting
---

## Arguments

- `<key>` (optional): run-state key identifying which workflow run to resume. Defined by CLAUDE.md State-persistence. Defaults to `git branch --show-current`.

---

## Run-dir resolution

1. If `<key>` supplied, use it directly.
2. Else `<key>` = `git branch --show-current`.
3. If result is empty (detached HEAD or non-git) AND no `<key>` given — list subdirectories of the resolved `BASE` (per `state-persistence.md` § Run-state directory: pack `projectStatePath` → `WORKFLOW_STATE_DIR` → `${XDG_STATE_HOME:-$HOME/.local/state}/claude-workflow`) and ask the user which run to resume before proceeding.

---

## Absent-state stop

If the resolved run directory does not exist, report `no run state` for `<key>` and stop. Do not start a fresh workflow.

---

## Resume report

Read whichever of `SPEC.md`, `DECISIONS.md`, `PROGRESS.md` are present and surface:

- **Goal** — from `SPEC.md`
- **Supersedes** — if `SPEC.md`'s first line is `Supersedes: archive/<NNN>-<slug>`, surface it (follow-up plan; named archive holds prior plan's decisions, read on demand). Absent on a first plan.
- **Archived plans** — count immediate `archive/<NNN>-*` subdirs (not recursive; `0` when absent). Report as `<N> stored under archive/ (reference only)`. Contents are NOT read for routing.
- **Decisions so far** — from `DECISIONS.md`
- **Step list** — from `PROGRESS.md`: each step with status, in-flight index, next steps, any `block reason`

---

## Resume ladder

Re-enter at the earliest phase whose inputs are not yet persisted.

### SPEC.md absent
Interrupted mid-Discover before clock-out — report `unsafe to resume` and let the user decide whether to restart from scratch.

### SPEC.md present
Skip Discover (all three sub-phases). Continue down:

### DECISIONS.md absent (SPEC present)
Re-enter at `Analyze` and proceed through Plan.

### DECISIONS.md present
Skip Analyze and Plan (`DECISIONS.md` is written at Plan approval, which follows both). Continue down:

### PROGRESS.md absent (DECISIONS present)
`PROGRESS.md` is first written on the first `TaskUpdate` flip — its absence means Execute may have partially started. WARN the user to `check git log` for partial commits, then re-enter Execute at step 1, restating the plan from `DECISIONS.md`.

### PROGRESS.md present

Rebuild the in-memory task list from `PROGRESS.md`: issue `TaskCreate` for each step (in order), then `TaskUpdate` for each to restore its status (`completed`, `in_progress`, `pending`). This is a READ driving in-memory harness calls only — does NOT write `PROGRESS.md`. Then proceed to Execute re-entry.

Read the in-flight index:
- All steps `completed` → route to `Validate`.
- In-flight index is `none` (mid-Execute between steps) → re-enter Execute at the first not-completed step.
- Otherwise → re-enter Execute at the in-flight step.

If a `block reason` is recorded, surface it verbatim and WAIT for the user — do not auto-continue past a block.

### Validate discriminator

An all-`completed` `PROGRESS.md` may be Execute-just-finished or Validate-interrupted. If `PROGRESS.md` contains a test-results section the run was mid-Validate; either way route to `Validate` — re-entry is idempotent.

---

## Manual-only

Never auto-fired by any hook. No hook may trigger it automatically.
