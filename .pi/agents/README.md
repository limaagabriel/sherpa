# pi subagent roles

These eleven `*.md` files are sherpa's roles as **pi-subagents agents**. The
package manifest declares `pi.subagents.agents: ["./.pi/agents"]`, so
pi-subagents **auto-registers** them on load — no manual copy or symlink. Each
shim is a thin pointer: its body resolves the sherpa package root and reads the
canonical role from `<root>/agents/<name>.md`, mirroring the `.codex/agents/*.toml`
shims. No role body is duplicated here.

## pi-subagents requirement and degradation

pi-subagents is **required for full-fidelity multi-agent operation** — the
dispatcher resolves these named roles through it. When pi-subagents is absent,
degrade gracefully, mirroring superpowers: run the role's work inline in the main
thread, or state the gap plainly. **Never fabricate dispatch** — do not claim a
subagent ran when none did.

## Roles and tiers

Each shim points at its canonical `agents/<name>.md` and carries a `thinking`
tier mirroring the Codex `model_reasoning_effort` gradient — read from each
role's own `piThinking` frontmatter field, so this table always mirrors it.

| Role | Canonical body | tools | `thinking` |
|---|---|---|---|
| frame-reviewer | `agents/frame-reviewer.md` | read, grep, find, ls, bash, write | high |
| structure-reviewer | `agents/structure-reviewer.md` | read, grep, find, ls, bash, write | high |
| readiness-reviewer | `agents/readiness-reviewer.md` | read, grep, find, ls, bash, write | high |
| engineering-reviewer | `agents/engineering-reviewer.md` | read, grep, find, ls, bash, write | high |
| shape-contributor | `agents/shape-contributor.md` | read, grep, find, ls, bash, write | high |
| shape-builder | `agents/shape-builder.md` | read, grep, find, ls, bash, write | high |
| step-builder | `agents/step-builder.md` | read, grep, find, ls, bash, edit, write | high |
| quality-reviewer | `agents/quality-reviewer.md` | read, grep, find, ls, bash, write | high |
| codebase-explorer | `agents/codebase-explorer.md` | read, grep, find, ls, bash, write | medium |
| code-reviewer | `agents/code-reviewer.md` | read, grep, find, ls, bash, write | high |
| analysis-reviewer | `agents/analysis-reviewer.md` | read, grep, find, ls, bash, write | high |

The `tools` column carries the write distinction: only `step-builder` holds `edit`. Every other
role holds `write` for the handoff exception alone: it may write only inside `HANDOFF` (see
`protocols/handoff.md`); pi does not enforce it, so the agent must. Among the read-only roles,
`codebase-explorer`, `shape-contributor` and `shape-builder` are workers; the rest are reviewers.
Each shim resolves
the package root via `$SHERPA_PLUGIN_ROOT` (exported
by `.pi/extensions/sherpa.ts`), else the concrete pi install roots
`~/.pi/agent/npm/node_modules/sherpa` or `~/.pi/agent/git/*/*/sherpa`.
