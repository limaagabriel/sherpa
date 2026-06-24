---
name: codegen-build
description: Cheapest build path — delegates one codegen subtask (typically running an auto-gen/codegen command) to the haiku `codegen-builder`, landing exactly one commit. No breaker, no review — the caller owns review. Dispatched by /build-and-review for catalog-matched (codegen-tier) subtasks; also invokable standalone. Args - <task-or-brief>, plus orchestrated context when called by build-and-review.
---

**Build-Id note:** Follow `protocols/invariants/build-id.md` — your single commit must carry it.

## What this is

The codegen tier (`protocols/invariants/tiering-catalog.md`): work is **running a deterministic code generator** whose output the generator owns. No design judgment → no spec to attack, no precedent to find. Hands work to a haiku worker and gets out of the way.

**Does NOT review.** Verify + turn-reviewer run downstream, owned by `/build-and-review` (or the always-on Stop-hook turn-reviewer for standalone calls).

## Arguments

- `<task-or-brief>` (required): a brief file **path** when dispatched by build-and-review; a task string when standalone.
- Orchestrated context (from build-and-review; self-generate when standalone):
  - `BUILD ID` + subtask index `<n>`
  - `PRE-EXISTING DIRT` snapshot
  - `PRE-BUILD BASE` SHA
  - handoff path `handoffs/<BUILD ID>.<n>.md`

## The loop

### Prep (standalone only)

`git status --short` → `PRE-EXISTING DIRT`; `git rev-parse HEAD` → `PRE-BUILD BASE`; `scripts/build-id.sh` → `BUILD ID`, `<n> = 1`; `scripts/build-notes.sh init` → repo-local notes config. When build-and-review supplies context, use it verbatim — never regenerate the `BUILD ID`.

### Build

Dispatch `codegen-builder` (`model: haiku`). Pass: brief path (or task string), `PRE-EXISTING DIRT`, `BUILD ID`, `<n>`, handoff path.

Builder runs the generator, stages only its own output, commits once with a builder-authored subject + Build-Id note, writes OUTPUT CONTRACT to the handoff, returns handoff path + `BUILD OK <SHA>` / `BUILD FAILED <reason>`.

### Re-tier guard (no fix loop)

No breaker, no fix loop. Two outcomes only:
- `BUILD OK` → Deliver.
- `BUILD FAILED` or re-tier signal in handoff DECISIONS (generator errored; work needed hand-authoring; output half-applied) → **stop and surface it** — this subtask was mis-tiered. When orchestrated, return failure to build-and-review for re-route to `/adversarial-build`. When standalone, report to user. Never patch generator output by hand to force a pass.

### Deliver

One commit, Build-Id noted. Leave history as-is — no squash, no reword, no push. PRE-EXISTING DIRT stays untouched. Summary (1 sentence): which generator ran, the commit subject. Review happens downstream.
