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
- **codeStyleRules:** a file path or array of file paths; resolved lazily via `scripts/resolve-pack-value.sh` against the config's base directory, missing files warned and skipped per-entry. The `step-builder` conforms its output to the resolved prose, and the `quality-reviewer` cites rules from it when announced.
- **knowledge:** a file path or array of file paths; resolved lazily via `scripts/resolve-pack-value.sh` against the config's base directory, missing files warned and skipped per-entry. Resolved immediately before each layer's dispatch, then forwarded to that layer's subagent(s) unchanged. Subagents cannot Read files or invoke a Skill to obtain this input — the prose is delivered directly.
- Absent → reviewers fall back to the file's language conventions + in-file/module precedent (`style — language-convention fallback`) — never skipped outright.

## Topic breadcrumbs (load on demand, don't pre-read)
| When you… | Read |
|---|---|
| <trigger> | `<path/to/topic.md>` |
