---
name: scout
description: Scout the codebase — dispatch subgents to gather a Discover record (landmarks, precedent, constraints, tests, gaps, confidence). Args - <task> [TARGET_DIR] [breadth: quick|medium|very thorough]. Returns the record.
Layer: macro
---

Gathers codebase intelligence via a read-only Explore subagent. Single responsibility: **scout**. Caller consumes the returned record for clarification and planning.

## Inputs

- `TASK` (required) — what the downstream work will do (so the scout knows what precedent/constraints matter).
- `TARGET_DIR` — absolute path to scout. Default: current working directory.
- `FOCUS` — optional subsystems/files/questions to prioritize.
- `BREADTH` — `quick` (local change) → 1 Explore dispatch; `medium` / `very thorough` (cross-cutting) → up to 2. Default `medium`.

## Procedure

Dispatch a read-only **explore** subagent (Claude Code: `subagent_type: "Explore"`; Codex: a read-only general/search agent — see `${CLAUDE_PLUGIN_ROOT}/protocols/harness/codex.md`), briefed with `TASK` / `TARGET_DIR` / `FOCUS`. Required to return:
- File:line landmarks for relevant entry points and existing patterns.
- Structured **precedent list** — array of `{file:line, what_it_exemplifies}`; `None found` is valid but needs justification.
- Constraints (configs, build files, schemas, validators, conventions) and existing tests with their framework.
- `gaps` list — questions the scout could not close.

Read-only. The subagent never edits. Breadth drives dispatch count: `quick` → 1; `medium` / `very thorough` → up to 2 (split by subsystem when surface is cross-cutting).

## Output

Compact markdown — the Discover-record `Scout` payload the caller drops into its brief:
- `landmarks` — `file:line` entry points and existing patterns.
- `precedent` — `file:line — what_it_exemplifies` per pattern (`None found` + justification allowed).
- `constraints` — configs, build files, schemas, validators, conventions.
- `tests` — existing tests with framework.
- `gaps` — questions left open.
- `confidence` — overall line, justified by coverage of the relevant surface.

Nothing else — no preamble.
