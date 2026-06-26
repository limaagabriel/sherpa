---
name: my-project-init
description: <Project> rules and conventions for the workflow engine. Named by `initialize` in the project's pack YAML and invoked at session start (per its `sessionInstructions`) when the project is detected. Extends the engine's profile/stance/conventions; lists topic docs to load on demand.
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
  as a per-step builder action>

## Style & architecture (consumed by the engine via the announcement)
- **codeStyleRules:** a shell command that prints the complete rule set to stdout; the engine's reviewers run it and cite rules from its output when announced. Sherpa makes no assumption about how rules are stored.
- **codeStyleAudit:** the Validate phase runs this command for the exhaustive pass.
- **architectureRules:** a shell command that prints the project's architectural guidelines to stdout; sherpa runs it at the **plan** layer and forwards the output to `plan-reviewer`, which checks the proposed plan against it. Absent → that lens falls back to an advisory general-principle check (SRP / coupling / cyclic deps / leaky abstraction, WARN-tier).
- **initialize:** this skill itself — the main agent invokes it at session start; the orchestrator forwards its `SKILL.md` path to subagents (which `Read` it).
- If you announce neither style key, reviewers fall back to the file's language conventions + in-file/module precedent (`style — language-convention fallback`) — never skipped outright.

## Topic breadcrumbs (load on demand, don't pre-read)
| When you… | Read |
|---|---|
| <trigger> | `<path/to/topic.md>` |
