# The three layers (sherpa's spine)

Sherpa is three layers of decreasing altitude, each an **independently callable skill**. Sherpa
offers the tools; the user composes the workflow. Each layer has **one job, one driver, one
artifact, and its pressure at the boundary.** Pressure lives at the boundary between layers — never
nested inside; a boundary may carry more than one critique.

**What separates one layer from the next: how much it sees, and what it may change.** The
discriminator is a single progression — *no diff → all steps, no diff → one step's diff*. The
moment a component can see a diff, it is build (L3).

| Layer | Skill | Owns (artifact) | Question | Sees | May change |
|---|---|---|---|---|---|
| **macro** (L1) | `/spec` | the spec (intent + discovery + open questions) | right problem, right framing? | the whole problem, **no diff** | anything |
| **step** (L2) | `/plan` | the plan (the step list) | do these pieces, in this order, add up to the goal? | **all steps at once**, no diff | the decomposition (not code) |
| **build** (L3) | `/implement` | the commits (the code) | does each step's code do what it promised, built well? | **one step's diff** at a time | that step's code |

A read-only reviewer at any layer changes **nothing** — it emits a verdict. The "may change" column
is the layer's *driver* boundary; reviewers inherit the layer's *sees* boundary.

## A ceremony gradient — the user picks the entry point

The three skills are independent tools, not a fixed chain. The entry point matches task complexity:

```
fuzzy / unknown scope / design calls   →  /spec       (refine, discover, surface unknowns)
clear goal, just needs decomposition   →  /plan        (skip /spec)
one obvious change                     →  /implement   (skip both)
```

Two rules keep a lower entry point from re-running the layer above it:
1. **Each skill takes a `<task>` arg** — any can be the entry point.
2. **Consume the upstream artifact if it's in context; else do the *minimum* to proceed — never
   re-run the upstream layer.** Skills share *tools* (`/scout`), not *logic*. A standalone `/plan`
   is the step layer doing a lighter discovery for its own needs, not a small `/spec`.

When a skill notices it is underspecified, it **offers** to go up a layer in one declinable line —
never a forced router. The user's judgment is the router.

## Handoff & state
- **In-context by default.** Within one conversation each skill's output is in context for the next.
- **Single-conversation is the default contract.** No spec in a fresh session is expected.
- **Persistence is the opt-in `/persist` skill.** No branch-keyed run-state, no `DECISIONS`/`PROGRESS`.

## Per-component binding

| Component | Layer | Boundary |
|---|---|---|
| `/spec` skill | macro | drives the spec; nothing to disk, no source edits |
| `spec-reviewer` | macro | reads the spec + repo read-only, no diff; read-only `SOLID \| HOLES` |
| `/scout` skill | macro | reads the codebase to produce a Discover record; changes nothing |
| `scout` (agent) | cross-cutting | reads the target read-only to produce a Discover record; the worker the `/scout` skill dispatches; owns no layer |
| `/diverge` skill | macro | reads the problem + codebase to produce candidate directions and a Direction record; changes nothing |
| `diverger` (agent) | cross-cutting | reads the target read-only to produce candidate directions; the worker the `/diverge` skill dispatches; owns no layer |
| `diverge-reviewer` | macro | reads the candidate pool read-only, no diff; returns a ranked shortlist + traps + collapse record |
| `/plan` skill | step | decomposes into steps; no source edits |
| `plan-reviewer` | step | sees all steps + repo read-only, no diff; read-only `SOLID \| HOLES` on the decomposition |
| `/implement` skill | build | drives one step at a time; never reopens the plan |
| `step-builder` | build | sees one step's diff; changes only that step's code |
| `acceptance-reviewer` | build | sees one step's diff + criteria; read-only `MET \| UNMET` |
| `quality-reviewer` | build | sees one step's diff; read-only `PASS \| FIX \| BLOCK` |
| `/persist` skill | cross-cutting | writes the in-context spec/plan to disk on request; owns no layer |

Like `/scout`, `/diverge` is a macro-layer **tool**, not the layer's driver: classification comes
from what it sees — the problem and the codebase, no steps, no diff, exactly like `/scout` — not
from who consumes its output. Its Direction record is consumed by `/plan` step 0, where `Outcome`
binds.

An optional **project pack** extends each layer's components with project-specific knowledge
(and, for plan/implement, extra rules/validation) — see `packs/README.md`.

## No separate Validate
Adversarial pressure lives at each boundary — the candidate-pool critique (`/diverge`), the spec
critique (L1), the decomposition critique (L2), and per-step acceptance + quality (L3). There is no
final goal-gate: if the decomposition was sound and each step met its criteria, the goal holds by
construction.
