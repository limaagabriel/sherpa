# Sherpa

A [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) plugin: three
**composable skills**, one per layer of altitude — `/spec` (macro), `/plan` (step),
`/implement` (build) — with bundled scout, step-builder, and reviewer subagents that rope up
and check the rope at every pitch.

Sherpa offers the tools; **you compose the workflow**. It's **opt-in** (nothing runs until
you call a skill), **lean** (nothing persists unless you call `/persist`), and
**project-agnostic** — your code style and extra reviewers plug in through a small YAML
*pack*, so the engine never hard-codes anything about your repo.

## Why

Asking an agent to "just build it" skips the parts that make work trustworthy: scouting
precedent, pinning down acceptance criteria, and adversarially checking the result. Sherpa
makes those first-class — but lets *you* decide how much ceremony a task needs:

- **A ceremony gradient.** A fuzzy task starts at `/spec`. A clear goal starts at `/plan`.
  One obvious change goes straight to `/implement`. You pick the entry point.
- **Reviewed at every layer.** A spec-reviewer attacks the framing, a plan-reviewer attacks
  the decomposition, and per-step acceptance + quality reviewers check "right thing?" and
  "built right?" independently.
- **No magic state.** The spec and plan live in the conversation. Want them on disk to resume
  later? Call `/persist`. Otherwise sherpa leaves no trace.

## Install

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

Then open `/hooks`, review and **trust** sherpa's `SessionStart` hook (it detects your
project pack), and start a new thread. Verify with `/spec` — if the skill shows up, you're set.

## Usage

| Skill | Layer | Does | Start here when |
|---|---|---|---|
| `/spec <task>` | macro | Refine intent, scout, ask questions as they arise, compose + present a spec, get a cold-eyes critique. | the task is fuzzy or has design calls |
| `/plan <task>` | step | Decompose into ordered, traceable steps; critique the decomposition; **wait for approval**. | the goal is clear, just needs steps |
| `/implement <task>` | build | Build each step (step-builder + acceptance + quality reviewers), with pressure per step. | it's one obvious change |
| `/scout <task>` | — | Standalone codebase scout; also called by `/spec` and `/plan`. | you just want a lay of the land |
| `/persist` | — | Write the in-context spec/plan to disk so a later session can resume. | you want to save or resume |

Each skill is a standalone entry point: it uses the upstream artifact if it's in context,
else does the minimum to proceed — never re-running the layer above. Compose them however the
task wants:

```
/spec add rate limiting to the public API   # fuzzy → shape it first
   → scouts, asks a few questions, presents a spec
/plan                                        # decompose the spec into steps
   → presents steps, waits for your approval
/implement                                   # build them, reviewed per step
```

…or just `/implement bump the copyright year` for a one-liner.

## How it works

```
/spec       scout + refine intent + ask as questions arise  →  spec  (in context)
            spec-reviewer attacks the framing (L1)
/plan       decompose into steps  ──►  YOU APPROVE  ◄── (hard gate)
            plan-reviewer attacks the decomposition (L2)
/implement  per step: step-builder commits → acceptance-reviewer + quality-reviewer (L3)
```

`BLOCK` findings surface to you. `MET`/`PASS`/`FIX` continue automatically (a `FIX` is folded
into the step-builder's commit and re-checked once). There is no final Validate gate — pressure
lives at each boundary. See `protocols/layers.md`.

## Project packs (optional)

The engine ships generic. To layer in your project's conventions, drop one YAML file per project:

```
${WORKFLOW_PACKS_DIR:-~/.claude/sherpa/projects}/<project>.yaml
```

```yaml
name: my-project
detect: case "$CWD" in */my-project*) exit 0 ;; *) exit 1 ;; esac
sessionInstructions: |
  Invoke Skill my-project-init before other work; skip if already invoked.
pack:
  initialize: my-project-init          # skill that loads project knowledge
  reviewers: my-project-code-reviewer  # extra review subagents
  codeStyleRules: cat /abs/path/to/rules.md   # command that dumps your style rules
```

Sherpa's single `SessionStart` hook scans the dir, detects the active project, and announces
its pack — no per-project hook to write. If nothing matches, the engine runs generic and every
pack-dependent step no-ops. Details and the full schema: `packs/README.md`.

## Components

### L1 Macro
- **`/spec`** — refine intent + discover; presents a spec, nothing on disk.
- **`/scout`** — standalone codebase scout; also called by `/spec` and `/plan`.
- **`spec-reviewer`** (agent) — cold eyes on the spec's intent, discovery, and open questions.

### L2 Step
- **`/plan`** — decompose into steps; waits for your approval.
- **`plan-reviewer`** (agent) — attacks the decomposition (traceability, gaps, overlap, order).

### L3 Build
- **`/implement`** — runs approved steps via step-builder + reviewers, pressure per step.
- **`step-builder`** (agent) — implements one step and lands one commit.
- **`acceptance-reviewer`** (agent) — judges whether each acceptance criterion is met.
- **`quality-reviewer`** (agent) — audits the diff for minimality, correctness, security, tests.

### Cross-cutting
- **`/persist`** — writes the in-context spec/plan to disk on request.

## Layout

```
skills/        /spec, /plan, /implement, /scout, /persist
agents/        spec-reviewer, plan-reviewer, step-builder, acceptance-reviewer, quality-reviewer
protocols/     the workflow contracts (the engine's brain)
packs/         project-pack template + docs
hooks/         the single SessionStart pack resolver
```

## License

MIT
