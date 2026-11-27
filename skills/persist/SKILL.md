---
name: persist
description: Opt-in. Writes the in-context frame and/or plan to disk for a later session. Never automatic. Triggers - "/persist", "save the frame", "save the plan", "persist this". Optional path; default `.sherpa/<slug>.md`.
---

# /persist — save the frame or plan to disk

Sherpa keeps the frame and plan in conversation by default. Run this only when you want
them on disk — to resume in a fresh session, or to commit them. The separate opt-in inventory
(`sherpa loop`, see README "Inventory") keeps its ticket state on its own; this skill does not touch it.
Sherpa writes nothing in the repo unless you run `/persist`; temp handoff files outside it follow `protocols/handoff.md`.

## Steps
1. **Resolve the path.** Use the path arg if given. Else default to `.sherpa/<slug>.md` where
   `<slug>` is the current git branch, or a slug of the goal when not on a branch. `mkdir -p` its dir.
2. **Write** whatever is in context — the frame, the plan, or both — into one
   markdown file under clear `## Frame` / `## Plan` headings. Don't fabricate sections
   that don't exist yet.
3. **Report** the path. Don't commit unless the human asks.

## Resume
A later session reads the file back: paste its path into `/shape` or `/implement`, which
consume it exactly as they would an in-context frame or plan.

## Done when
The file is written and its path reported.
