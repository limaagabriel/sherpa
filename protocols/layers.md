# The three layers (sherpa's spine)

Sherpa is three layers of decreasing altitude. Each has **one job, one driver, one artifact, one
pressure point.** Pressure lives at the boundary between layers — never nested inside them.

**What separates one layer from the next: how much it sees, and what it may change.** Read the
table top-down and the discriminator is a single progression — *no code → all steps, no code → one
step's code*. The moment a component can see code, it is build (L3).

| Layer | Owns (source of truth) | Question | Sees | May change |
|---|---|---|---|---|
| **macro** (L1) | the plan (architecture + decisions) | right problem, right approach? | the whole problem, **no code** | anything |
| **step** (L2) | the step list (order + boundaries) | do these pieces, in this order, add up to the plan? | **all steps at once**, no code | the decomposition (not code) |
| **build** (L3) | the commits (the code) | does each step's code do what it promised, built well? | **one step's diff** at a time | that step's code |

A read-only reviewer at any layer changes **nothing** — it emits a verdict. The "may change" column
is the layer's *driver* boundary; reviewers inherit the layer's *sees* boundary and produce verdicts.

macro *proposes* the step decomposition; step *ratifies* it. That producer-vs-ratifier split is why
step is a gate, not a doing-layer — it has no driver skill of its own.

## Per-component binding

| Component | Layer | Boundary |
|---|---|---|
| `plan` skill | macro | drives the plan; writes no code |
| `plan-reviewer` | macro | reads the plan + reasoning, no code; read-only verdict |
| `scout` skill | macro | reads the codebase to produce a Discover record; changes nothing |
| `step-reviewer` | step | sees all steps, no code; read-only verdict on the decomposition |
| `execute` skill | build | drives one step at a time; never reopens the plan |
| `builder` | build | sees one step's diff; changes only that step's code — never the plan or another step |
| `acceptance-reviewer` | build | sees one step's diff + criteria; read-only verdict |
| `quality-reviewer` | build | sees one step's diff; read-only verdict |
| `workflow` / `workflow-resume` | cross-cutting | span layers, own no artifact; chain the halves and hold the gate |

## step vs. the build acceptance-reviewer — same noun, different time

Both judge steps, but step judges them *before* code exists ("are these the right pieces?") and
the build `acceptance-reviewer` judges *after* ("did this piece get built as promised?"). Not
overlap — the timeline splits them.

## Layers vs. phases (two different axes)

Layers (altitude of artifact under pressure) are orthogonal to the
Discover→Analyze→Plan→Execute→Validate phases (the timeline):

```
Phase:   Discover → Analyze → Plan │ (gate) │ Execute  │ Validate
Layer:   └────────── macro ────────┘  step   └─ build ──┘  cross-cutting
```

macro spans three phases; step is the single gate between Plan and Execute; build is Execute;
Validate belongs to no layer.
