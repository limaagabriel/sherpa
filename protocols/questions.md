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
Every user-facing question is two parts: a short **prose preamble** (the walk — the context that
produced the question) immediately followed by the **structured fork** (`AskUserQuestion`). The
preamble never goes inside the question text; that field is short by design and stuffing it makes
a wall.

## The walk
Three beats, one line each. What renders to the user is flowing prose (see the worked example
above) — the table below documents what each beat carries, it is not the render format itself:

| Beat | Carries | Rule |
|---|---|---|
| **Found** | what scouting turned up | user-observable terms, not internal symbols |
| **Which means** | the implication that creates the fork | why there is a choice at all |
| **So** | the hand-off to the question | one clause |

Hard cap: three lines. A fourth line is allowed **explicitly**, and only for a genuinely tangled
finding — take the fourth line openly rather than silently stretching all three.

## Translate, don't cite
State findings as behavior the reader can recognize, not as symbols they have never read. When an
internal name is unavoidable, gloss it inline, once.

> Bad: "`PackLoader.resolve()` only walks `.claude/`."
> Good: "Config is only picked up from `.claude/` — so a Codex user's settings are silently
> ignored."

Same fact; the second is answerable without having read the codebase.

## When to brief
This is a TEST, not a suggestion: **"Could the user answer this without reading the code? Yes →
no preamble."** A pure preference question ("which name do you prefer") gets no walk. Also skip
when the user already demonstrated familiarity with that surface earlier in the conversation —
re-explaining what they just told you reads as condescending. The failure mode this gate exists to
prevent: briefing every question until the ceremony becomes noise the user learns to skim.

## The options
Each option's description is **one clause naming the downstream consequence** — never a
restatement of the label. `AskUserQuestion` keeps `label` and `description` as separate fields;
the description clause never repeats the label text. The recommended option comes first and
carries the `(Recommended)` suffix.

| Label | Weak description (restates the label) | Good description (consequence only) |
|---|---|---|
| Path only (Recommended) | The cache key uses the path only | simplest, but two tenants on the same path collide |
| Path + tenant | The cache key uses path plus tenant | safe across tenants, but every existing cache key changes shape |
