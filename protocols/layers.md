# The three layers (sherpa's spine)

Sherpa is three layers of decreasing altitude, each an **independently callable skill**. Sherpa
offers the tools; the user composes the workflow. Each layer has **one job, one driver, and
pressure at every artifact boundary it produces** — most layers hand off one artifact; shape hands
off two.

**Pressure lives at the boundary of every artifact a layer produces, not nested inside the
reasoning that produces it.** Frame carries one boundary (the problem contract); shape carries
two, back to back (the candidate pool, then the plan); implement carries one per step (that step's
commit). A boundary may carry more than one critique.

**What separates one layer from the next: what's unbound — problem, solution, or nothing.** In
frame the problem is unbound: scope, framing, and open questions are still in play. In shape the
problem is settled but the solution is unbound: which direction, and whether a full plan for that
direction adds up to the goal. In implement nothing is unbound: problem and solution are both
settled, and only execution remains, one step's diff at a time.

| Layer | Skill | Unbound | Owns (artifact) | Question | Sees | May change |
|---|---|---|---|---|---|---|
| L1 (macro) | `/frame` | the problem | the frame (problem contract + discovery + open questions) | right problem, right framing? | the whole problem, **no step list** | anything |
| L2 (shape) | `/shape` | the solution | the pitch (picked candidate + rejected candidates) **and** the plan (step list ready for implement) | which direction, and does the resulting plan add up to the goal? | the problem + candidate directions, then the chosen plan, no diff | nothing on disk |
| L3 (build) | `/implement` | nothing — problem and solution are both settled | the commits (the code) | does each step's code do what it promised, built well? | **one step's diff** at a time | that step's code |

A read-only reviewer at any layer changes **nothing** — it emits a verdict. The "may change" column
is the layer's *driver* boundary; reviewers inherit the layer's *sees* boundary.

## A ceremony gradient — the user picks the entry point

The three skills are independent tools, not a fixed chain. The entry point matches task complexity:

```
fuzzy problem, unclear scope                      →  /frame       (scout, bind a problem contract, surface unknowns)
problem framed, no direction picked or needs plan →  /shape       (skip /frame — /shape runs its own quick scout if none exists)
one obvious change, problem & solution both clear →  /implement   (skip /frame, /shape)
```

Two rules keep a lower entry point from re-running the layer above it:
1. **Each skill takes a `<task>` arg** — any can be the entry point.
2. **Consume the upstream artifact if it's in context; else do the *minimum* to proceed — never
   re-run the upstream layer.** Skills share *tools* (`/scout`), not *logic*. A standalone
   `/shape` run with no frame in context does its own lighter discovery for its own needs — it is
   not running a small `/frame`.

When a skill notices it is underspecified, it **offers** to go up a layer in one declinable line —
never a forced router; `/implement` uses this when a reviewer recommends a `/shape` revisit (§
Verdicts, `protocols/workflow/phases/implement.md`). A missing frame is not this case — per rule 2
above, `/shape` with no frame in context runs its own lighter discovery (quick scout → inline
contract, `protocols/workflow/phases/shape.md` § Boundaries) instead of offering `/frame`. The
user's judgment is the router.

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
| `/shape` skill | shape | drives the pitch, then the plan; nothing to disk, no source edits |
| `shape-builder` (agent) | shape | reads the target read-only to produce candidate directions; the worker the `/shape` skill dispatches |
| `shape-reviewer` | shape | reads the candidate pool read-only, no diff; returns a ranked shortlist + traps + collapse record |
| `structure-reviewer` | shape | sees all steps + repo read-only, no diff; read-only `SOLID \| HOLES` on the plan |
| `readiness-reviewer` | shape | sees all steps read-only, no diff; read-only `SOLID \| HOLES` on each step's own contract |
| `/implement` skill | build | drives one step at a time; never reopens the plan |
| `step-builder` | build | sees one step's diff; changes only that step's code |
| `acceptance-reviewer` | build | sees one step's diff + criteria; read-only `MET \| UNMET` |
| `quality-reviewer` | build | sees one step's diff; read-only `PASS \| FIX \| BLOCK` |
| `/persist` skill | cross-cutting | writes the in-context frame, pitch, or plan to disk on request; owns no layer |

`/scout` produces no artifact of its own — it hands back a Discover record for whichever layer
requested it. `/shape` produces two artifacts, back to back — the pitch, then the plan — and owns
both.

An optional **project pack** extends each layer's components with project-specific knowledge
(and, for shape/implement, extra rules/validation) — see `packs/README.md`.

## No separate Validate
Adversarial pressure lives at each artifact boundary (Cooper 1990 — phase gates) — the frame
critique, shape's two critiques (the candidate-pool critique, then the plan critique), and
per-step acceptance + quality. There is no final goal-gate: if the plan was sound and each step
met its criteria, the goal holds by construction.
`/implement` also runs the plan's own already-authored Block 3 check once at the end
(`protocols/workflow/phases/implement.md` § Plan-level verification) — not a new layer or
reviewer, but the mechanism that makes "holds by construction" actually confirmed rather than
assumed.
