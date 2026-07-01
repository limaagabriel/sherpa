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
| step-builder | L3 build | standard (sonnet) | `gpt-5.5` | `minimal` | workspace-write |
| acceptance-reviewer | L3 build | standard (sonnet) | `gpt-5.5` | `medium` | read-only |
| quality-reviewer | L3 build | standard (sonnet) | `gpt-5.5` | `medium` | read-only |
| plan-reviewer | L2 step | standard (sonnet) | `gpt-5.5` | `medium` | read-only |
| spec-reviewer | L1 macro | deep (opus) | `gpt-5.5` | `high` | read-only |

The cheap/standard/deep gradient is carried by `model_reasoning_effort` on a
single `model`. A role with `model` omitted inherits the parent session model —
Codex fixes a subagent's model in its role file (no dispatch-time override), so
the tier intent must live here.
