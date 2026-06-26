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

| Role | Tier (Claude model) | `model` | `model_reasoning_effort` | sandbox |
|---|---|---|---|---|
| codegen-builder | cheap (haiku) | `gpt-5.5` | `minimal` | workspace-write |
| adversarial-builder | standard (sonnet) | `gpt-5.5` | `medium` | workspace-write |
| adversarial-drafter | standard (sonnet) | `gpt-5.5` | `medium` | workspace-write |
| task-reviewer | standard (sonnet) | `gpt-5.5` | `medium` | read-only |
| turn-reviewer | standard (sonnet) | `gpt-5.5` | `medium` | read-only |
| adversarial-breaker | deep (opus) | `gpt-5.5` | `high` | read-only |
| plan-reviewer | deep (opus) | `gpt-5.5` | `high` | read-only |

The cheap/standard/deep gradient is carried by `model_reasoning_effort` on a
single `model`. Swap `codegen-builder`'s `model` to a faster Codex model (e.g. a
Codex-Spark variant) if you have access and want it cheaper. A role with `model`
omitted inherits the parent session model — Codex fixes a subagent's model in its
role file (no dispatch-time override), so the tier intent must live here.
