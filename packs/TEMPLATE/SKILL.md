---
name: my-project-init
description: <Project> rules and conventions for the workflow engine. Optional — invoke it from the pack's `sessionInstructions` when the project is detected. Extends the engine's profile/stance/conventions; lists topic docs to load on demand.
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
- **codeStyleRules:** a shell command that prints the complete rule set to stdout; the `step-builder` conforms its output to it and the `quality-reviewer` cites rules from its output when announced. Sherpa makes no assumption about how rules are stored.
- **knowledge:** always literal inline prose, at any length — resolved lazily via `yq` against the announced `configPath` immediately before each layer's dispatch, then forwarded to that layer's subagent(s) unchanged. Subagents cannot Read files or invoke a Skill to obtain this input, so a knowledge value can never point a subagent at something else to load — write the prose directly (to invoke this skill itself, use the pack's `sessionInstructions` instead, see the frontmatter `description` above).
- Absent → reviewers fall back to the file's language conventions + in-file/module precedent (`style — language-convention fallback`) — never skipped outright.

## Topic breadcrumbs (load on demand, don't pre-read)
| When you… | Read |
|---|---|
| <trigger> | `<path/to/topic.md>` |
