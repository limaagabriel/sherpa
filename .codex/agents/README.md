# Codex subagent roles

Codex resolves subagents from standalone TOML files — there is no plugin-manifest
pointer for them (unlike skills/hooks). Codex reads agent roles from:

- `.codex/agents/*.toml` — **project-scoped** (these files; active when Codex runs inside this repo)
- `~/.codex/agents/*.toml` — **user-global** (active in every repo)

One file per sherpa subagent, mirroring the plugin's `agents/*.md` (Claude Code
reads those automatically; Codex needs these TOMLs). Each file binds only the
**model tier + sandbox**; the full role lives in the plugin's `agents/<name>.md`.

## Install (for running sherpa under Codex on other repos)

```sh
mkdir -p ~/.codex/agents
cp /path/to/sherpa/.codex/agents/*.toml ~/.codex/agents/
```

(Or symlink them.) When you work *inside* this repo, the project-scoped copies
here are picked up with no install.

## Model tiers

| Role | Layer | Tier (Claude model) | `model` | `model_reasoning_effort` | sandbox |
|---|---|---|---|---|---|
| frame-reviewer | frame layer | deep (opus) | `gpt-6-astra` | `high` | read-only |
| structure-reviewer | shape layer | deep (opus) | `gpt-6-astra` | `high` | read-only |
| readiness-reviewer | shape layer | standard (sonnet) | `gpt-6.1-sol` | `high` | read-only |
| engineering-reviewer | shape layer | deep (opus) | `gpt-6-astra` | `high` | read-only |
| shape-contributor | shape layer | standard (sonnet) | `gpt-6.1-sol` | `high` | read-only |
| shape-builder | shape layer | deep (opus) | `gpt-6-astra` | `high` | read-only |
| step-builder | build layer | standard (sonnet) | `gpt-6.1-sol` | `high` | workspace-write |
| quality-reviewer | build layer | standard (sonnet) | `gpt-6.1-sol` | `high` | read-only |
| codebase-explorer | cross-cutting | standard (sonnet) | `gpt-6-luna` | `medium` | read-only |
| code-reviewer | review | standard (sonnet) | `gpt-6.1-sol` | `high` | read-only |
| analysis-reviewer | analyze layer | deep (opus) | `gpt-6-astra` | `high` | read-only |

Tiers: deep = `gpt-6-astra`, standard = `gpt-6.1-sol`, light = `gpt-6-luna`. The deep roles
(frame, structure, engineering and analysis reviewers, and the shape-builder) use Astra with high reasoning for
adversarial scrutiny. The standard roles use Sol with high reasoning, and the `sandbox` column
carries the write distinction: the sole `workspace-write` role, step-builder, is one of them. The
`read-only` codebase-explorer keeps its efficient discovery posture on Luna with medium reasoning.
On a ChatGPT plan without Astra, swap `gpt-6-astra` to `gpt-6.1-sol` in the role files. A role with `model`
omitted inherits the parent session model —
Codex fixes a subagent's model in its role file (no dispatch-time override),
so this mapping must live here.

## Handoff write exception

Read-only roles may write one file inside `HANDOFF` (see `protocols/handoff.md`): shape-contributor
and shape-builder hand off their output that way. Codex's read-only sandbox blocks that write, so
the agent falls back to returning its output inline.
