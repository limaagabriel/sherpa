# sherpa — agent instructions

sherpa is the plugin behind this repo: three composable, opt-in skills, authored in Claude
Code's vocabulary but run under **Claude Code, Codex CLI, and pi**. The user composes the
workflow; sherpa offers the tools.

- **`/frame <task>`** (frame) — scout + bind a problem statement, ask questions as they arise.
- **`/shape <task>`** (shape) — skeleton + critique a candidate, fan out only on `EXPAND`, plan
  the approved one.
- **`/implement <task>`** (build) — build the plan (or the task as one implicit step), one
  reviewed step at a time.
- **Nothing persists unless asked** — `/persist` writes the in-context frame, proposal, or plan to
  disk; there is no automatic run-state.

## Versioning

Bump the plugin version on every new commit to `main`. CI enforces lockstep across four files,
five fields — `package.json` (`.version`), `.claude-plugin/plugin.json` (`.version`),
`.codex-plugin/plugin.json` (`.version`), and `.claude-plugin/marketplace.json` (both
`.metadata.version` and `.plugins[0].version`) — must all carry the **same** version string. See
`.github/workflows/ci.yml`.

## Running under Codex CLI

Read every Claude-specific tool mention (the Agent tool, `subagent_type`, `AskUserQuestion`,
model names) through the equivalence table in **`protocols/harness/codex.md`** — the intent is
identical, only the mechanism differs.

## Running under pi

Read every Claude-specific tool mention through the equivalence table in
**`protocols/harness/pi.md`**; pi gets a working bridge from `.pi/extensions/sherpa.ts`.

## Editing agents

Rule text shared across skills or agents (Authority, Questions, the read-only Bash allowlist, the
reviewer verdict shape, etc.) lives once in **`protocols/shared-rules.md`**, stamped into each
target file between `<!-- shared:<block> -->` / `<!-- /shared -->` markers. Editing shared rule
content means editing `protocols/shared-rules.md`, then re-running
`bash scripts/inline-shared-rules.sh`. Editing role-specific content — anything outside the marker
regions — means editing the `agents/*.md` file directly, then running
`bash scripts/generate-agent-twins.sh`. Run both generators after any `agents/*.md` edit, since
either kind of change can land there: `bash scripts/inline-shared-rules.sh` first (in case a
marker moved or content drifted), then `bash scripts/generate-agent-twins.sh` to refresh the
`.codex/agents`/`.pi/agents` twins, and commit the regenerated twins alongside it.
