---
name: persist
description: Opt-in. Write the current in-context frame, pitch, and/or plan to disk so a later session can resume. Sherpa persists nothing automatically — call this only when you want the artifacts saved. Triggers - "/persist", "save the frame", "save the pitch", "save the plan", "persist this". Takes an optional path; defaults to .sherpa/<slug>.md in the repo.
---

# /persist — save the frame, pitch, or plan to disk

Sherpa keeps the frame, pitch, and plan in conversation by default. Run this only when you want
them on disk — to resume in a fresh session, or to commit them.

## Steps
1. **Resolve the path.** Use the path arg if given. Else default to `.sherpa/<slug>.md` where
   `<slug>` is the current git branch, or a slug of the goal when not on a branch. `mkdir -p` its dir.
2. **Write** whatever is in context — the frame, the pitch, the plan, or any combination — into one
   markdown file under clear `## Frame` / `## Pitch` / `## Plan` headings. Don't fabricate sections
   that don't exist yet.
3. **Report** the path. Don't commit unless the human asks.

## Resume
A later session reads the file back: paste its path into `/decompose` or `/implement`, which
consume it exactly as they would an in-context frame, pitch, or plan.

## Done when
The file is written and its path reported.
