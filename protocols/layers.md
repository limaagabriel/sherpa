# The four layers (sherpa's spine)

Sherpa is four layers of decreasing altitude, each an **independently callable skill**. Sherpa
offers the tools; the user composes the workflow. Each layer has **one job, one driver, one
artifact, and its pressure at the boundary.** Pressure lives at the boundary between layers — never
nested inside; a boundary may carry more than one critique.

**What separates one layer from the next: how many step lists, at what resolution.** The
discriminator is a single progression — *no step list → N coarse step lists → 1 exact step list →
1 step's diff*. N coarse lists is shape (L2); one exact list is decompose (L3); the moment a
component can see a diff, it is build (L4).

| Layer | Skill | Owns (artifact) | Question | Sees | May change |
|---|---|---|---|---|---|
| **macro** (L1) | `/frame` | the frame (problem contract + discovery + open questions) | right problem, right framing? | the whole problem, **no step list** | anything |
| **shape** (L2) | `/shape` | the pitch (N coarse step lists) | which direction, and is each one actually solved? | the problem + **N coarse step lists**, no diff | nothing on disk |
| **step** (L3) | `/decompose` | the plan (the step list) | do these pieces, in this order, add up to the goal? | **1 exact step list**, no diff | the decomposition (not code) |
| **build** (L4) | `/implement` | the commits (the code) | does each step's code do what it promised, built well? | **one step's diff** at a time | that step's code |

A read-only reviewer at any layer changes **nothing** — it emits a verdict. The "may change" column
is the layer's *driver* boundary; reviewers inherit the layer's *sees* boundary.

## A ceremony gradient — the user picks the entry point

The four skills are independent tools, not a fixed chain. The entry point matches task complexity:

```
fuzzy / unknown scope / design calls     →  /frame       (scout, bind a problem contract, surface unknowns)
clear problem, multiple directions       →  /shape       (skip /frame — /shape offers to run it if none exists)
one direction, needs decomposition       →  /decompose   (skip /frame, /shape)
one obvious change                       →  /implement   (skip all three)
```

Two rules keep a lower entry point from re-running the layer above it:
1. **Each skill takes a `<task>` arg** — any can be the entry point.
2. **Consume the upstream artifact if it's in context; else do the *minimum* to proceed — never
   re-run the upstream layer.** Skills share *tools* (`/scout`), not *logic*. A standalone
   `/decompose` is the step layer doing a lighter discovery for its own needs, not a small
   `/frame`.

**Exception: `/shape` is the one layer that requires its upstream artifact** — it derives its
vantages from the frame's problem contract, so with no frame in context it has no vantage axis to
fan out on at all.

When a skill notices it is underspecified, it **offers** to go up a layer in one declinable line —
never a forced router; `/shape` uses this when no frame is in context. The user's judgment is the
router.

## Handoff & state
- **In-context by default.** Within one conversation each skill's output is in context for the next.
- **Single-conversation is the default contract.** No frame in a fresh session is expected.
- **Persistence is the opt-in `/persist` skill.** No branch-keyed run-state, no `DECISIONS`/`PROGRESS`.

## Per-component binding

| Component | Layer | Boundary |
|---|---|---|
| `/frame` skill | macro | drives the frame; nothing to disk, no source edits |
| `frame-reviewer` | macro | reads the frame + repo read-only, no diff; read-only `SOLID \| HOLES` |
| `/scout` skill | cross-cutting | reads the codebase to produce a Discover record; changes nothing |
| `scout` (agent) | cross-cutting | reads the target read-only to produce a Discover record; the worker the `/scout` skill dispatches; owns no layer |
| `/shape` skill | shape | drives the pitch; nothing to disk, no source edits |
| `shape-builder` (agent) | shape | reads the target read-only to produce candidate directions; the worker the `/shape` skill dispatches |
| `shape-reviewer` | shape | reads the candidate pool read-only, no diff; returns a ranked shortlist + traps + collapse record |
| `/decompose` skill | step | decomposes into steps; no source edits |
| `structure-reviewer` | step | sees all steps + repo read-only, no diff; read-only `SOLID \| HOLES` on the decomposition |
| `readiness-reviewer` | step | sees all steps read-only, no diff; read-only `SOLID \| HOLES` on each step's own contract |
| `/implement` skill | build | drives one step at a time; never reopens the plan |
| `step-builder` | build | sees one step's diff; changes only that step's code |
| `acceptance-reviewer` | build | sees one step's diff + criteria; read-only `MET \| UNMET` |
| `quality-reviewer` | build | sees one step's diff; read-only `PASS \| FIX \| BLOCK` |
| `/persist` skill | cross-cutting | writes the in-context frame, pitch, or plan to disk on request; owns no layer |

`/scout` produces no step list and owns no artifact of its own; `/shape` produces N coarse step
lists and owns the pitch.

An optional **project pack** extends each layer's components with project-specific knowledge
(and, for decompose/implement, extra rules/validation) — see `packs/README.md`.

## No separate Validate
Adversarial pressure lives at each boundary — the frame critique (L1), the shape critique (L2), the
decomposition critique (L3), and per-step acceptance + quality (L4). There is no final goal-gate: if
the decomposition was sound and each step met its criteria, the goal holds by construction.
`/implement` also runs the plan's own already-authored Block 3 check once at the end
(`protocols/workflow/phases/implement.md` § Plan-level verification) — not a new layer or
reviewer, but the mechanism that makes "holds by construction" actually confirmed rather than
assumed.
