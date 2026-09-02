---
name: my-project-init
description: <Project> rules and conventions for the workflow engine. Optional — invoke it from the pack's `context` when the project is detected. Extends the engine's profile/stance/conventions; lists topic docs to load on demand.
---

# <Project> rules

These rules apply when the cwd / target / branch lives in a <Project> codebase.

## Profile extension
- **Stack:** <languages / frameworks>
- **Team:** <team>

## Stance extension
- <project-specific stance, e.g. "default to no new pattern; replicate the
  closest existing one">

## Conventions extension
- <coding standards the project enforces>
- <precedent rules>

## Workflow extension
- <how Build/Execute changes for this project — e.g. codegen pairing, formatting
  as a per-step step-builder action>

## Style (consumed by the engine via the announcement)
- **`implement.codeStyle`:** the fixed convention path `implement/codeStyle.md` (or a same-named directory of files), resolved lazily via `scripts/resolve-pack-value.sh <configPath> implement.codeStyle` against the config's base directory; a missing path is warned to stderr and resolves to nothing. The `step-builder` conforms its output to the resolved prose, and the `quality-reviewer` cites rules from it when announced.
- **`implement.review`:** the fixed convention path `implement/review.md` (or a same-named directory of files), resolved the same lazy way. Resolved by the `/implement` driver itself, right before dispatching each step's reviewer(s) — not by any subagent — and its plain-English instructions shape which reviewer(s) run and what extra they check.
- **`context` / `frame.context` / `shape.context` / `implement.context`:** each is a fixed convention path (`context.md`, `frame/context.md`, `shape/context.md`, `implement/context.md`, or a same-named directory of files), resolved the same lazy way. `context` is resolved immediately before each layer's dispatch, then forwarded to that layer's subagent(s) unchanged; the layer-specific keys are additive alongside it. Subagents cannot Read files or invoke a Skill to obtain this input — the prose is delivered directly.
- Absent → reviewers fall back to the file's language conventions + in-file/module precedent (`style — language-convention fallback`) — never skipped outright.

## Topic breadcrumbs (load on demand, don't pre-read)
| When you… | Read |
|---|---|
| <trigger> | `<path/to/topic.md>` |
