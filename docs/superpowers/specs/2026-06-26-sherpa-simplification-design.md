# Sherpa Simplification — Design

**Date:** 2026-06-26
**Status:** Approved design, pending spec review

## Problem

Sherpa grew spaghettish: a 5-deep dispatch chain
(`workflow → plan/execute → build-and-review → adversarial-build → builders/breakers → reviewers`),
~16 protocol fragments, and a redundant *inner* adversarial pressure engine
(breaker + drafter + briefing + verdict protocols) bolted inside the execution layer.

Root cause: **pressure applied in the wrong direction.** Adversarial pressure was nested
*inside* step execution instead of living at the **layer boundaries**. That nesting forced the
proliferation of protocols, output contracts, and verdict handling — and it left the real
architecture (three layers of decreasing altitude) implicit, hidden behind skill names like
`workflow` and `build-and-review`.

## The three layers (the spine)

Sherpa is three layers of decreasing altitude. Each layer has **one job, one driver, one
artifact, and exactly one pressure point.** Pressure lives at the boundary between layers —
never nested inside them.

**What separates one layer from the next: how much it sees, and what it may change.** Read the
table top-down and the discriminator is a single progression — *no code → all steps, no code →
one step's code*. The moment a layer can see code, it is L3.

| Layer | Owns (source of truth) | Question | Sees | May change |
|---|---|---|---|---|
| **L1 macro** | the plan (architecture + decisions) | right problem, right approach? | the whole problem, **no code** | anything |
| **L2 step** | the step list (order + boundaries) | do these pieces, in this order, add up to the plan? | **all steps at once**, no code | the decomposition (not code) |
| **L3 build** | the commits (the code) | does each step's code do what it promised, built well? | **one step's diff** at a time | that step's code |

L1 *proposes* the step decomposition; L2 *ratifies* it. That producer-vs-ratifier split is why
L2 is a gate, not a doing-layer — it has no driver skill of its own.

```
                        DRIVER          PRODUCES            PRESSURE (one)            MODEL
┌─ L1  MACRO ─────────  plan skill      the plan:           plan-reviewer:            —
│      "right plan?"    (discover/       architecture,      architecture +
│                        analyze/plan    decisions,         reasoning sound?
│                        phases)         step decomposition
│
├─ L2  STEP ──────────  (step gate,     validated step      step-reviewer:            —
│      "right steps?"    end of plan /   list               decomposition complete?
│                        before build)                      fires ONCE, up-front,
│                                                           over ALL steps
│
└─ L3  BUILD ─────────  execute skill   commits            TWO parallel reviewers,   builder
       "right thing,    (per step:                          after each step:          picks
        built right?"    builder +                          • acceptance-reviewer —   per step
                         2 reviewers)                          plan perspective:       (see rule)
                                                               step meets its criteria?
                                                             • quality-reviewer —
                                                               quality perspective:
                                                               clean, correct, secure,
                                                               no regression
```

**Why two L3 reviewers, not one.** A quality reviewer can wave through clean code that doesn't do
what the step promised — its lens is "good code," not "meets the spec." So acceptance and quality
are split into two purpose-built agents run in parallel: diverse perspectives catch different
failures; redundant ones just agree. These two are the *only* default L3 reviewers — sherpa ships
no dimension-reviewer fan-out (a project pack may still announce extra `reviewers`). The old
`task-reviewer`'s 3-loop ceremony is dropped — each reviewer emits its verdict and relays gaps once.

**Why up-front step pressure (L2):** a missing foundation in step 1 silently breaks steps 2–N.
Reviewing the whole decomposition before building anything catches that when it is cheap.

**L2 vs. the L3 acceptance-reviewer — same noun, different time.** Both judge steps, but L2 judges
them *before* code exists ("are these the right pieces?") and L3's acceptance-reviewer judges *after*
("did this piece get built as promised?"). Not overlap — the timeline splits them.

**Why no overseer layer:** a reasoning auditor that runs at the end is pressure at the worst
moment — max sunk cost, min leverage. Reasoning pressure belongs at L1, where a bad call is
cheap to fix. `plan-reviewer` owns it; the old `turn-reviewer` is deleted.

### Layers vs. phases (two different axes)

Layers (altitude of artifact under pressure) are orthogonal to the
Discover→Analyze→Plan→Execute→Validate phases (the timeline). The mapping:

```
Phase:   Discover → Analyze → Plan │ (gate) │ Execute  │ Validate
Layer:   └────────── L1 ───────────┘   L2    └── L3 ────┘  cross-cutting
```

L1 spans three phases; L2 is the single gate between Plan and Execute; L3 is Execute; Validate
belongs to no layer.

### Cross-cutting (not a layer)

