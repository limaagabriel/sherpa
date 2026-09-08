# Sherpa

A [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) plugin: three
**composable skills**, one per layer of altitude — `/frame` (frame), `/shape` (shape),
`/implement` (build) — with bundled scout, shape-builder, step-builder, and reviewer subagents
that rope up and check the rope at every stage.

Sherpa offers the tools; **you compose the workflow**. It's **opt-in** (nothing runs until you
call a skill), **lean** (nothing persists unless you call `/persist`), and **project-agnostic** —
your code style and extra reviewers plug in through a small YAML *pack*, so the engine never
hard-codes anything about your repo.

## Install

Requires `jq` and `yq` (v4+) on `PATH` for the SessionStart pack resolver — without `jq` the
hook stays silent; without `yq` it still loads but skips project packs.

Sherpa is a Claude Code plugin. From inside Claude Code:

```
/plugin marketplace add limaagabriel/sherpa
/plugin install sherpa@sherpa
```

Or point at a local clone:

```
git clone https://github.com/limaagabriel/sherpa.git
/plugin marketplace add /path/to/sherpa
/plugin install sherpa@sherpa
```

Then open `/hooks`, review and **trust** sherpa's `SessionStart` hook (it detects your project
pack), and start a new thread. Verify with `/frame` — if the skill shows up, you're set.

## Usage

| Skill | Does | Start here when |
|---|---|---|
| `/frame <task>` | Scout, bind a problem statement, ask questions as they arise, compose + present a frame, get a cold-eyes critique. | the task is fuzzy or has design calls |
| `/shape <task>` | Skeleton + critique a direct-approach candidate; fans out to a full candidate pool only when that critique returns `EXPAND`. Presents a proposal — step budget stated up front in it — and waits for your pick; once picked, plans ordered, traceable steps, critiques the plan, and waits for your one approval. | the problem's framed (or clear enough) |
| `/implement <task>` | Build each step (step-builder + acceptance + quality reviewers), with pressure per step. | it's one obvious change |
| `/scout <task>` | Standalone codebase scout; also called by `/frame` and `/shape`. | you just want a lay of the land |
| `/persist` | Write the in-context frame, proposal, or plan to disk so a later session can resume. | you want to save or resume |

Each skill is a standalone entry point: it uses the upstream artifact if it's in context, else
does the minimum to proceed — never re-running the layer above.

```
/frame add rate limiting to the public API   # fuzzy → frame it first
   → scouts, asks a few questions, presents a frame
/shape                                       # skeleton the direct approach, fan out only if it fails
   → presents a proposal, waits for your pick, then presents the plan, waits for your approval
/implement                                   # build them, reviewed per step
```

…or just `/implement bump the copyright year` for a one-liner.

## How it works

`/frame` scouts, binds a problem statement, and asks questions as they arise; `frame-reviewer`
attacks the framing. `/shape` skeletons a direct-approach candidate and critiques it via
`shape-reviewer`; only an `EXPAND` verdict pays for the full pooled fan-out. Once a candidate's
picked, it plans the steps and gets that plan attacked by `structure-reviewer` (how the steps
relate) and `readiness-reviewer` (each step's own contract), then presents the plan and waits:
**your approval is this run's one hard gate**. `/implement` then builds one step at a time:
`step-builder` commits, then `quality-reviewer` checks it against both quality and its acceptance
criteria. A `BLOCK` or a terminal `UNMET`/`FIX` surfaces to you verbatim; everything else continues
automatically.

## Project packs (optional)

The engine ships generic. To layer in your project's conventions, commit
`<repo>/.sherpa/project.yaml` (project-local) or drop one directory per project under a shared
workspace dir. `project.yaml` carries metadata only (`name`, `detect`); every content-bearing
value — `session.md` (injected at session start), `context.md` (forwarded to every subagent, at
the root and per layer) — is a fixed convention path next to it, resolved by one call:
`bash scripts/resolve-pack-value.sh <configPath> [frame|shape|implement]`. Sherpa's single
`SessionStart` hook scans for a matching config and announces the active pack automatically. Full
schema and resolution rules: `packs/README.md`.

## Components

- **`/frame`** (frame) — scout + bind a problem statement; `frame-reviewer` gives it cold eyes.
- **`/shape`** (shape) — skeletons + critiques a candidate, plans the approved one;
  `shape-builder` builds candidates, `shape-reviewer` critiques the pool,
  `structure-reviewer`/`readiness-reviewer` critique the plan.
- **`/implement`** (build) — runs approved steps; `step-builder` builds and commits each one,
  `quality-reviewer` checks it.
- **`/scout`** / **`/persist`** — cross-cutting: codebase discovery, and opt-in disk persistence.

## Layout

```
skills/        /frame, /shape, /implement, /scout, /persist, using-sherpa
agents/        scout, frame-reviewer, shape-builder, shape-reviewer, structure-reviewer, readiness-reviewer, step-builder, quality-reviewer
protocols/harness/  Codex CLI and pi harness equivalence tables
packs/         project-pack template + docs
hooks/         the single SessionStart pack resolver
scripts/       pack resolution + CI helper scripts
```

## License

MIT
