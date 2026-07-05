# Pack Schema Reshape — Design

**Date:** 2026-07-05
**Status:** Approved design, pending spec review

## Problem

The project-pack schema (`packs/README.md`, `packs/TEMPLATE.yaml`) predates sherpa's collapse
into three composable layers (`/spec`, `/plan`, `/implement` — see `protocols/layers.md`). It's a
flat bag of keys accumulated across the old opinionated pipeline (Plan → Build → Validate, with a
dimension-reviewer fan-out) and never reconciled with the new shape:

- **`reviewers` is dead.** Documented as "extra project code-reviewer subagents" feeding the
  `quality-reviewer` style pass — no skill, agent, or protocol file consumes it. It's a relic of
  the old Validate phase's dimension-reviewer fan-out, which `protocols/layers.md` explicitly
  retired ("one general reviewer... sherpa ships no dimension-reviewer fan-out").
- **`codeStyleRules` over-promises.** `packs/README.md` claims it feeds both `step-builder` and
  `quality-reviewer`. In the actual dispatch chain (`skills/implement/SKILL.md`,
  `protocols/workflow/phases/implement.md`, `agents/step-builder.md`) it only reaches
  `step-builder`. `quality-reviewer.md` has zero pack references.
- **The resolver script's own comment has drifted.** `scripts/resolve-project-pack.sh`'s header
  lists `codeStyleAudit` and `architectureRules` as schema keys — neither appears in
  `packs/README.md` or `packs/TEMPLATE.yaml`. Leftovers from pre-refactor commits
  (`plan-layer-pressure: architectureRules...`).
- **The shape doesn't name the layers.** A flat `pack:` map gives no signal about which skill a
  given knob affects, or where a new one should go.

## New schema — sections match skills, not internal layer labels

```yaml
name: my-project
detect: case "$CWD" in */my-project*) exit 0 ;; *) exit 1 ;; esac
sessionInstructions: |
  Invoke Skill my-project-init before other work; skip if already invoked this session.

pack:
  knowledge: my-project-init        # cross-cutting: every layer, every subagent, always loaded

  spec:
    knowledge: my-spec-init         # optional, additive — spec-specific tactical guidance

  plan:
    knowledge: my-plan-init         # optional, additive
    architectureRules: cat ./architecture.md   # /plan drafts steps mindful of it;
                                                # plan-reviewer checks the decomposition against it

  implement:
    knowledge: my-implement-init    # optional, additive
    codeStyleRules: cat ./style.md  # step-builder conforms; quality-reviewer cites
    validate: |                     # step-builder runs before commit — same gate as
      npm run lint                  # its existing acceptance check; a failure is BUILD FAILED
      npm test
```

`reviewers` is removed — no replacement key. If a project wants deeper scrutiny than the single
`quality-reviewer` gives, that's out of scope for packs (matches the "one general reviewer"
design already in `protocols/layers.md`).

`initialize` is renamed **`knowledge`** — the old name suggested a one-time session bootstrap,
but it's now used at two scopes (cross-cutting and per-layer) to mean "the skill that loads
project knowledge for this scope." `knowledge` reads correctly in both positions
(`pack.knowledge`, `pack.plan.knowledge`) and doesn't collide with sherpa's own internal
"primer" concept (`skills/using-sherpa/SKILL.md`, the always-loaded layer-selection primer —
a different thing, force-loaded by the resolver regardless of pack match).

No `macro`/`step`/`build` internal-layer naming — sections are named after the skill a project
author actually calls (`spec`, `plan`, `implement`), since that's the vocabulary in `README.md`'s
usage table.

## Wiring per section

| Section key | Consumed by | Behavior |
|---|---|---|
| `knowledge` (top-level) | main agent + every subagent, every layer | unchanged from today's `initialize` — always loaded when announced |
| `spec.knowledge` | `/spec` skill, `spec-reviewer` | additive on top of the cross-cutting `knowledge` |
| `plan.knowledge` | `/plan` skill, `plan-reviewer` | additive |
| `plan.architectureRules` | `/plan` skill, `plan-reviewer` | `/plan` drafts steps mindful of it; `plan-reviewer` checks the decomposition doesn't violate it |
| `implement.knowledge` | `step-builder`, `quality-reviewer` | additive |
| `implement.codeStyleRules` | `step-builder`, `quality-reviewer` | `step-builder` conforms its output; `quality-reviewer` cites it in the style pass — this is the doc/code mismatch being fixed |
| `implement.validate` | `step-builder` only | runs pre-commit as part of the existing "build/test before committing" rule; a failure is `BUILD FAILED`, same as a failing acceptance check. `quality-reviewer` does not re-run it (may cite it) |

## Resolver script changes (`scripts/resolve-project-pack.sh`)

The `yq` walk that builds the `WORKFLOW_PACK:` line currently flattens one level
(`pack.key=val`). It needs to flatten two levels:

- Top-level scalar keys pass through as-is: `knowledge=my-project-init`.
- Nested per-layer maps (`spec`, `plan`, `implement`) flatten to `section.key=val`:
  `plan.architectureRules="cat ./architecture.md"`, `implement.validate="npm run lint\nnpm test"`.

Relative-path resolution (`resolve_pack_value`, proximate-`.claude`/`.codex`/`.pi`-dir logic)
is unchanged — it already operates per-value, not per-key-depth.

The header comment's schema line and its `codeStyleAudit`/`architectureRules` mentions are
rewritten to match the real schema above.

## Files touched

`packs/README.md`, `packs/TEMPLATE.yaml`, `packs/TEMPLATE/SKILL.md`,
`scripts/resolve-project-pack.sh`, `scripts/test-resolve-project-pack.sh`,
`skills/spec/SKILL.md`, `skills/plan/SKILL.md`, `skills/implement/SKILL.md`,
`agents/spec-reviewer.md`, `agents/plan-reviewer.md`, `agents/step-builder.md`,
`agents/quality-reviewer.md`, `protocols/workflow/phases/implement.md`,
`protocols/layers.md` (pointer only — its per-component binding table gains no new columns,
just a one-line note that packs extend components per-layer; see `packs/README.md`).

## Out of scope

- No `macro`/`step`/`build` stub sections for future knobs that don't exist yet (YAGNI).
- No change to `sessionInstructions` or the `detect`/precedence resolution order.
- No new subagents. `implement.validate` is a command step-builder runs itself — not a new
  reviewer.
