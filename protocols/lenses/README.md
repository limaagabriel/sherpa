# Lens library

One file per lens. Each file is the single description every agent uses for that lens. A
coordinator reads the file and injects only the sections its consumer needs, as content, never a
path (see the Portability rule in `skills/analyze/SKILL.md`).

## Section map

| Consumer | Injects |
|---|---|
| Diff reviewers: /analyze `code-reviewer`, /implement `code-reviewer` and `quality-reviewer` | `## In scope`, `## Out of scope`, `## Severity`, `## Deep-pass triggers` |
| `engineering-reviewer` (plan review) | `## Plan review` |
| `shape-contributor` | the `Owns` line and `## Proposing` |

Sections a consumer does not list are never injected: `## Proposing` and `## Plan review` must not
reach a diff reviewer, and a lens without a section is simply not used by that consumer.

## Proposing

`## Proposing` is written for an agent that drafts a light pre-plan (idea, macro steps, pros, cons)
from the problem alone, before any plan exists. It says what to optimize for and what kind of
direction to propose. It is not a review checklist.
