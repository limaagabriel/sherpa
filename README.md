# Sherpa

Sherpa is a [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) plugin made of skills.
You call them one at a time.

The three main skills work in order:

- `/frame` understands the problem and states it clearly.
- `/shape` writes a step-by-step plan and gets it reviewed.
- `/implement` builds the plan, one reviewed step at a time.

Other skills: `/persist`, `/analyze`, `/triage`, `/restory`, and `/invoke`.

Sherpa also bundles helper agents: codebase-explorer, step-builder, code-reviewer, analysis-reviewer, engineering-reviewer, and the reviewers.

Sherpa offers the tools. You decide the workflow. It is opt-in: nothing runs until you call a skill.
It keeps nothing on disk unless you call `/persist`. Your project's rules go in an optional YAML file
called a "pack", so the core stays general and knows nothing about your repo.

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
| `/analyze` | Pre-review analysis of a branch's changes or a GitHub PR; opens with a short context briefing, then lens findings checked by `analysis-reviewer`, plus a verdict. | you want a pre-PR or pre-merge second opinion |
| `/triage` | Categorize all PR review feedback (makes sense / questionable / push back / needs clarification), flag lessons for AGENTS.md. | you got PR feedback and want to sort it before acting |
| `/restory` | Rewrite the current branch's messy commits into a clean, logical sequence; same end tree, fewer/better commits. | your branch history needs tidying before a PR |
| `/invoke <name\|path> [args]` | Run a pack skill (`skills/<name>/SKILL.md`) or any markdown file as a skill; no args lists the pack skills. | a project pack ships a skill you want to run |

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

## Reading a frame and a plan

A printed frame or plan still uses a few sherpa terms. Here is what each one means.

**Summary and Details.** A frame and a plan both open with a plain **Summary** of about 12 lines.
The full record follows under **Details**. The Summary only restates the Details in simple words.

**The problem statement** (in a frame). One sentence with five parts:

| Part | Plain meaning |
|---|---|
| who | A named party, never just "the user". |
| can't do what | The goal they cannot reach. |
| why (the obstacle) | The cause that exists now. |
| what it costs | What breaks if nobody fixes it. |
| how we'll know (the done signal) | What an observer sees change when it is solved. |

**Open questions and design questions.** Open questions are about the problem or its scope. You
answer them in `/frame`. Design questions are choices about the solution. `/frame` leaves them for
`/shape`, which picks an answer and records why in Block 3.

**The goal statement** (in a plan). `<Outcome> for <consumers> because <motivation>; done when
<verification>`. The outcome is the end state you can observe. The motivation says why it matters.
The verification is a check you can run again.

**The three plan blocks.**
- **Block 1:** the goal statement, a before/after table, the step budget, and the limits (the
  no-gos and the rabbit holes).
- **Block 2:** the steps, one block each.
- **Block 3:** why this approach (precedent, design-question answers) and how the result is verified.

**The fields of a step.**
- **Goal:** what this step achieves. It traces back to the plan goal.
- **Change:** the concrete edit this step makes, and nothing more.
- **Interfaces:** what the step relies on and what it leaves for later steps.
  - `consumes` is what the step needs that already exists, or that an earlier step produces.
  - `produces` is what later steps rely on.
  - Each entry is an anchor like `path::literal`. The `literal` is text that must appear exactly
    in that file, so it can be checked with `git grep -F`. A path with no `::literal`
    points at the whole file. `none — <reason>` means no file backs the entry.
- **Acceptance criteria:** `done = <X>, confirmed by <check>`. The check can be run again.
- **Risk:** the one real risk that could sink this step, or `none` with a reason.

**Reviewer verdicts.** After the draft, reviewers check it. `OK` means the draft goes on.
`GAPS` means a reviewer found a gap. The driver fixes what it can and waits for you on the rest.

**The two approval points** (called "human gates" in `/shape`). In `/shape`, only these wait for you:
1. A gap only you can close. The driver shows the finding and waits.
2. Plan approval. Say "approved", "go" or "lgtm". A question or a critique is not approval.

## Project packs (optional)

The engine ships generic. To layer in your project's conventions, commit
`<repo>/.sherpa/project.yaml` (project-local) or drop one directory per project under a shared
workspace dir. `project.yaml` carries metadata only (`name`, `detect`); every content-bearing
value — `session.md` (injected at session start), `context.md` (forwarded to every subagent, at
the root and per layer) — is a fixed convention path next to it, resolved by one call:
`bash scripts/pack/load-layer.sh <configPath> [frame|shape|implement|analyze]`. Sherpa's single
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
- **`/analyze`** — Pre-review analysis of a branch's changes or a GitHub PR;
  `code-reviewer` does the independent, isolated look, `analysis-reviewer` checks each finding; the report opens with a short context briefing and ends with a verdict.
- **`/triage`** — categorizes all PR review feedback and flags lessons for AGENTS.md;
  strictly analytical, never edits code or replies on the PR.
- **`/restory`** — rewrites the current branch's commits into a clean, reviewable sequence; pure
  git, never pushes.
- **`/invoke`** — runs a pack skill or any markdown file as a skill; runs with your permissions,
  unsandboxed.

## Layout

```
skills/        /frame, /shape, /implement, /persist, /analyze, /triage, /restory, /invoke, using-sherpa
agents/        codebase-explorer, frame-reviewer, structure-reviewer, readiness-reviewer, engineering-reviewer, step-builder, quality-reviewer, code-reviewer, analysis-reviewer
protocols/harness/  Codex CLI and pi harness equivalence tables
packs/         project-pack template + docs
hooks/         the single SessionStart pack resolver
scripts/       helper scripts by group: pack, agents, ci (see scripts/README.md)
```

## License

MIT
