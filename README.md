# Sherpa

A [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) plugin: three
**composable skills**, one per layer of altitude — `/frame` (macro), `/shape` (shape),
`/implement` (build) — with bundled scout, shape-builder,
step-builder, and reviewer subagents that rope up and check the rope at every pitch.

Sherpa offers the tools; **you compose the workflow**. It's **opt-in** (nothing runs until
you call a skill), **lean** (nothing persists unless you call `/persist`), and
**project-agnostic** — your code style and extra reviewers plug in through a small YAML
*pack*, so the engine never hard-codes anything about your repo.

## Why

Asking an agent to "just build it" skips the parts that make work trustworthy: scouting
precedent, pinning down acceptance criteria, and adversarially checking the result. Sherpa
makes those first-class — but lets *you* decide how much ceremony a task needs:

- **A ceremony gradient.** A fuzzy task starts at `/frame`. A clear problem—whether you have
  a direction to pass as `DIRECTION` or need `/shape` to scout and pick one—starts at
  `/shape`. One obvious change goes straight to `/implement`. You pick the entry point.
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
| `/shape <task>` | shape (L2) | Fan out candidate directions along the frame's vantages, skeleton + critique the pool, present a pitch, **wait for your pick**; once picked, bind the goal's `Outcome`, plan ordered, traceable steps, critique the plan, **wait for approval**. | the problem's framed (or clear enough), you're ready to pass a direction as `DIRECTION`, or need `/shape` to scout and fan out |
| `/implement <task>` | build (L3) | Build each step (step-builder + acceptance + quality reviewers), with pressure per step. | it's one obvious change |
| `/scout <task>` | — | Standalone codebase scout; also called by `/frame` and `/shape`. | you just want a lay of the land |
| `/persist` | — | Write the in-context frame, pitch, or plan to disk so a later session can resume. | you want to save or resume |

Each skill is a standalone entry point: it uses the upstream artifact if it's in context,
else does the minimum to proceed — never re-running the layer above. Compose them however the
task wants:

```
/frame add rate limiting to the public API   # fuzzy → frame it first
   → scouts, asks a few questions, presents a frame
/shape                                       # fan out directions, pick one, then plan the steps
   → presents a pitch, waits for your pick, then presents the plan, waits for your approval
/implement                                   # build them, reviewed per step
```

…or just `/implement bump the copyright year` for a one-liner.

## How it works

`/frame` scouts, binds a problem contract, and asks questions as they arise, producing the frame
in context; `frame-reviewer` attacks the framing (L1). `/shape` fans out candidate directions,
skeletons and critiques the pool via `shape-reviewer` (solved, bounded, necessity, collapse),
presents a pitch, and waits for your pick; once picked, it plans the steps and gets that plan
attacked by `structure-reviewer` (how the steps relate) and `readiness-reviewer` (each step's own
contract) — all within L2 — then presents the plan and waits: **YOU APPROVE** is this run's one
hard gate. `/implement` then builds one step at a time: `step-builder` commits, then
`acceptance-reviewer` and `quality-reviewer` check it — all within L3.

`BLOCK` and a terminal `UNMET`/`FIX` surface to you verbatim; everything else continues
automatically — see `protocols/workflow/phases/implement.md` § Verdicts for the full state
machine, and `protocols/layers.md` for how pressure lives at each boundary instead of a final
gate.

## Project packs (optional)

The engine ships generic. To layer in your project's conventions, either commit a pack
inside the repo, or drop one directory per project in a shared workspace dir:

```
<repo>/.sherpa/project.yaml         # project-local, single canonical location
<packs dir>/<project>/project.yaml  # workspace (many projects, one dir)
```

`<packs dir>` is `$SHERPA_CONFIG_DIR/projects` if set, else `$WORKFLOW_PACKS_DIR` if set, else
`${XDG_CONFIG_HOME:-~/.config}/sherpa/projects`.

`project.yaml` carries metadata only — `name`, and `detect` (a shell command; required for a
workspace pack, forbidden for a project-local pack since the file's fixed location already
proves the project active). Every content-bearing value is a fixed convention path next to
that `project.yaml`, not a YAML key:

```
.sherpa/project.yaml
.sherpa/context.md                 # cross-cutting, forwarded into every subagent's brief
.sherpa/implement/codeStyle.md     # complete rule set; resolved lazily
.sherpa/implement/validate.md      # content is the command(s) step-builder runs before committing
.sherpa/implement/review.md        # prose the driver reads before dispatching reviewers
```

Sherpa's single `SessionStart` hook scans for a matching config, detects the active project,
and announces its pack — no per-project hook to write. If nothing matches, the engine runs
generic and every pack-dependent step no-ops. Full 9-key convention-path table and resolution
rules: `packs/README.md`.

## Components

### L1 Macro
- **`/frame`** — scout + bind a problem contract; presents a frame, nothing on disk.
- **`frame-reviewer`** (agent) — cold eyes on the frame's problem contract, discovery, and open questions.

### L2 Shape
- **`/shape`** — fans out candidate directions from the frame, skeletons + critiques the pool, presents a pitch for your pick; once picked, binds the goal's `Outcome`, plans ordered steps, and waits for your approval.
- **`shape-builder`** (agent) — read-only candidate builder holding one premise false; the worker `/shape` dispatches.
- **`shape-reviewer`** (agent) — cold eyes on the pooled candidates; returns a ranked shortlist + traps + collapse record.
- **`structure-reviewer`** (agent) — attacks how steps relate (traceability, gaps, overlap, order, interface mismatch).
- **`readiness-reviewer`** (agent) — attacks each step's own contract (completeness, over-prescription, single responsibility, risk substance).

### L3 Build
- **`/implement`** — runs approved steps via step-builder + reviewers, pressure per step.
- **`step-builder`** (agent) — implements one step and lands one commit.
- **`acceptance-reviewer`** (agent) — judges whether each acceptance criterion is met.
- **`quality-reviewer`** (agent) — audits the diff for minimality, correctness, security, tests.

### Cross-cutting
- **`/scout`** — standalone codebase scout; also called by `/frame` and `/shape`.
- **`/persist`** — writes the in-context frame, pitch, or plan to disk on request.

## Layout

```
skills/        /frame, /shape, /implement, /scout, /persist, using-sherpa
agents/        scout, frame-reviewer, shape-builder, shape-reviewer, structure-reviewer, readiness-reviewer, step-builder, acceptance-reviewer, quality-reviewer
protocols/     the workflow contracts (the engine's brain)
packs/         project-pack template + docs
hooks/         the single SessionStart pack resolver
```

## License

MIT
