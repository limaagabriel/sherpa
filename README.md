# Sherpa

A [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) plugin: four
**composable skills**, one per layer of altitude — `/frame` (macro), `/shape` (shape),
`/decompose` (step), `/implement` (build) — with bundled scout, shape-builder,
step-builder, and reviewer subagents that rope up and check the rope at every pitch.

Sherpa offers the tools; **you compose the workflow**. It's **opt-in** (nothing runs until
you call a skill), **lean** (nothing persists unless you call `/persist`), and
**project-agnostic** — your code style and extra reviewers plug in through a small YAML
*pack*, so the engine never hard-codes anything about your repo.

## Why

Asking an agent to "just build it" skips the parts that make work trustworthy: scouting
precedent, pinning down acceptance criteria, and adversarially checking the result. Sherpa
makes those first-class — but lets *you* decide how much ceremony a task needs:

- **A ceremony gradient.** A fuzzy task starts at `/frame`. A clear problem with multiple
  directions to weigh starts at `/shape`. One direction that just needs decomposing starts at
  `/decompose`. One obvious change goes straight to `/implement`. You pick the entry point.
- **Reviewed at every layer.** A frame-reviewer attacks the framing, a shape-reviewer attacks
  the candidate pool, a structure-reviewer attacks how the steps relate and a readiness-reviewer
  attacks each step's own contract, and per-step acceptance + quality reviewers check "right
  thing?" and "built right?" independently.
- **No magic state.** The frame, pitch, and plan live in the conversation. Want them on disk to
  resume later? Call `/persist`. Otherwise sherpa leaves no trace.

## Install

Requires `jq` and `yq` (v4+) on `PATH` for the SessionStart pack resolver — without `jq`
the hook stays silent; without `yq` it still loads but skips project packs.

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
project pack), and start a new thread. Verify with `/frame` — if the skill shows up, you're set.

## Usage

| Skill | Layer | Does | Start here when |
|---|---|---|---|
| `/frame <task>` | macro (L1) | Scout, bind a problem contract, ask questions as they arise, compose + present a frame, get a cold-eyes critique. | the task is fuzzy or has design calls |
| `/shape <task>` | shape (L2) | Fan out candidate directions along the frame's vantages, skeleton + critique the pool, present a pitch; **wait for your pick**. | the problem's framed and there are multiple directions to weigh (needs a frame — offers `/frame` first if none exists) |
| `/decompose <task>` | step (L3) | Bind the goal's `Outcome`, decompose into ordered, traceable steps; critique the decomposition; **wait for approval**. | the goal is clear, just needs steps |
| `/implement <task>` | build (L4) | Build each step (step-builder + acceptance + quality reviewers), with pressure per step. | it's one obvious change |
| `/scout <task>` | — | Standalone codebase scout; also called by `/frame` and `/decompose`. | you just want a lay of the land |
| `/persist` | — | Write the in-context frame, pitch, or plan to disk so a later session can resume. | you want to save or resume |

Each skill is a standalone entry point: it uses the upstream artifact if it's in context,
else does the minimum to proceed — never re-running the layer above. Compose them however the
task wants:

```
/frame add rate limiting to the public API   # fuzzy → frame it first
   → scouts, asks a few questions, presents a frame
/shape                                       # fan out directions, pick one
   → presents a pitch, waits for your pick
/decompose                                   # decompose the pick into steps
   → presents steps, waits for your approval
/implement                                   # build them, reviewed per step
```

…or just `/implement bump the copyright year` for a one-liner.

## How it works

```
/frame      scout + bind a problem contract + ask questions as they arise  →  frame  (in context)
            frame-reviewer attacks the framing (L1)
/shape      fan out directions, skeleton + critique the pool  →  pitch  (in context)
            shape-reviewer attacks the pool: solved, bounded, collapse (L2)
/decompose  decompose into steps  ──►  YOU APPROVE  ◄── (hard gate)
            structure-reviewer attacks how steps relate, readiness-reviewer attacks each step's contract (L3)
/implement  per step: step-builder commits → acceptance-reviewer + quality-reviewer (L4)
```

`BLOCK` findings surface to you. `MET`/`PASS`/`FIX` continue automatically (a `FIX` is folded
into the step-builder's commit and re-checked once; still failing after that re-check is terminal,
surfaced like `BLOCK`). Any reviewer output containing `recommend /decompose revisit` also stops,
surfacing verbatim and offering `/decompose` in one declinable line. There is no final Validate
gate — pressure lives at each boundary. See `protocols/layers.md`.

## Project packs (optional)

The engine ships generic. To layer in your project's conventions, drop one directory per project:

```
<packs dir>/<project>/project.yaml
```

`<packs dir>` is `$SHERPA_CONFIG_DIR/projects` if set, else `$WORKFLOW_PACKS_DIR` if set, else
`${XDG_CONFIG_HOME:-~/.config}/sherpa/projects`.

```yaml
name: my-project
detect: case "$CWD" in */my-project*) exit 0 ;; *) exit 1 ;; esac
sessionInstructions: |
  Invoke Skill my-project-init before other work; skip if already invoked.
pack:
  knowledge: Invoke Skill my-project-init — loads project rules.   # cross-cutting: every layer, every subagent
  implement:
    codeStyleRules: cat /abs/path/to/rules.md   # command that dumps your style rules
```

Sherpa's single `SessionStart` hook scans the packs dir, detects the active project, and announces
its pack — no per-project hook to write. If nothing matches, the engine runs generic and every
pack-dependent step no-ops. Details and the full schema: `packs/README.md`.

## Components

### L1 Macro
- **`/frame`** — scout + bind a problem contract; presents a frame, nothing on disk.
- **`/scout`** — standalone codebase scout; also called by `/frame` and `/decompose`.
- **`frame-reviewer`** (agent) — cold eyes on the frame's problem contract, discovery, and open questions.

### L2 Shape
- **`/shape`** — fans out candidate directions from the frame, skeletons + critiques the pool, presents a pitch for your pick.
- **`shape-builder`** (agent) — read-only candidate builder holding one premise false; the worker `/shape` dispatches.
- **`shape-reviewer`** (agent) — cold eyes on the pooled candidates; returns a ranked shortlist + traps + collapse record.

### L3 Step
- **`/decompose`** — binds the goal's `Outcome`, decomposes into ordered steps; waits for your approval.
- **`structure-reviewer`** (agent) — attacks how steps relate (traceability, gaps, overlap, order, interface mismatch).
- **`readiness-reviewer`** (agent) — attacks each step's own contract (completeness, over-prescription, single responsibility, risk substance).

### L4 Build
- **`/implement`** — runs approved steps via step-builder + reviewers, pressure per step.
- **`step-builder`** (agent) — implements one step and lands one commit.
- **`acceptance-reviewer`** (agent) — judges whether each acceptance criterion is met.
- **`quality-reviewer`** (agent) — audits the diff for minimality, correctness, security, tests.

### Cross-cutting
- **`/persist`** — writes the in-context frame, pitch, or plan to disk on request.

## Layout

```
skills/        /frame, /shape, /decompose, /implement, /scout, /persist
agents/        scout, frame-reviewer, shape-builder, shape-reviewer, structure-reviewer, readiness-reviewer, step-builder, acceptance-reviewer, quality-reviewer
protocols/     the workflow contracts (the engine's brain)
packs/         project-pack template + docs
hooks/         the single SessionStart pack resolver
```

## License

MIT
