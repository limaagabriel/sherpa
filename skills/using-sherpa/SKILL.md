---
name: using-sherpa
description: Sherpa's layer-selection nudge — check whether /spec, /plan, or /implement fits before free-form action. Force-loaded every session via the SessionStart hook; also registered as a normal skill so routing survives contexts the hook doesn't reach (nested subagent, pre-SessionStart).
---

# Using sherpa

Sherpa is a ceremony gradient: match the layer to how well-formed the task already is.

- **Fuzzy task, unclear scope or open design questions** → `/spec` — refine intent, scout the code, surface open questions.
- **Clear goal, shape known** → `/plan` — decompose into ordered steps, get the decomposition reviewed.
- **One obvious change** → `/implement` — build it with per-step review.

Before taking free-form action, check whether one of these fits. Skip sherpa only when none of them apply.
