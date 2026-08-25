# sherpa — agent instructions

sherpa is a set of **composable, opt-in skills** — one per layer — shipped as a
plugin whose skills/protocols are authored in Claude Code's vocabulary but run
under **both Claude Code and Codex CLI**. The user composes the workflow; sherpa
offers the tools.

- Three layers, three entry points (pick by task complexity):
  `/frame <task>` (macro — scout + bind a problem contract), `/shape <task>` (shape —
  fan out directions, pick one, then plan the steps), `/implement <task>` (build).
  Smaller block: `/scout`.
- Each skill is a standalone entry point: it consumes the upstream artifact if it's
  in context, else does the minimum to proceed — never re-running the layer above.
- **Nothing persists unless asked** — `/persist` writes the in-context frame, pitch,
  or plan to disk; there is no automatic run-state.
- See `protocols/layers.md` for the layer/skill/reviewer binding.

## Versioning

Bump the plugin version on every new commit to `main`. CI enforces lockstep across
four files, five fields — `package.json` (`.version`), `.claude-plugin/plugin.json`
(`.version`), `.codex-plugin/plugin.json` (`.version`), and
`.claude-plugin/marketplace.json` (both `.metadata.version` and `.plugins[0].version`)
— must all carry the **same** version string. See `.github/workflows/ci.yml`.

## Running under Codex CLI

Read every Claude-specific tool mention (the Agent tool, `subagent_type`,
`AskUserQuestion`, model names `haiku`/`sonnet`/`opus`) through the equivalence
table in **`protocols/harness/codex.md`**. The intent is identical; only the
mechanism differs. Key points:

- `AskUserQuestion` → ask **one numbered free-text question**, preamble included
  and each option's consequence clause carried, and wait (Codex has no
  structured-question tool).
- "dispatch X via the Agent tool / `subagent_type: X`" → invoke the Codex agent
  role **X** from `.codex/agents/X.toml` (install per `.codex/agents/README.md`).
- Per-subagent model lives in those role TOMLs; `${CLAUDE_PLUGIN_ROOT}` and the
  SessionStart pack hook work under Codex unchanged.

## Running under pi

pi gets a working bridge by active injection from `.pi/extensions/sherpa.ts`; this
section is the human-facing pointer. Read the Claude-specific tool mentions
through the equivalence table in **`protocols/harness/pi.md`** — the intent is
identical; only the mechanism differs. Key points:

- `ask_user_question` (rpiv) maps to `AskUserQuestion` **1:1** — a structured
  equivalent, used directly (numbered free-text only when that tool is absent,
  preamble and each option's consequence clause included either way).
- "dispatch X via the Agent tool / `subagent_type: X`" → dispatch the role **X**
  through **pi-subagents** (registered from `.pi/agents/X.md`; see
  `.pi/agents/README.md`).
- pi-subagents is **required for full fidelity**; when it is absent, sherpa
  degrades gracefully — the role's work runs inline, never faked.
