# Sherpa

A [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) plugin:
**composable skills** — one per layer of altitude, `/frame` (frame), `/shape` (shape),
`/implement` (build) — plus `/persist` and the independently invokable `/review`, `/triage`, and
`/restory` — with bundled codebase-explorer, step-builder, code-reviewer, engineering-reviewer, and
reviewer subagents that rope up and check the rope at every stage.

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
| `/shape <task>` | Drafts the plan directly — step budget stated up front — then gets it critiqued three ways (structure, readiness, engineering) in parallel, and waits for your one approval. | the problem's framed (or clear enough) |
| `/implement <task>` | Build each step (step-builder + quality reviewer), with pressure per step. | it's one obvious change |
| `/persist` | Write the in-context frame or plan to disk so a later session can resume. | you want to save or resume |
| `/review` | Multi-perspective, read-only review of a branch's changes or a GitHub PR; reports findings plus a verdict. | you want a pre-PR or pre-merge second opinion |
| `/triage` | Categorize unresolved GitHub PR review comments (makes sense / questionable / push back / needs clarification), flag lessons for AGENTS.md. | you got PR feedback and want to sort it before acting |
| `/restory` | Rewrite the current branch's messy commits into a clean, logical sequence; same end tree, fewer/better commits. | your branch history needs tidying before a PR |

Each skill is a standalone entry point: it uses the upstream artifact if it's in context, else
does the minimum to proceed — never re-running the layer above.

```
/frame add rate limiting to the public API   # fuzzy → frame it first
   → scouts, asks a few questions, presents a frame
/shape                                       # draft the plan directly
   → critiques it three ways, then presents the plan, waits for your approval
/implement                                   # build them, reviewed per step
```

…or just `/implement bump the copyright year` for a one-liner.

## How it works

`/frame` scouts, binds a problem statement, and asks questions as they arise; `frame-reviewer`
attacks the framing. `/shape` drafts the plan directly, then gets it attacked in parallel by
`structure-reviewer` (how the steps relate), `readiness-reviewer` (each step's own contract), and
`engineering-reviewer` (plan-level engineering quality) — a gap only you can close waits on you
(human gate 1) — before presenting the plan and waiting for **your explicit approval (human
gate 2)**, the one gate every run hits. `/implement` then builds one step at a time:
`step-builder` commits, then `quality-reviewer` checks it against both quality and its acceptance
criteria. A `BLOCK` or a terminal `UNMET`/`FIX` surfaces to you verbatim; everything else continues
automatically.

## Project packs (optional)

The engine ships generic. To layer in your project's conventions, commit
`<repo>/.sherpa/project.yaml` (project-local) or drop one directory per project under a shared
workspace dir. `project.yaml` carries metadata only (`name`, `detect`); every content-bearing
value — `session.md` (injected at session start), `context.md` (forwarded to every subagent, at
the root and per layer) — is a fixed convention path next to it, resolved by one call:
`bash scripts/resolve-pack-value.sh <configPath> [frame|shape|implement|review]`. Sherpa's single
`SessionStart` hook scans for a matching config and announces the active pack automatically. Full
schema and resolution rules: `packs/README.md`.

## Components

- **`/frame`** (frame) — scout + bind a problem statement; `frame-reviewer` gives it cold eyes.
- **`/shape`** (shape) — drafts the plan directly; `structure-reviewer`, `readiness-reviewer`,
  and `engineering-reviewer` critique it in parallel.
- **`/implement`** (build) — runs approved steps; `step-builder` builds and commits each one,
  `quality-reviewer` checks it.
- **`codebase-explorer`** / **`/persist`** — cross-cutting: codebase discovery (dispatched directly by
  `/frame` and `/shape`, not a standalone skill), and opt-in disk persistence.
- **`/review`** — multi-perspective, read-only review of a branch's changes or a GitHub PR;
  `code-reviewer` does the independent, isolated look and reports a verdict.
- **`/triage`** — categorizes unresolved GitHub PR review comments and flags lessons for AGENTS.md;
  strictly analytical, never edits code or replies on the PR.
- **`/restory`** — rewrites the current branch's commits into a clean, reviewable sequence; pure
  git, never pushes.

## Layout

```
skills/        /frame, /shape, /implement, /persist, /review, /triage, /restory, using-sherpa
agents/        codebase-explorer, frame-reviewer, structure-reviewer, readiness-reviewer, engineering-reviewer, step-builder, quality-reviewer, code-reviewer
protocols/harness/  Codex CLI and pi harness equivalence tables
packs/         project-pack template + docs
hooks/         the single SessionStart pack resolver
scripts/       pack resolution + CI helper scripts
```

## License

MIT
