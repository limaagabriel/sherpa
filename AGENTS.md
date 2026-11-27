# sherpa — agent instructions

sherpa is the plugin behind this repo: composable, opt-in skills, authored in Claude
Code's vocabulary but run under **Claude Code, Codex CLI, and pi**. The user composes the
workflow; sherpa offers the tools.

- **`/frame <task>`** (frame) — scout + bind a problem statement, ask questions as they arise.
- **`/shape <task>`** (shape) — draft the plan directly, then critique it three ways before you
  approve it.
- **`/implement <task>`** (build) — build the plan (or the task as one implicit step), one
  reviewed step at a time.
- **Nothing in the repo unless asked** — `/persist` writes the in-context frame or plan into
  the repo (`.sherpa/` by default); there is no automatic run-state. Temp handoff files outside
  the repo are allowed (`protocols/handoff.md`), and the inventory keeps ticket state under
  `~/.config/sherpa/inventory` only when you run it.
- **`/analyze <branch or PR>`** — Pre-review analysis of changes; the report opens with a short
  context briefing, then lens findings checked by `analysis-reviewer`, plus a verdict.
- **`/triage <PR>`** — categorizes all PR review feedback and flags lessons for
  AGENTS.md.
- **`/restory`** — rewrites the current branch's commits into a clean, reviewable sequence.
- **`/invoke <name|path> [args]`** — runs a pack skill or any markdown file as a skill; no args
  lists them.
- **`sherpa init` / `sherpa loop <project>`** (inventory) — opt-in ticket board under
  `~/.config/sherpa/inventory/<project>/`; the loop runs each ticket's next stage headless and parks
  it at every gate. See README "Inventory".

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

Rule text shared across skills or agents (Authority, Questions, the read-only Bash rule, the
reviewer verdict shape, etc.) lives once in **`protocols/shared-rules.md`**, stamped into each
target file between `<!-- shared:<block> -->` / `<!-- /shared -->` markers. Editing shared rule
content means editing `protocols/shared-rules.md`, then re-running
`bash scripts/agents/build-rules.sh`. Editing role-specific content — anything outside the marker
regions — means editing the `agents/*.md` file directly, then running
`bash scripts/agents/build-twins.sh`. Run both generators after any `agents/*.md` edit, since
either kind of change can land there: `bash scripts/agents/build-rules.sh` first (in case a
marker moved or content drifted), then `bash scripts/agents/build-twins.sh` to refresh the
`.codex/agents`/`.pi/agents` twins, and commit the regenerated twins alongside it.