- `workflow` skill — the conductor; runs L1 then L3. Spans layers, owns none.
- `validate` phase — final goal check after L3.
- `state-persistence`, `mutating-bash-verbs`, harness/codex support, `resolve-project-pack` — infra.

## L3 builder — model rule (preserves the cheap-model win)

The single builder picks its model per step:

> Is this step pure automated codegen — run a generator, commit its output, no hand-written logic?
> → **haiku.** Otherwise → default model.

One line of self-judgment. Replaces the entire codegen agent + tiering-catalog apparatus.

## Make the layers explicit — without moving files

A directory regroup (`layers/macro/`, …) was considered and **rejected**: it breaks harness
discovery. Each harness finds components by its own convention, in its own location:

| Harness | Skills | Agents |
|---|---|---|
| Claude | `skills/` (convention; `plugin.json` declares no override) | `agents/*.md` (convention) |
| Codex | `skills/` (via `.codex-plugin/plugin.json` `"skills"`) | `.codex/agents/*.toml` (separate dir + format) |
| Pi (coming) | its own convention | its own convention |

Moving files under `layers/` would break Claude, desync Codex's `.codex/agents/`, and collide
with Pi's future convention. So the layers are made explicit by **labeling, not relocation**:

1. **Layer-first README** — the component index in `README.md` is grouped under L1/L2/L3 + cross-cutting.
2. **`Layer:` line in every component** — each `SKILL.md` / agent description names its layer
   (`Layer: macro | step | build | cross-cutting`). Pick by the discriminator from the spine: what
   the component sees — whole problem, no code → `macro`; all steps, no code → `step`; one step's
   code → `build`; spans layers or pure infra → `cross-cutting`. A reader sees the layer in the
   file, and the harness still finds it by convention.

Result: layers legible from any single file and from the README, with zero churn to harness paths.

## What dies (per layer)

| Layer | Delete | Why |
|---|---|---|
| L3 | `skills/adversarial-build`, `skills/codegen-build` | the redundant inner pressure engine |
| L3 | `skills/build-and-review` | folds into `execute` (only routes step → build + review) |
| L3 | `agents/adversarial-builder`, `agents/codegen-builder` | → one builder |
| L1/L2 | `agents/adversarial-breaker`, `agents/adversarial-drafter` | pressure moved to layer boundaries |
| cross | `skills/turn-review`, `agents/turn-reviewer` | overseer dropped; reasoning audit → plan-reviewer |
| cross | `protocols/adversarial/*` (incl. `verdict-handling`) | no inner engine to govern |
| cross | `protocols/invariants/tiering-catalog`, `build-id` | one builder, no tiers, no build-note ceremony |
| cross | `protocols/invariants/inline-mode` | feature removed |
| cross | `scripts/build-notes.sh`, `scripts/build-log.sh` | build-id ceremony gone |

Estimated reduction: ~1,100 lines, ~12 files. Dispatch depth 5 → 2.

## Create

- `agents/builder` (L3) — the single builder (+ Codex twin).
- `agents/acceptance-reviewer` (L3) — plan perspective; emits per-criterion
  `ACCEPTANCE: MET/UNMET`, relays gaps once, no 3-loop (+ Codex twin).
- `agents/quality-reviewer` (L3) — quality perspective; one general reviewer covering
  minimality, architecture, correctness, security, performance, edge cases, test coverage,
  regression risk (+ Codex twin). Self-contained — no shared `base.md`.

## Rename

- `agents/plan-breaker` → `agents/plan-reviewer` (L1)
- `agents/task-reviewer` → `agents/step-reviewer` (L2)

Each agent has a Codex twin under `.codex/agents/*.toml`. Every delete and rename above must be
mirrored there (`.codex/agents/plan-breaker.toml` → `plan-reviewer.toml`, delete the
`adversarial-*`/`codegen-builder`/`turn-reviewer` toml twins, etc.). Treat the two copies as one
unit per agent.

## What stays

`workflow`, `plan`, `execute`, `scout`, `workflow-resume`; `workflow/phases/*`;
`state-persistence`, `mutating-bash-verbs`; `resolve-project-pack.sh` (+ test),
`run-state-archive.sh`; harness/codex support.

## Out of scope

- Re-litigating the macro `workflow/phases` design — it stays.
- Behaviour changes beyond removing the inner engine; this is a structural debloat, not a
  feature rework. Layers are made explicit by labeling, not by moving files.

## Risks

- The collapsed dispatch path is load-bearing. `execute` absorbing `build-and-review` must
  preserve per-step build + review behaviour. Verify on a real plan run before calling done.
- Renamed agents are referenced across skills/protocols **and** mirrored in `.codex/agents/*.toml`
  — grep every caller in both trees before rename, update all paths and both copies.
- Harness coupling: a future Pi harness will add a third agent/skill location. Keep components
  discoverable by each harness's own convention; never assume one shared path.
