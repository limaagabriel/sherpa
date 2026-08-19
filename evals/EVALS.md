# Evals

Seeded-defect fixtures for sherpa's adversarial reviewers. Each fixture pairs a clean artifact
(what the reviewer under test actually sees) with a separate answer key (what defect was planted,
and which attack category should have caught it) — never mixed into one file, so the artifact can
be forwarded to a live dispatch without leaking the answer.

No CI wiring. These run by hand when you're validating a reviewer prompt change, not on every push.

## Layout
- `fixtures/<name>.artifact.md` — the exact input to forward to the reviewer under test.
- `fixtures/<name>.answer.md` — the planted defect, its expected attack category, and how to judge a catch.

## Dispatch protocol
1. Pick the fixture matching the reviewer you're validating (see the table below).
2. Dispatch that reviewer fresh — a new Agent call, no prior context, exactly as its owning skill
   would (e.g. `frame-reviewer` gets only what `/frame`'s own dispatch step gives it: the frame,
   the verbatim request, pack knowledge). Forward ONLY the `.artifact.md` file's content. Never
   forward the `.answer.md` file, and never mention that this is an eval — a reviewer told it's
   being tested may reason differently than it would in real use.
3. Capture the reviewer's verbatim output.
4. Open the matching `.answer.md` and judge by hand (see Pass criterion) — this is a human read,
   not a string match; a paraphrased catch counts.

## Fixtures

| Fixture | Reviewer under test | Attack category exercised |
|---|---|---|
| `frame-mechanism-leakage` | `frame-reviewer` | Mechanism leakage |
| `plan-interface-mismatch-no-go` | `structure-reviewer` | Interface mismatch + No-go violation |
| `step-diff-planted-bug` | `quality-reviewer` | Correctness |

## Pass criterion
The fixture PASSES (the reviewer caught it) when the reviewer's output contains a HOLES/FIX entry
that: (a) quotes the same offending text the answer key names, and (b) tags it with the same, or a
reasonably equivalent, attack category. A miscategorized-but-correctly-quoted catch still counts —
category drift across reviewer-prompt edits is expected and not itself a failure. A reviewer that
returns `SOLID`/`PASS` with no matching entry FAILS the fixture. For a fixture with multiple
planted defects, score per-defect, not one pass/fail for the whole fixture — see that fixture's
own answer key's Judging section.

## Catch-rate metric
Per reviewer role: `catches / fixtures run` across that role's fixtures. Report it whenever you run
a batch (e.g. after editing a reviewer's `## What you attack` list) — a single run's catch rate
isn't a trend, treat it as a spot check, not a KPI to chase turn over turn.

## Fixture-regeneration rule
When a reviewer's `## What you attack` list gains or loses a category, its fixture set follows:
add a fixture for a new category within the same change that adds the category; when a category is
removed, move its fixture's two files to `fixtures/retired/` rather than deleting them (keeps old
catch-rate runs reproducible against history). Never edit an existing fixture's planted defect in
place — retire the pair and add a new one under a new name; an in-place edit invalidates every past
catch-rate number that cited the old fixture without leaving a trace of what changed.
