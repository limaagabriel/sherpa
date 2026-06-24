# Harness equivalences — running sherpa under Codex CLI

sherpa's skills and protocols are written in Claude Code's vocabulary (the Agent
tool, `subagent_type`, `AskUserQuestion`, model names like `haiku`/`sonnet`/`opus`).
Under **Codex CLI** read every such mention through this table. The *intent* is
identical; only the mechanism differs.

| sherpa prose says | Claude Code | Codex CLI |
|---|---|---|
| "dispatch X via the Agent tool / `subagent_type: \"X\"`" | Agent tool, that subagent type | invoke the Codex agent role **X** (defined in `.codex/agents/X.toml`; install per `.codex/agents/README.md`) |
| "fresh `Agent` call", "stateless", "never `SendMessage`" | new Agent invocation each time | spawn a fresh Codex agent each time — never resume a prior one |
| the `Explore` scout subagent | `subagent_type: "Explore"` | a read-only general/search agent |
| `AskUserQuestion` | structured multiple-choice tool | Codex has **no** structured-question tool — ask **one numbered free-text question** listing the options (mark the recommended one), then wait for the reply. Same batching/serialization rules as the prose. |
| the `Skill` tool (main agent invokes a skill) | Skill tool | `/skills` (explicit) or implicit skill use. Subagents have no skill tool under either harness — they `Read` the `SKILL.md` by path, unchanged. |
| model `haiku` / `sonnet` / `opus` for a subagent | Agent frontmatter `model:` | the role's `.codex/agents/X.toml` (`model` + `model_reasoning_effort`); ignore the Claude model name |
| `${CLAUDE_PLUGIN_ROOT}` in a path or hook | set by Claude Code | **set by Codex too** (for compatibility) — paths and the SessionStart hook resolve unchanged |

## Notes

- **No structured questions.** Codex's only built-in user gate is approve/deny.
  Where a skill says `AskUserQuestion`, render the questions as a numbered list in
  one message and wait — do not fabricate a choice the user didn't make.
- **Agent roles are not plugin-registered.** Codex reads agent roles from
  `.codex/agents/*.toml` (project) or `~/.codex/agents/*.toml` (user), not from the
  plugin manifest — see `.codex/agents/README.md` to install them. A role's model
  is fixed in its file (no dispatch-time override), so the model tier lives there.
- **Hooks need trust.** Plugin-bundled hooks are non-managed; Codex skips them
  until the user reviews and trusts the hook — the same one-time step as Claude's
  `/hooks` trust prompt.
