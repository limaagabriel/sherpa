# Harness equivalences — running sherpa under pi

sherpa's skills and protocols are written in Claude Code's vocabulary (the Agent
tool, `subagent_type`, `AskUserQuestion`, model names like `haiku`/`sonnet`/`opus`).
Under **pi** read every such mention through this table. The *intent* is
identical; only the mechanism differs.

| sherpa prose says | Claude Code | pi |
|---|---|---|
| "dispatch X via the Agent tool / `subagent_type: \"X\"`" | Agent tool, that subagent type | dispatch the role **X** through pi-subagents — the `subagent` tool or `/run X` (registered from `.pi/agents/X.md`; see `.pi/agents/README.md`) |
| "fresh `Agent` call", "stateless", "never `SendMessage`" | new Agent invocation each time | dispatch a fresh pi-subagents agent each time — never resume a prior one |
| the `Explore` scout subagent | `subagent_type: "Explore"` | a read-only general/search agent |
| `AskUserQuestion` | structured multiple-choice tool | `ask_user_question` (rpiv) — a 1:1 structured equivalent. Only if that tool is absent, ask **one numbered free-text question** listing the options (mark the recommended one), then wait. Same batching/serialization rules as the prose. |
| the `Skill` tool (main agent invokes a skill) | Skill tool | native pi skills — discovered via `resources_discover` (the extension registers `skills/`). Subagents have no skill tool under either harness — they `Read` the `SKILL.md` by path, unchanged. |
| model `haiku` / `sonnet` / `opus` for a subagent | Agent frontmatter `model:` | the role's `thinking` tier in `.pi/agents/X.md`; ignore the Claude model name — **no Claude model names exist under pi** |
| `${CLAUDE_PLUGIN_ROOT}` in a path or hook | set by Claude Code | `$SHERPA_PLUGIN_ROOT`, exported by `.pi/extensions/sherpa.ts` (derived from `import.meta.url`). If unset, resolve the package root from its install path |

## Notes

- **Structured questions are native.** pi's `ask_user_question` (rpiv) maps onto
  `AskUserQuestion` 1:1 — use it directly. The numbered free-text fallback applies
  only when that tool is unavailable; never fabricate a choice the user didn't make.
- **Subagent dispatch needs pi-subagents.** The manifest declares
  `pi.subagents.agents: ["./.pi/agents"]`, so the roles auto-register on load —
  see `.pi/agents/README.md`. When **pi-subagents is absent**, degrade gracefully:
  run the role's work inline in the main thread, or state the gap plainly. **Never
  fabricate dispatch** — do not claim a subagent ran when none did.
- **Plugin root resolution.** Each role shim and skill path resolves the package
  root via `$SHERPA_PLUGIN_ROOT` first, else the concrete pi install roots
  (`~/.pi/agent/npm/node_modules/sherpa` or `~/.pi/agent/git/*/*/sherpa`). The
  step-builder is the only writer; the four reviewers are read-only.
