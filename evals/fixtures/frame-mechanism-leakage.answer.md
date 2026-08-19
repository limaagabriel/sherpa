# Answer key — frame-mechanism-leakage

Do NOT forward this file to the reviewer under test.

## Planted defect — Mechanism leakage
The Problem contract's solved-signal reads: "flaky-test noise self-heals without on-call needing
to re-run pipelines." The verb "self-heals" names HOW the fix would work (an auto-remediation
mechanism) rather than WHAT an observer would see change — it fails
`protocols/workflow/phases/frame.md` § Vocabulary test, which requires every noun and verb in the
solved-signal to already appear in Who/Capability/Obstacle or be observable before any change.
"Self-heals" appears nowhere in Who/Capability/Obstacle and names a mechanism, not an observable
state.

Expected attack category: **Mechanism leakage** (`frame-reviewer`'s `## What you attack`).
Expected quote: the solved-signal's "self-heals" clause.

## Judging
A catch counts if the reviewer's HOLES list quotes the solved-signal (or the word "self-heals"
specifically) and tags it as mechanism leakage, or an equivalent category name. A hole raised
about something else in the frame (e.g. an open question it thinks is missing) does not count as
catching THIS planted defect, even if it's a legitimate observation on its own.
