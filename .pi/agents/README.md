# pi subagent roles

These eight `*.md` files are sherpa's roles as **pi-subagents agents**. The
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
| frame-reviewer | `agents/frame-reviewer.md` | read, grep, find, ls, bash | high |
| shape-builder | `agents/shape-builder.md` | read, grep, find, ls, bash | low |
| shape-reviewer | `agents/shape-reviewer.md` | read, grep, find, ls, bash | high |
| structure-reviewer | `agents/structure-reviewer.md` | read, grep, find, ls, bash | medium |
| readiness-reviewer | `agents/readiness-reviewer.md` | read, grep, find, ls, bash | low |
| step-builder | `agents/step-builder.md` | read, grep, find, ls, bash, edit, write | low |
| acceptance-reviewer | `agents/acceptance-reviewer.md` | read, grep, find, ls, bash | low |
| quality-reviewer | `agents/quality-reviewer.md` | read, grep, find, ls, bash | low |
| scout | `agents/scout.md` | read, grep, find, ls, bash | low |

The `tools` column carries the write distinction: `step-builder` holds `edit, write`; no other
role does. Among the read-only roles, `scout` and `shape-builder` are workers; the rest are
reviewers. Each shim resolves
the package root via `$SHERPA_PLUGIN_ROOT` (exported
by `.pi/extensions/sherpa.ts`), else the concrete pi install roots
`~/.pi/agent/npm/node_modules/sherpa` or `~/.pi/agent/git/*/*/sherpa`.
