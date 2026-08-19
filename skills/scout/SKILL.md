---
name: scout
description: "Scout the codebase for a Discover record (landmarks, precedent, constraints, tests, gaps, confidence). Args - <task> [TARGET_DIR] [breadth: quick|medium|very thorough]. Returns the record."
---

Gathers codebase intelligence via a read-only `scout` subagent. Single responsibility: **scout**. Caller consumes the returned record for clarification and planning.

## Inputs

- `TASK` (required) — what the downstream work will do (so the scout knows what precedent/constraints matter).
- `TARGET_DIR` — absolute path to scout. Default: current working directory.
- `FOCUS` — optional subsystems/files/questions to prioritize.
- `BREADTH` — `quick` (local change) → 1 scout dispatch; `medium` / `very thorough` (cross-cutting) → up to 2. Default `medium`.

## Procedure

Dispatch the read-only **`scout`** agent (`subagent_type: "scout"`) — one role resolved across all harnesses (Claude Code by convention; Codex via `.codex/agents/scout.toml`; pi via `.pi/agents/scout.md`), briefed with `TASK` / `TARGET_DIR` / `FOCUS`. The scout agent owns the Discover-record contract (see `agents/scout.md`).

Read-only. The subagent never edits. Breadth drives dispatch count: `quick` → 1; `medium` / `very thorough` → up to 2 (split by subsystem when surface is cross-cutting).

## Output

Compact markdown — the Discover-record `Scout` payload the caller drops into its brief. The
Discover-record fields the scout agent owns — see `agents/scout.md` § Output for the contract
(`landmarks`, `precedent`, `constraints`, `tests`, `gaps`, `confidence`).

Nothing else — no preamble.
