# Questions

Sherpa's contract for how any user-facing question is shaped. Phase contracts and skill drivers
cite this instead of restating the rule.

Worked example — the whole shape in one shot:

> Found the plan step names its cache key from the URL path alone. Which means two tenants on the
> same path collide. So: scope by path, or by path + tenant?
>
> **AskUserQuestion:** "Scope the cache key by path alone, or path + tenant?"
> - Path only (Recommended) — simplest, but two tenants on the same path collide
> - Path + tenant — safe across tenants, but every existing cache key changes shape

## The two-part shape
Every question is two parts: a **prose preamble** (the walk) followed by the **structured fork**
(`AskUserQuestion`). The preamble never goes inside the question text.

## The walk
Three beats, one line each — the table names what each beat carries:

| Beat | Carries | Rule |
|---|---|---|
| **Found** | what scouting turned up | user-observable terms, not internal symbols |
| **Which means** | the implication that creates the fork | why there is a choice at all |
| **So** | the hand-off to the question | one clause |

Hard cap: three lines, extended only **explicitly** for a genuinely tangled finding.

## Translate, don't cite
See `protocols/prose.md` § The referent rule.

## When to brief
See `protocols/prose.md` § The reader test — a pure preference question gets no walk.

## The options
Each option's description is **one clause naming the downstream consequence**, never a
restatement of the label. The recommended option comes first, marked `(Recommended)`.

| Label | Weak description (restates the label) | Good description (consequence only) |
|---|---|---|
| Path only (Recommended) | The cache key uses the path only | simplest, but two tenants on the same path collide |
| Path + tenant | The cache key uses path plus tenant | safe across tenants, but every existing cache key changes shape |
