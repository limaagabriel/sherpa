# pi subagent roles

These five `*.md` files are sherpa's roles as **pi-subagents agents**. The
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
tier mirroring the Codex `model_reasoning_effort` gradient.

| Role | Canonical body | tools | `thinking` |
|---|---|---|---|
| builder | `agents/builder.md` | read, grep, find, ls, bash, edit, write | low |
| acceptance-reviewer | `agents/acceptance-reviewer.md` | read, grep, find, ls, bash | low |
| quality-reviewer | `agents/quality-reviewer.md` | read, grep, find, ls, bash | low |
| plan-reviewer | `agents/plan-reviewer.md` | read, grep, find, ls, bash | medium |
| spec-reviewer | `agents/spec-reviewer.md` | read, grep, find, ls, bash | high |

The builder is the only writer (`edit, write`); the four reviewers are
read-only. Each shim resolves the package root via `$SHERPA_PLUGIN_ROOT` (exported
by `.pi/extensions/sherpa.ts`), else the concrete pi install roots
`~/.pi/agent/npm/node_modules/sherpa` or `~/.pi/agent/git/*/*/sherpa`.
