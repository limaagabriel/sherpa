# sherpa — agent instructions

sherpa is an opt-in **Discover → Analyze → Plan → Execute → Validate** workflow,
shipped as a plugin whose skills/protocols are authored in Claude Code's
vocabulary but run under **both Claude Code and Codex CLI**.

- Nothing runs until invoked: `/plan <task>`, `/execute`, `/workflow <task>`.
  Smaller blocks: `/scout`, `/build-and-review`, `/codegen-build`,
  `/adversarial-build`, `/turn-review`, `/workflow-resume`.
- **No execution without an approved plan.**

## Running under Codex CLI

Read every Claude-specific tool mention (the Agent tool, `subagent_type`,
`AskUserQuestion`, model names `haiku`/`sonnet`/`opus`) through the equivalence
table in **`protocols/harness/codex.md`**. The intent is identical; only the
mechanism differs. Key points:

- `AskUserQuestion` → ask **one numbered free-text question** and wait (Codex has
  no structured-question tool).
- "dispatch X via the Agent tool / `subagent_type: X`" → invoke the Codex agent
  role **X** from `.codex/agents/X.toml` (install per `.codex/agents/README.md`).
- Per-subagent model lives in those role TOMLs; `${CLAUDE_PLUGIN_ROOT}` and the
  SessionStart pack hook work under Codex unchanged.
