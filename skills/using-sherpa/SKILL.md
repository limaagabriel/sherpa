---
name: using-sherpa
description: Sherpa's layer-selection nudge — check /frame, /shape, /implement before free-form action. Force-loaded every session.
---

# Using sherpa

Sherpa is a ceremony gradient: match the layer to how well-formed the task already is.

- **Fuzzy task, unclear scope or open design questions** → `/frame` — scout the code, bind a problem contract, surface open questions.
- **Problem clear with a settled direction, or clear needing one picked** → `/shape` — pass your settled direction as `DIRECTION` to skip fan-out and plan it directly, or let `/shape` scout, fan out, critique, pick one, and plan.
- **One obvious change** → `/implement` — build it with per-step review.

Before taking free-form action, check whether one of these fits. Skip sherpa only when none of them apply.

Before acting on any task-initiating prompt — not a reply, confirmation, or answer to your own question — also check: does it admit multiple materially different reasonable interpretations of what to build? If yes, say so and offer /frame or /shape, whichever fits, as one line before proceeding. Required, not optional — even deep into a long session.

## HARD GATE — pack resolution

If a pack is resolved (`configPath` announced): (a) read the pack config at `configPath`, (b) run
`bash scripts/resolve-pack-value.sh <configPath> session`, (c) read and follow that output — before
any other tool, skill, or answer. This is required the instant a `configPath` shows up in session
context, not deferred until convenient.

## Resolution contract

No content-bearing pack key is ever pre-resolved by one component and forwarded as text to
another. Any consumer that needs a content-bearing key — a layer skill needing content for its own
reasoning, or a subagent that skill dispatches — resolves that key itself, at the point it needs
it, by calling `bash scripts/resolve-pack-value.sh <configPath> <key>`. Every key resolves the same
way, no exceptions. A skill or agent never accepts an already-resolved blob handed off by another
component in place of running this call itself.
