---
name: my-project-init
description: <Project> rules and conventions for the workflow engine. Optional — invoke it from the pack's `sessionInstructions` (or from a `knowledge` prose line) when the project is detected. Extends the engine's profile/stance/conventions; lists topic docs to load on demand.
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
- **knowledge:** inline prose, forwarded verbatim to every layer and subagent — it may say "invoke Skill X" (e.g. this skill) if you want a skill loaded.
- Absent → reviewers fall back to the file's language conventions + in-file/module precedent (`style — language-convention fallback`) — never skipped outright.

## Topic breadcrumbs (load on demand, don't pre-read)
| When you… | Read |
|---|---|
| <trigger> | `<path/to/topic.md>` |
